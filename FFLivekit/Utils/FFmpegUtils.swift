//
//  FFmpegUtils.swift
//  live-demo
//
//  Created by xkal on 10/3/2024.
//

import AVFoundation
import ffmpegkit

enum RecordingType {
    case Microphone
    case Camera
    case Camera_Microphone
    case File
}

public class FFStat {
    
    public let bitrate: Double
    public let size: Int
    public let time: Double
    public let speed: Double
    public let rate: Double
    public let fps: Float
    public let quality: Float
    public let frameNumber: Int32
    public let sessionId: Int
    
    init(stat: Statistics) {
        bitrate = stat.getBitrate()
        size = stat.getSize()
        time = stat.getTime()
        speed = stat.getSpeed()
        rate = stat.getBitrate()
        fps = stat.getVideoFps()
        quality = stat.getVideoQuality()
        frameNumber = stat.getVideoFrameNumber()
        sessionId = stat.getSessionId()
    }
    
    
}

public enum RecordingState {
    case RequestRecording
    case Recording
    case RequestStop
    case Normal
}

public protocol FFmpegUtilsDelegate {
    func _FFLiveKit(didChange status: RecordingState)
    func _FFLiveKit(onStats stats: FFStat)
    func _FFLiveKit(onError error: String)
}

public enum FFLivekitSettings {
    case outputVideoFramerate(Int)
    case outputVideoPixelFormat(String)
    case outputVideoSize((Int, Int))
    /// example "500k" or "2M"
    case outputVideoBitrate(String)
    /// example "128k"
    case outputAudioBitrate(String)

    /// nil to no transpose
    /// 0 - Rotate 90 degrees counterclockwise and flip vertically.
    ///1 - Rotate 90 degrees clockwise.
    /// 2 - Rotate 90 degrees counterclockwise.
    /// 3 - Rotate 90 degrees clockwise and flip vertically.
    case outputVideoTranspose(Int?)
    case videoEncoder(Encoder?)
    case audioEncoder(Encoder?)
}


struct FFmpegOptions {
    /// input settings
    var outputVideoFramerate: Int
    var outputVideoPixelFormat: String
    var outputVideoSize: (Int, Int)
    var outputVideoBitrate: String
    var outputAudioBitrate: String
    var outputVideoTranspose: Int?
    var videoEncoder: Encoder
    var audioEncoder: Encoder
    
    init(outputVideoFramerate: Int, outputVideoPixelFormat: String, outputVideoSize: (Int, Int), outputVideoBitrate: String, outputAudioBitrate: String,videoEncoder: Encoder, audioEncoder: Encoder, outputVideoTranspose: Int?) {
        self.outputVideoFramerate = outputVideoFramerate
        self.outputVideoPixelFormat = outputVideoPixelFormat
        self.outputVideoSize = outputVideoSize
        self.outputVideoBitrate = outputVideoBitrate
        self.outputAudioBitrate = outputAudioBitrate
        self.outputVideoTranspose = outputVideoTranspose
        self.videoEncoder = videoEncoder
        self.audioEncoder = audioEncoder
    }
    
    init(settings: [FFLivekitSettings]) {
        self = FFmpegOptions.shared()

        for setting in settings {
            switch setting {
            case .outputAudioBitrate(let value):
                self.outputAudioBitrate = value
                break
            case .outputVideoBitrate(let value):
                self.outputVideoBitrate = value
                break
            case .outputVideoSize(let value):
                self.outputVideoSize = value
                break
            case .outputVideoFramerate(let value):
                self.outputVideoFramerate = value
                break
            case .outputVideoPixelFormat(let value):
                self.outputVideoPixelFormat = value
                break
            case .outputVideoTranspose(let value):
                self.outputVideoTranspose = value
                break
            case .videoEncoder(let encoder):
                self.videoEncoder = encoder ?? Encoder(str: "")
                break
            case .audioEncoder(let encoder):
                self.audioEncoder = encoder ?? Encoder(str: "")
                break
            }
        }
    }
    
    public static func shared() -> FFmpegOptions {
        let option = FFmpegOptions(outputVideoFramerate: 30, outputVideoPixelFormat: "yuv420p", outputVideoSize: (1280, 720), outputVideoBitrate: "640k", outputAudioBitrate: "64k", videoEncoder: H264_VTEncoder(),audioEncoder: AACEncoder(), outputVideoTranspose: 1)
        return option
    }
    
}

class FFmpegUtils: NSObject, SourceDelegate {
  
  
    var audioPipe: String?
    var videoPipe: String?
    var sources: [Source] = []
    var outputFormat = ""
    var baseUrl = ""
//    var streamName: String?
//    var queryString = ""
    let options: FFmpegOptions!
    
    
    var url: String {
        get {
            return baseUrl
        }
    }
    
    var enableWritingToPipe = false
    var isInBackground = false
    
    private var videoTimer: Timer?
    private var blankFrames: Data?
    private var videoFileDescriptor: Int32!
    private var audioFileDescriptor: Int32!
    
//    var recordingType = RecordingType.Camera_Microphone
    
    var inputCommands: [String] = []
//    var outputCommands: [String] = []
//    var encoders: [String] = []
    
    /// threads
    private let background = DispatchQueue.global(qos: .background)
    private let videoFeedThread = DispatchQueue.global(qos: .background)
    private let audioFeedThread = DispatchQueue.global(qos: .background)
    
    /// buffers and locks
    private let videoBufferLock = NSLock()
    private var videoDataBuffer = Data()
    
    private let audioBufferLock = NSLock()
    private var audioDataBuffer = Data()
    
    private var delegate: FFmpegUtilsDelegate?
    
    init(sources: [Source], outputFormat: String, url: String, delegate: FFmpegUtilsDelegate?, options: [FFLivekitSettings]) {
        self.options = FFmpegOptions(settings: options)
        super.init()
        self.sources = sources
        /// delegate
        for var source in sources {
            source.delegate = self
        }
        /// start the source
        for source in sources {
            source.start()
        }
        self.inputCommands = getInputCommands()
//        self.encoders = getEncoders()
        self.outputFormat = outputFormat
        self.baseUrl = url
        self.delegate = delegate
        FFmpegKitConfig.enableLogCallback({log in
            if let log = log {
                print(log.getMessage()!)
            }
        })
        registerForInterruption()
        self.recordingState = .Normal
    }
    
    func registerForInterruption() {
        // Add observers for AVCaptureSession notifications
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: .AVCaptureSessionWasInterrupted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: .AVCaptureSessionInterruptionEnded, object: nil)
    }
    
    // Handle AVCaptureSession runtime error
    @objc func sessionRuntimeError(notification: Notification) {
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error {
            print("AVCaptureSession runtime error: \(error.localizedDescription)")
            // Handle the error as needed
        }
    }
    
    // Handle AVCaptureSession interruption
    @objc func sessionWasInterrupted(notification: Notification) {
        if let reasonValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int,
           let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue) {
            print("AVCaptureSession was interrupted. Reason: \(reason)")
            // Handle the interruption as needed
            if reasonValue == 1 {
                blankFrames = BufferConverter.createEmptyRGBAData(width: 1920, height: 1080)
                isInBackground = true
            }
        }
    }
    
    // Handle AVCaptureSession interruption ended
    @objc func sessionInterruptionEnded(notification: Notification) {
        print("AVCaptureSession interruption ended.")
        isInBackground = false
        blankFrames = nil
        clearVideoBuffer()
        clearAudioBuffer()
    }
    
    // Remove observers when the view controller is deallocated
    deinit {
        NotificationCenter.default.removeObserver(self)
        videoDataBuffer.removeAll()
    }
    
    
    var recordingState: RecordingState = .Normal {
        willSet {
            DispatchQueue.main.async {
                self.delegate?._FFLiveKit(didChange: newValue)
            }
            switch newValue {
            case .Normal:
                enableWritingToPipe = false
                break
            case .RequestRecording:
                clearVideoBuffer()
                clearAudioBuffer()
                enableWritingToPipe = true
                /// initialize pipes
                createPipes()
                background.async {
                    self.executeCommand()
                }
                startTimer()
                break
            case .Recording:
                enableWritingToPipe = true
                break
            case .RequestStop:
                enableWritingToPipe = false
                stopTimer()
                closePipes()
                clearVideoBuffer()
                clearAudioBuffer()
                FFmpegKit.cancel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    self.recordingState = .Normal
                })
                break
            }
        }
    }
    
    func start() {
        recordingState = .RequestRecording
    }
    
    func getInputCommands() -> [String] {
        let inputs = sources.map({source in
            return source.command
        })
        return inputs
    }
    
//    func getEncoders() -> [String] {
//        let encoders = sources.map { $0.encoder!.command }
//        return encoders
//    }
    
    func stop() {
        recordingState = .RequestStop
    }
    
    private func stopTimer() {
        videoTimer?.invalidate()
        videoTimer = nil
    }
    
    private func startTimer() {
        DispatchQueue.global().async {
            self.videoTimer = Timer.scheduledTimer(timeInterval: 0.010, target: self, selector: #selector(self.handleFeed), userInfo: nil, repeats: true)
            RunLoop.current.add(self.videoTimer!, forMode: .default)
            RunLoop.current.run()
        }
    }
    
    @objc func handleFeed() {
        if isInBackground {
            /// check if it has video source
            let contains = sources.contains(where: {source in
                return source is CameraSource || source is FileSource
            })
            print("Contains -> \(contains)")
            if contains {
                self.appendToVideoBuffer(data: self.blankFrames!)
                if self.videoDataBuffer.count > 10*1000000 {
                    print("Flushing....")
                    self.feedToVideoPipe()
                }
            }
        } else {
            feedToVideoPipe()
            feedToAudioPipe()
        }
    }
    
    private func createPipes() {
        // create a pipe for video
        videoPipe = FFmpegKitConfig.registerNewFFmpegPipe()
        audioPipe = FFmpegKitConfig.registerNewFFmpegPipe()
        // open the videopipe so that ffempg doesnot closes when the video pipe receives EOF
        videoFileDescriptor = open(videoPipe!, O_RDWR)
        audioFileDescriptor = open(audioPipe!, O_RDWR)
        //        audioFileDescriptor = open(audioPipe!, O_RDWR)
    }
    
    private func closePipes() {
        if videoFileDescriptor != nil {
            close(videoFileDescriptor)
        }
        if audioFileDescriptor != nil {
            close(audioFileDescriptor)
        }
        FFmpegKitConfig.closeFFmpegPipe(videoPipe)
        FFmpegKitConfig.closeFFmpegPipe(audioPipe)
    }
    
    func appendToVideoBuffer(data: Data) {
        videoFeedThread.sync {
            self.videoBufferLock.lock()
            /// Max bytes buffer 100MB
            if self.videoDataBuffer.count > (100 * 1000000) {
                self.videoDataBuffer.removeAll()
            }
            self.videoDataBuffer.append(data)
            self.videoBufferLock.unlock()
        }
    }
    
    func appendToAudioBuffer(data: Data) {
        audioFeedThread.sync {
            self.audioBufferLock.lock()
            /// Max bytes buffer 100MB
            if self.audioDataBuffer.count > (50 * 1000000) {
                self.audioDataBuffer.removeAll()
            }
            self.audioDataBuffer.append(data)
            self.audioBufferLock.unlock()
        }
    }
    
    func writeToVideoPipe(data: Data) {
        if let currentPipe = self.videoPipe, let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: currentPipe)) {
            //                print("writing to the data \(data)")
            // Convert the message to data
            if #available(iOS 13.4, *) {
                try? fileHandle.write(contentsOf: data)
            } else {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
            print("Video written successfully")
        } else {
            print("Failed to open video file handle for writing")
        }
    }
    
    func writeToAudioPipe(data: Data) {
        if let currentPipe = self.audioPipe, let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: currentPipe)) {
            //                print("writing audio to the data \(data)")
            // Convert the message to data
            if #available(iOS 13.4, *) {
                try? fileHandle.write(contentsOf: data)
            } else {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
            print("Audio written successfully")
        } else {
            print("Failed to open audio file handle for writing")
        }
    }
    
    @objc func feedToVideoPipe() {
        //        print("Feeding video")
        self.videoBufferLock.lock()
        // Feed video
        if !self.videoDataBuffer.isEmpty {
            self.writeToVideoPipe(data: self.videoDataBuffer)
            self.videoDataBuffer.removeAll()
        }
        self.videoBufferLock.unlock()
    }
    
    @objc func feedToAudioPipe() {
        //        print("Feeding video")
        self.audioBufferLock.lock()
        // Feed video
        if !self.audioDataBuffer.isEmpty {
            self.writeToAudioPipe(data: self.audioDataBuffer)
            self.audioDataBuffer.removeAll()
        }
        self.audioBufferLock.unlock()
    }
    
    func clearVideoBuffer() {
        self.videoBufferLock.lock()
        self.videoDataBuffer.removeAll()
        self.videoBufferLock.unlock()
    }
    
    func clearAudioBuffer() {
        self.audioBufferLock.lock()
        self.audioDataBuffer.removeAll()
        self.audioBufferLock.unlock()
    }
    
 
    private func generateVideoOutputCommand() -> String {
        return "-framerate \(options.outputVideoFramerate) -pixel_format \(options.outputVideoPixelFormat) -vf \"\(options.outputVideoTranspose == nil ? "" : "transpose=\(options.outputVideoTranspose!),")scale=\(options.outputVideoSize.0):\(options.outputVideoSize.1)\" -b:v \(options.outputVideoBitrate)"
    }
    
    private func generateAudioOutputCommand() -> String {
        return "-b:a \(options.outputAudioBitrate)"
    }

    private func executeCommand() {
        let inputs = self.inputCommands.joined(separator: " ").replacingOccurrences(of: "%videoPipe%", with: videoPipe!).replacingOccurrences(of: "%audioPipe%", with: audioPipe!)
        let encoders = [self.options.videoEncoder.command, self.options.audioEncoder.command].joined(separator: " ")
        let cmd = "-re \(inputs) \(encoders) \(generateVideoOutputCommand()) \(generateAudioOutputCommand()) -vsync 1 -f \(outputFormat) \"\(url)\""
        execute(cmd: cmd)
    }
    
    
    private func execute(cmd: String) {
        print("Executing \(cmd)..........")
        FFmpegKit.executeAsync(cmd, withCompleteCallback: {session in
            if let session = session {
                if let stats = session.getStatistics().first as? Statistics {
                    DispatchQueue.main.async {
                        self.delegate?._FFLiveKit(onStats: FFStat(stat: stats))
                    }
                }
                if let code = session.getReturnCode() {
                    if ReturnCode.isSuccess(code) {
                        print("Finished")
                    } else if ReturnCode.isCancel(code) {
                        print("Cancelled")
                    } else {
                        print("Error")
                        DispatchQueue.main.async {
                            let output = session.getOutput() ?? ""
                            self.delegate?._FFLiveKit(onError: output)
                        }
                    }
                }
                
            }
            self.stop()
        }, withLogCallback: nil, withStatisticsCallback: {stats in
            guard let stats = stats else {
                return
            }
            /// For Video
            if stats.getTime() > 0 {
                self.recordingState = .Recording
            }
            DispatchQueue.main.async {
                self.delegate?._FFLiveKit(onStats: FFStat(stat: stats))
            }
        })
    }
    
    
//    func _CameraSource(switchStarted: Bool) {
//        startPiping = false
//        clearVideoBuffer()
//    }
//    
//    func _CameraSource(switchEnded: Bool) {
//        running = true
//    }
    
    
    func _Source(_ source: Source,type: SourceType, onData: Data) {
        if self.enableWritingToPipe {
            if source is CameraSource {
                if !self.isInBackground, let data = isInBackground ? blankFrames : onData {
                    if self.recordingState == .RequestRecording {
                        self.writeToVideoPipe(data: data)
                    } else if self.recordingState == .Recording {
                        self.appendToVideoBuffer(data: data)
                    }
                }
            } else if source is MicrophoneSource {
                if self.recordingState == .RequestRecording {
                    self.writeToAudioPipe(data: onData)
                } else if self.recordingState == .Recording {
                    if isInBackground {
                        self.writeToAudioPipe(data: onData)
                    } else {
                        self.appendToAudioBuffer(data: onData)
                    }
                }
            } else if source is ScreenSource {
                if type == .Video {
                    if self.recordingState == .RequestRecording {
                        self.writeToVideoPipe(data: onData)
                    } else if self.recordingState == .Recording {
                        if isInBackground {
                            self.writeToVideoPipe(data: onData)
                        } else {
                            self.appendToVideoBuffer(data: onData)
                        }
                    }
                }
            }
        }
    }
    
    func _Source(_ source: Source, extra: [String : Any]) {
        if self.recordingState == .Recording {
            if source is CameraSource {
                if let switchStarted = extra["switchStarted"] as? Bool {
                    if switchStarted == true {
                        self.enableWritingToPipe = false
                        clearVideoBuffer()
                        clearAudioBuffer()
                    } else if switchStarted == false {
                        self.enableWritingToPipe = true
                    }
                }
                
            }
        }
    }
}
