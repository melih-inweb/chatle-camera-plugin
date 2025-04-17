class CameraController {

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
        setupView()
        setupChannel(channel)
    }

    func view() -> UIView {
        return _view
    }

    deinit {
        stopRecording()
    }

    private func setupView() {
        _view.backgroundColor = .black
        switch cameraManager.currentCameraStatus() {
        case .notDetermined, .permissionDenied:
            askCameraAndMicrophonePermission()
        case .ready:
            addCameraPreview()
        default:
            break
        }
    }

    private func configureCameraManager() {
        cameraManager.shouldEnableExposure = true
        cameraManager.writeFilesToPhoneLibrary = false
        cameraManager.shouldFlipFrontCameraImage = false
        cameraManager.showAccessPermissionPopupAutomatically = false
    }

    private func setupChannel(_ channel: FlutterMethodChannel) {
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "toggle":
                self.toggleCamera()
            case "flash":
                self.toggleFlash()
            case "start":
                self.startRecording()
            case "pause":
                self.stopRecording(call: result)
            case "resume":
                self.startRecording()
            case "stop":
                self.stopRecording(isVideoCompleted: true, channel: channel, call: result)
            case "cameraDispose":
                self.cameraManager.stopCaptureSession()
                result(true)
            case "merge_audio_video":
                self.handleMergeAudioVideo(call: call, channel: channel)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
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
        cameraManager.shouldEnableTapToFocus = false
        cameraManager.shouldEnablePinchToZoom = false
        cameraManager.shouldEnableExposure = false
        cameraManager.shouldUseLocationServices = false
        cameraManager.shouldRespondToOrientationChanges = false
        cameraManager.shouldFlipFrontCameraImage = false
        cameraManager.addPreviewLayerToView(self._view, newCameraOutputMode: .videoWithMic)
    }

    private func toggleCamera() {
        cameraManager.cameraDevice = (cameraManager.cameraDevice == .front) ? .back : .front
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
    }

    private func stopRecording(isVideoCompleted: Bool = false, channel: FlutterMethodChannel? = nil, call: FlutterResult? = nil) {
        if isVideoCompleted && !isRecording {
            mergeAndReturnFinalVideo(channel: channel)
            return
        }

        cameraManager.stopVideoRecording { [weak self] videoURL, error in
            guard let self = self else { return }
            self.isRecording = false

            if let videoURL = videoURL {
                self.videoURLArray.append(videoURL)
                call?(true)
                if isVideoCompleted {
                    self.mergeAndReturnFinalVideo(channel: channel)
                }
            } else {
                print("Stop error: \(error?.localizedDescription ?? "nil")")
                call?(false)
            }
        }
    }

    private func mergeAndReturnFinalVideo(channel: FlutterMethodChannel?) {
        let savePathUrl = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/movie.m4v")
        try? FileManager.default.removeItem(at: savePathUrl)

        VideoGenerator.presetName = AVAssetExportPresetMediumQuality
        VideoGenerator.mergeMovies(videoURLs: self.videoURLArray) { result in
            self.videoURLArray.removeAll()
            channel?.invokeMethod("url_path", arguments: savePathUrl.path)
        }
    }

    private func handleMergeAudioVideo(call: FlutterMethodCall, channel: FlutterMethodChannel) {
        guard let audioPath = call.arguments as? String else { return }
        AVMutableComposition().mergeVideo(videoURLArray) { [weak self] url, _ in
            guard let self = self, let videoURL = url else { return }
            self.videoURLArray.removeAll()
            self.mergeVideoAndAudio(
                videoUrl: videoURL,
                audioUrl: URL(fileURLWithPath: audioPath),
                completion: { error, finalURL in
                    if let finalURL = finalURL {
                        channel.invokeMethod("url_path", arguments: finalURL.path)
                    } else {
                        print("Merge failed: \(error?.localizedDescription ?? "unknown error")")
                    }
                }
            )
        }
    }

    private func mergeVideoAndAudio(videoUrl: URL, audioUrl: URL, shouldFlipHorizontally: Bool = false, completion: @escaping (Error?, URL?) -> Void) {
        let mixComposition = AVMutableComposition()

        guard
            let videoTrack = AVAsset(url: videoUrl).tracks(withMediaType: .video).first,
            let audioTrack = AVAsset(url: audioUrl).tracks(withMediaType: .audio).first,
            let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let compositionAudioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            return
        }

        compositionVideoTrack.preferredTransform = shouldFlipHorizontally
            ? CGAffineTransform(scaleX: -1.0, y: 1.0).translatedBy(x: -videoTrack.naturalSize.width, y: 0)
            : videoTrack.preferredTransform

        do {
            try compositionVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: videoTrack.timeRange.duration),
                of: videoTrack,
                at: .zero
            )
            try compositionAudioTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: videoTrack.timeRange.duration),
                of: audioTrack,
                at: .zero
            )
        } catch {
            print("Insert error: \(error)")
        }

        let outputURL = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/newVideo.mp4")
        try? FileManager.default.removeItem(at: outputURL)

        let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetMediumQuality)!
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                switch exporter.status {
                case .completed:
                    completion(nil, outputURL)
                case .failed, .cancelled:
                    completion(exporter.error, nil)
                default:
                    break
                }
            }
        }
    }

    // Unused helper (optional)
    private func videoQueue() -> DispatchQueue {
        return DispatchQueue.main
    }

    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        return .portrait
    }
}

}