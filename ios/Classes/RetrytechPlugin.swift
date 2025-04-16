import Flutter
import UIKit
import AVKit

public class RetrytechPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "retrytech_plugin", binaryMessenger: registrar.messenger())
        let instance = RetrytechPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "mergeAudioAndVideo":
            if let command = call.arguments as? [String: Any] {
                if let videoInputString = command["input_path"] as? String, let audioPath = command["audio_path"] as? String, let outputPath = command["output_path"] as? String {
                                    AVEditor.shared.mergeAudioVideo(videoInput: URL(fileURLWithPath: videoInputString),
                                                                    audioInput: URL(fileURLWithPath: audioPath),
                                                                    outputURL: URL(fileURLWithPath: outputPath)) { status in
                                        result(status)
                                    }
                }
            } else {
                result(false)
                print("Argument must be a string")
            }
            
        case "extractAudio":
            if let command = call.arguments as? [String: Any] {
                print(command)
                if let videoInputString = command["input_path"] as? String, let outputPath = command["output_path"] as? String {
                    print("Badha Param")
                    AVEditor.shared.extractAudio(videoURL: URL(fileURLWithPath: videoInputString), outputURL: URL(fileURLWithPath: outputPath)) { status in
                        result(status)
                    }
                }
                
            } else {
                result(false)
                print("Argument must be a string")
            }
            
        case "addWaterMarkInVideo":
            if let command = call.arguments as? [String: Any] {
                print(command)
                if let videoInputString = command["input_path"] as? String,
                   let outputPath = command["output_path"] as? String,
                   let thumbnailPath = command["thumbnail_path"] as? String {
                    print("Badha Param")
                    AVEditor.shared.addWatermark(videoInput: URL(fileURLWithPath: videoInputString),
                                                 imagePath: thumbnailPath,
                                                 username: "",
                                                 outputURL: URL(fileURLWithPath: outputPath)) { status in
                        result(status)
                    }
                }
                
            } else {
                result(false)
                print("Argument must be a string")
            }
            
            
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

