//
//  FFmpegManager.swift
//  retrytech_plugin
//
//  Created by Aniket Vaddoriya on 04/03/25.
//

import Foundation
import ffmpegkit

class FFmpegManager {
    static var shared: FFmpegManager = FFmpegManager()
    
    func runCommand(command: String,completion: @escaping (Bool)->()) {
        FFmpegKit.executeAsync(command) { session in
            let returnCode = session?.getReturnCode()
            
            if returnCode?.isValueSuccess() == true {
                completion(true)
                print("FFmpeg Success")
            } else {
                completion(false)
                print("FFmpeg failed: \(session?.getFailStackTrace() ?? "Unknown error")")
            }
        }
    }
}

