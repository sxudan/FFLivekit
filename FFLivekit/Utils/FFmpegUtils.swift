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
    public let currentAudioBufferSize: Int
    public let currentVideoBufferSize: Int
    
    init(stat: Statistics, audioBufferSize: Int, videoBufferSize: Int) {
        bitrate = stat.getBitrate()
        size = stat.getSize()
        time = stat.getTime()
        speed = stat.getSpeed()
        rate = stat.getBitrate()
        fps = stat.getVideoFps()
        quality = stat.getVideoQuality()
        frameNumber = stat.getVideoFrameNumber()
        sessionId = stat.getSessionId()
        currentAudioBufferSize = audioBufferSize
        currentVideoBufferSize = videoBufferSize
    }
    
    
}

public enum RecordingState {
    case RequestRecording
    case Booting
    case Recording(useBuffer: Bool)
    case BackgroundRecording
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
    var currentStats: Statistics?
    
    
    var url: String {
        get {
            return baseUrl
        }
    }
    
    var enableWritingToPipe = false
//    var useBuffer = true
//    var isInBackground = false
    
    private var videoTimer: Timer?
    private var statsTimer: Timer?
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
                self.recordingState = .BackgroundRecording
            }
        }
    }
    
    // Handle AVCaptureSession interruption ended
    @objc func sessionInterruptionEnded(notification: Notification) {
        print("AVCaptureSession interruption ended.")
        self.recordingState = .Recording(useBuffer: false)
        blankFrames = nil
        self.feedToVideoPipe()
        self.feedToAudioPipe()
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
            print("STATE => \(newValue)")
            switch newValue {
            case .Normal:
                enableWritingToPipe = false
                break
            case .RequestRecording:
//                useBuffer = true
                clearVideoBuffer()
                clearAudioBuffer()
                /// initialize pipes
                createPipes()
                background.async {
                    self.executeCommand()
                }
                startTimer()
                break
            case .Booting:
                enableWritingToPipe = true
                break
            case .Recording:
                break
            case .BackgroundRecording:
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
        /// start the source
        for source in sources {
            source.start()
        }
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
        statsTimer?.invalidate()
        videoTimer = nil
        statsTimer = nil
    }
    
    private func startTimer() {
        DispatchQueue.global().async {
            self.videoTimer = Timer.scheduledTimer(timeInterval: 0.010, target: self, selector: #selector(self.handleFeed), userInfo: nil, repeats: true)
            RunLoop.current.add(self.videoTimer!, forMode: .default)
            RunLoop.current.run()
        }
    }
    
    @objc func handleFeed() {
        switch self.recordingState {
        case .BackgroundRecording:
            // check if it has video source
            let contains = self.sources.contains(where: {source in
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
            break
//        case .Recording(useBuffer: let useBuffer):
//            if useBuffer {
//                self.feedToVideoPipe()
//                self.feedToAudioPipe()
////                self.showStats()
//            }
//            break
        default:
            break
            
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
    
    private func showStats() {
        if let stats = currentStats {
            DispatchQueue.main.async {
                self.delegate?._FFLiveKit(onStats: FFStat(stat: stats, audioBufferSize: self.audioDataBuffer.count, videoBufferSize: self.videoDataBuffer.count))
            }
        }
    }
    
    
    private func execute(cmd: String) {
        print("Executing \(cmd)..........")
        FFmpegKit.executeAsync(cmd, withCompleteCallback: {session in
            if let session = session {
                if let stats = session.getStatistics().first as? Statistics {
                    DispatchQueue.main.async {
                        self.delegate?._FFLiveKit(onStats: FFStat(stat: stats, audioBufferSize: self.audioDataBuffer.count, videoBufferSize: self.videoDataBuffer.count))
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
        }, withLogCallback: {_ in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0, execute: {
                switch self.recordingState {
                case .RequestRecording:
                    self.recordingState = .Booting
                default:
                    break
                }
                
            })
            self.showStats()
        }, withStatisticsCallback: {stats in
            guard let stats = stats else {
                return
            }
            self.currentStats = stats
            /// For Video
            if stats.getTime() > 0 && stats.getVideoFps() > 10 {
                switch self.recordingState {
                case .Booting:
                    self.recordingState = .Recording(useBuffer: false)
                    break
//                case .Recording(useBuffer: let useBuffer):
//                    if !useBuffer {
//                        self.recordingState = .Recording(useBuffer: true)
//                        break
//                    }
                default:
                    break
                }
            }
            self.showStats()
//            DispatchQueue.main.async {
//                self.delegate?._FFLiveKit(onStats: FFStat(stat: stats, audioBufferSize: self.audioDataBuffer.count, videoBufferSize: self.videoDataBuffer.count))
//            }
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
                print("Video source running")
                switch self.recordingState {
                case .Booting:
                    self.writeToVideoPipe(data: onData)
                    break
                case .Recording(useBuffer: let useBuffer):
                    if useBuffer {
                        self.appendToVideoBuffer(data: onData)
                    } else {
                        self.writeToVideoPipe(data: onData)
                    }
                    break
                default:
                    break
                }
            } else if source is MicrophoneSource {
                switch self.recordingState {
                case .Booting:
                    self.writeToAudioPipe(data: onData)
                    break
                case .Recording(useBuffer: let useBuffer):
                    self.writeToAudioPipe(data: onData)
//                    if useBuffer {
//                        self.appendToAudioBuffer(data: onData)
//                    } else {
//                        self.writeToAudioPipe(data: onData)
//                    }
                    break
                case .BackgroundRecording:
                    self.writeToAudioPipe(data: onData)
                    break
                default:
                    break
                }
            }
//            runStatsManager()
        }
    }
    
    func _Source(_ source: Source, type: SourceType, onPath: String) {
        
    }
    
    
    func _Source(_ source: Source, extra: [String : Any]) {
        switch self.recordingState {
        case .Recording(useBuffer: let useBuffer):
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
            break
        default:
            break
        }
    }
}
