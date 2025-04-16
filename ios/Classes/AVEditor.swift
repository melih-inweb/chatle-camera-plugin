//
//  AVEditor.swift
//
//
//  Created by Aniket Vaddoriya on 15/04/25.
//

import SwiftUI
import AVKit

class AVEditor {
    
    static var shared = AVEditor()
    
    
    func extractAudio(videoURL: URL, outputURL: URL, completion: @escaping (_ status: Bool) -> Void ) {
        
        let asset = AVAsset(url: videoURL)
        
        let composition = AVMutableComposition()
        // Create an array of audio tracks in the given asset
        // Typically, there is only one
        let audioTracks = asset.tracks(withMediaType: .audio)

        // Iterate through the audio tracks while
        // Adding them to a new AVAsset
        for track in audioTracks {
            let compositionTrack = composition.addMutableTrack(withMediaType: .audio,
                                                               preferredTrackID: kCMPersistentTrackID_Invalid)
            do {
                // Add the current audio track at the beginning of
                // the asset for the duration of the source AVAsset
                try compositionTrack?.insertTimeRange(track.timeRange,
                                                      of: track,
                                                      at: track.timeRange.start)
            } catch {
                print(error)
            }
        }

        guard let exportSession = AVAssetExportSession(asset: composition,
                                                       presetName: AVAssetExportPresetAppleM4A) else {
            // This is just a generic error
            completion(false)
            
            return
        }
        
        try? FileManager.default.removeItem(at: outputURL)
        
        exportSession.outputFileType = .m4a
        exportSession.outputURL = outputURL
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(true)
            case .unknown, .waiting, .exporting, .failed, .cancelled:
                completion(false)
            default:
                break
            }
            
        }
    }
    
    func mergeAudioVideo(videoInput: URL, audioInput: URL, outputURL: URL, completion: @escaping (_ output: Bool) -> Void) {
        
        let mixComposition = AVMutableComposition()
        let videoAsset = AVAsset(url: videoInput)
        let audioAsset = AVAsset(url: audioInput)
        
        Task {
            do {
                // Load and insert video track
                let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
                guard let videoTrack = videoTracks.first else {
                    completion(false)
                    return
                }
                
                let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                try videoCompositionTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: videoTrack, at: .zero)
                
                videoCompositionTrack?.preferredTransform = videoTrack.preferredTransform
                
                // Load and insert audio track (always)
                let newAudioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
                if let newAudioTrack = newAudioTracks.first {
                    let newAudioCompositionTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    try newAudioCompositionTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: newAudioTrack, at: .zero)
                }
                
                // Export
                let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
                exporter?.outputFileType = .mp4
                exporter?.outputURL = outputURL
                exporter?.shouldOptimizeForNetworkUse = true
                
                try? FileManager.default.removeItem(at: outputURL) // Clean up before exporting
                
                exporter?.exportAsynchronously {
                    DispatchQueue.main.async {
                        if exporter?.status == .completed {
                            completion(true)
                        } else {
                            print("❌ Export failed: \(exporter?.error?.localizedDescription ?? "Unknown error")")
                            completion(false)
                        }
                    }
                }
                
            } catch {
                print("❌ Error merging: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    
    
    func addWatermark(videoInput: URL, imagePath: String,username: String,outputURL: URL, handler:@escaping (_ status: Bool)-> Void) {
        guard let watermark = UIImage(contentsOfFile: imagePath) else {
            print("UIImage issue")
            handler(false)
            return
        }
        let asset = AVAsset(url: videoInput)
        let mixComposition = AVMutableComposition()
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            print("❌ No video track found in asset")
            handler(false)
            return
        }
        
        let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        
        let minDimension = min(abs(size.width), abs(size.height))
        let imageSize: CGFloat = minDimension * 0.1 // Simpler logic
        
        let timerange = CMTimeRangeMake(start: CMTime.zero, duration: asset.duration)
        
        guard let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            print("❌ Failed to create composition track")
            handler(false)
            return
        }
        
        do {
            try compositionVideoTrack.insertTimeRange(timerange, of: videoTrack, at: CMTime.zero)
            compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
        } catch {
            print("❌ Failed to insert video track: \(error)")
            handler(false)
            return
        }
        
        let resizedWatermark = watermark.resizeImage(targetSize: CGSize(width: abs(size.width), height: imageSize))
        guard let watermarkCIImage = CIImage(image: resizedWatermark) else {
            print("❌ Failed to convert watermark to CIImage")
            handler(false)
            return
        }
        
        let watermarkFilter = CIFilter(name: "CISourceOverCompositing")!
        
        let videoComposition = AVVideoComposition(asset: asset) { (filteringRequest) in
            let source = filteringRequest.sourceImage.clampedToExtent()
            watermarkFilter.setValue(source, forKey: "inputBackgroundImage")
            
            let height = filteringRequest.sourceImage.extent.height
            let bottomPadding = height * 0.02 // 3% of video height
            
            let transform = CGAffineTransform(
                translationX: filteringRequest.sourceImage.extent.width - watermarkCIImage.extent.width - 10,
                y: bottomPadding
            )
            
            watermarkFilter.setValue(watermarkCIImage.transformed(by: transform), forKey: "inputImage")
            filteringRequest.finish(with: watermarkFilter.outputImage!, context: nil)
        }
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            handler(false)
            
            return
        }
        
        try? FileManager.default.removeItem(at: outputURL) // Clean up before exporting
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.videoComposition = videoComposition
        DispatchQueue.main.async {
            exportSession.exportAsynchronously { () -> Void in
                handler(true)
            }
        }
    }
}




extension View {
    func snapshotComplition(color: Color = .white,complition: @escaping (UIImage)->()){
        DispatchQueue.main.async {
            let controller = UIHostingController(rootView: self)
            let view = controller.view
            
            let targetSize = controller.view.intrinsicContentSize
            view?.bounds = CGRect(origin: .zero, size: targetSize)
            view?.backgroundColor = UIColor(color)
            
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            DispatchQueue.main.async {
                let image = renderer.image { _ in
                    view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
                }
                complition(image)
            }
        }
    }
}


extension UIImage {
    func resizeImage(targetSize: CGSize) -> UIImage {
        let size = self.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}
