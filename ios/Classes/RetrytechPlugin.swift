import Flutter
import UIKit

public class RetrytechPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "retrytech_plugin", binaryMessenger: registrar.messenger())
    let instance = RetrytechPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "runFFmpegCommand":


    NSLog("FFmpeg called")

        print("FFmpeg called")
        if let command = call.arguments as? String {
            FFmpegManager.shared.runCommand(command: command) { status in
                result(status)
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
