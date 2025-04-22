//
//  CameraView.swift
//  retrytech_plugin
//
//  Created by Aniket Vaddoriya on 19/04/25.
//

import Foundation
import CameraManager
import AVKit

class CameraView: NSObject, FlutterPlatformView {
    private let _view: UIView
    private let deviceWidth = UIScreen.main.bounds.size.width
    private var isBackCamera = true
    private var isTouchOn = false
    private var isRecording = false
    private var videoURLArray: [URL] = []
    private let cameraManager = CameraManager()

    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, binaryMessenger: FlutterBinaryMessenger?, channel: FlutterMethodChannel) {
        self._view = UIView(frame: CGRect(x: 0, y: 0, width: deviceWidth, height: deviceWidth * 1.77))
        super.init()
        configureCameraManager()
        setupChannel(channel)
    }

    func view() -> UIView {
        return _view
    }

    deinit {
        cameraManager.stopCaptureSession()
    }

    private func setupChannel(_ channel: FlutterMethodChannel) {
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            print("Mothod name: \(call.method)")
            switch call.method {
            case "init":
                self.setupView()
            case "toggle":
                self.toggleCamera()
            case "flash":
                self.toggleFlash()
            case "start":
                self.startRecording()
            case "pause":
                self.stopRecording(result: result)
            case "resume":
                self.startRecording()
            case "stop":
                self.stopRecording(isVideoCompleted: true, result: result)
            case "dispose":
                self.cameraManager.stopCaptureSession()
                result(true)
            case "capture_image":
                self.captureImage(result: result)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func setupView() {
        _view.backgroundColor = .black
        print(cameraManager.currentCameraStatus())
        switch cameraManager.currentCameraStatus() {
        case .notDetermined, .accessDenied:
            askCameraAndMicrophonePermission()
        case .ready:
            addCameraPreview()
        default:
            break
        }
    }

    private func configureCameraManager() {
        cameraManager.writeFilesToPhoneLibrary = false
        cameraManager.showAccessPermissionPopupAutomatically = false
        cameraManager.shouldEnableTapToFocus = false
        cameraManager.shouldEnablePinchToZoom = false
        cameraManager.shouldEnableExposure = false
        cameraManager.shouldUseLocationServices = false
        cameraManager.shouldRespondToOrientationChanges = false
        cameraManager.shouldFlipFrontCameraImage = false
    }

    private func askCameraAndMicrophonePermission() {
        cameraManager.askUserForCameraPermission { [weak self] granted in
            guard let self = self, granted else {
                return
            }
            self.addCameraPreview()
        }
    }

    private func addCameraPreview() {
        cameraManager.resumeCaptureSession()
        cameraManager.addPreviewLayerToView(self._view, newCameraOutputMode: .videoWithMic)
    }

    private func toggleCamera() {
        cameraManager.cameraDevice = (cameraManager.cameraDevice == .front) ? .back : .front
    }

    private func captureImage(result: FlutterResult? = nil){
        cameraManager.capturePictureWithCompletion { resultImage in
            switch resultImage {
            case .success(content: let content):
                guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    print("DIrectory not found")
                    return
                }
                let data = content.asData
                let outputURL = documentDirectory.appendingPathComponent("captured.jpg")
                try? FileManager.default.removeItem(at: outputURL) // Clean existing file if needed
                do {
                    try data?.write(to: outputURL)
                    result?(outputURL.path)
                } catch {
                    print(error.localizedDescription)
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }

    private func toggleFlash() {
        guard isBackCamera else {
            isTouchOn = false
            return
        }
        isTouchOn.toggle()
        toggleTorch(on: isTouchOn)
    }

    private func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }

    private func startRecording() {
        isRecording = true
        cameraManager.startRecordingVideo()
        if isBackCamera && isTouchOn {
            DispatchQueue.main.async {
                self.toggleTorch(on: true)
            }
        }
    }

    private func stopRecording(isVideoCompleted: Bool = false, result: FlutterResult? = nil) {
        if isVideoCompleted && !isRecording {
            mergeAndReturnFinalVideo(result: result)
            return
        }

        cameraManager.stopVideoRecording { [weak self] videoURL, error in
            guard let self = self else { return }
            self.isRecording = false

            if let videoURL = videoURL {
                self.videoURLArray.append(videoURL)
                if isVideoCompleted &&  result != nil {
                    self.mergeAndReturnFinalVideo(result: result)
                } else {
                    result?(nil)
                }
            } else {
                print("Stop error: \(error?.localizedDescription ?? "nil")")
            }
        }
    }

    private func mergeAndReturnFinalVideo(result: FlutterResult?) {
        AVMutableComposition().mergeVideo(self.videoURLArray) { url, error in
            self.videoURLArray.removeAll()
//            channel?.invokeMethod("url_path", arguments: savePathUrl.path)
            result?(url?.path ?? "")

        }

//@@@
//        VideoGenerator.presetName = AVAssetExportPresetMediumQuality
//        VideoGenerator.mergeMovies(videoURLs: self.videoURLArray) { result in
//            self.videoURLArray.removeAll()
//            channel?.invokeMethod("url_path", arguments: savePathUrl.path)
//        }
    }


    // Unused helper (optional)
    private func videoQueue() -> DispatchQueue {
        return DispatchQueue.main
    }

    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        return .portrait
    }
}



import Flutter
import UIKit

class CameraViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    private var channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger, channel: FlutterMethodChannel) {
        self.messenger = messenger
        self.channel = channel
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return CameraView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger,
            channel: channel
        )
    }
}


extension AVMutableComposition {

    func mergeVideo(_ urls: [URL], completion: @escaping (_ url: URL?, _ error: Error?) -> Void) {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(nil, NSError(domain: "AVMutableComposition", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access document directory"]))
            return
        }

        let outputURL = documentDirectory.appendingPathComponent("finalvideo.mp4")
        try? FileManager.default.removeItem(at: outputURL) // Clean existing file if needed

        // Skip merging if there's only one video
//        if let singleURL = urls.first, urls.count == 1 {
//            do {
//                try FileManager.default.copyItem(at: singleURL, to: outputURL)
//                completion(outputURL, nil)
//            } catch {
//                completion(nil, error)
//            }
//            return
//        }

        let maxRenderSize = CGSize(width: 1280, height: 720)
        var renderSize = CGSize.zero
        var currentTime = CMTime.zero
        var instructions: [AVMutableVideoCompositionInstruction] = []

        for (index, url) in urls.enumerated() {
            let asset = AVAsset(url: url)
            guard let assetTrack = asset.tracks(withMediaType: .video).first else {
                completion(nil, NSError(domain: "AVMutableComposition", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing video track in asset"]))
                return
            }

            let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
            let (instruction, isPortrait) = AVMutableComposition.instruction(for: assetTrack, asset: asset, at: currentTime, duration: asset.duration, maxRenderSize: maxRenderSize)
            instructions.append(instruction)

            if index == 0 {
                renderSize = isPortrait
                    ? CGSize(width: maxRenderSize.height, height: maxRenderSize.width)
                    : maxRenderSize
            }

            do {
                try insertTimeRange(timeRange, of: asset, at: currentTime)
                currentTime = CMTimeAdd(currentTime, asset.duration)
            } catch {
                completion(nil, error)
                return
            }
        }

        // Configure video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = instructions
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = renderSize

        // Export session
        guard let exporter = AVAssetExportSession(asset: self, presetName: AVAssetExportPresetHighestQuality) else {
            completion(nil, NSError(domain: "AVMutableComposition", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create exporter"]))
            return
        }

        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.videoComposition = videoComposition

        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                completion(exporter.status == .completed ? outputURL : nil, exporter.error)
            }
        }
    }

    static func instruction(for assetTrack: AVAssetTrack, asset: AVAsset, at time: CMTime, duration: CMTime, maxRenderSize: CGSize)
        -> (AVMutableVideoCompositionInstruction, Bool) {

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: assetTrack)
        let assetInfo = orientation(from: assetTrack.preferredTransform)

        let scaleRatio: CGFloat = assetInfo.isPortrait
            ? maxRenderSize.height / assetTrack.naturalSize.height
            : maxRenderSize.width / assetTrack.naturalSize.width

        var transform = CGAffineTransform(scaleX: scaleRatio, y: scaleRatio)
        transform = assetTrack.preferredTransform.concatenating(transform)
        layerInstruction.setTransform(transform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: time, duration: duration)
        instruction.layerInstructions = [layerInstruction]

        return (instruction, assetInfo.isPortrait)
    }

    static func orientation(from transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        switch (transform.a, transform.b, transform.c, transform.d) {
        case (0, 1, -1, 0): return (.right, true)
        case (0, -1, 1, 0): return (.left, true)
        case (1, 0, 0, 1): return (.up, false)
        case (-1, 0, 0, -1): return (.down, false)
        default: return (.up, false)
        }
    }
}
