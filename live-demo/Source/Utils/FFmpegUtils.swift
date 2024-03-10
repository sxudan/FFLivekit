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

class FFStat {
    
    let bitrate: Double
    let size: Int
    let time: Double
    let speed: Double
    let rate: Double
    let fps: Float
    let quality: Float
    let frameNumber: Int32
    let sessionId: Int
    let isVideoRecording: Bool
    let isAudioRecording: Bool
    
    init(stat: Statistics, isVideoRecording: Bool, isAudioRecording: Bool) {
        bitrate = stat.getBitrate()
        size = stat.getSize()
        time = stat.getTime()
        speed = stat.getSpeed()
        rate = stat.getBitrate()
        fps = stat.getVideoFps()
        quality = stat.getVideoQuality()
        frameNumber = stat.getVideoFrameNumber()
        sessionId = stat.getSessionId()
        self.isAudioRecording = isAudioRecording
        self.isVideoRecording = isVideoRecording
    }
    
    
}

enum RecordingState {
    case RequestRecording
    case Recording
    case RequestStop
    case Normal
}

protocol FFmpegUtilsDelegate {
    func FFmpegUtils(didChange status: RecordingState)
    func FFmpegUtils(onStats stats: FFStat)
}


struct FFmpegOptions {
    /// input settings
    var inputVideoFileType: String
    var inputVideoPixelFormat: String
    var inputVideoSize: (Int, Int)
    var inputAudioFileType: String
    var inputAudioRate: Int
    var inputAudioChannel: Int
    var inputAudioItsOffset: Int
    var outputVideoFramerate: Int
    var outputVideoCodec: String
    var outputVideoPixelFormat: String
    var outputVideoSize: (Int, Int)
    var outputVideoBitrate: String
    var outputAudioBitrate: String
    var outputAudioCodec: String
    var inputFilePath: String
}

class FFmpegUtils: NSObject, CameraSourceDelegate, MicrophoneSourceDelegate {
    
    var audioPipe: String?
    var videoPipe: String?
    
    var outputFormat = ""
    var baseUrl = ""
    var streamName: String?
    
    let options: FFmpegOptions!
    
    
    var url: String {
        get {
            if streamName != nil {
                return "\(baseUrl)/\(streamName!)"
            } else {
                return baseUrl
            }
        }
    }
    
    var running = false
    var isInBackground = false
    var isVideoRecording = false
    var isAudioRecording = false
    
    private var videoTimer: Timer?
    private var blankFrames: Data?
    private var videoFileDescriptor: Int32!
    private var audioFileDescriptor: Int32!
    
    var recordingType = RecordingType.Camera_Microphone
    
    /// threads
    private let background = DispatchQueue.global(qos: .background)
    private let videoFeedThread = DispatchQueue.global(qos: .background)
    
    /// buffers and locks
    private let videoBufferLock = NSLock()
    private var videoDataBuffer = Data()
    
    private var delegate: FFmpegUtilsDelegate?
    
    init(outputFormat: String, url: String,options: FFmpegOptions, delegate: FFmpegUtilsDelegate?) {
        self.options = options
        super.init()
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
    }
    
    // Remove observers when the view controller is deallocated
    deinit {
        NotificationCenter.default.removeObserver(self)
        videoDataBuffer.removeAll()
    }
    
    
    var recordingState: RecordingState = .Normal {
        willSet {
            DispatchQueue.main.async {
                self.delegate?.FFmpegUtils(didChange: newValue)
            }
            switch newValue {
            case .Normal:
                running = false
                break
            case .RequestRecording:
                clearVideoBuffer()
                running = true
                /// initialize pipes
                createPipes()
                background.async {
                    if self.recordingType == .Camera_Microphone {
                        self.executeVideo_Audio()
                    } else if self.recordingType == .Camera {
                        self.executeVideoOnly()
                    } else if self.recordingType == .Microphone {
                        self.executeAudioOnly()
                    } else if self.recordingType == .File {
                        self.executeFile()
                    }
                }
                startTimer()
                break
            case .Recording:
                running = true
                break
            case .RequestStop:
                running = false
                stopTimer()
                closePipes()
                clearVideoBuffer()
                FFmpegKit.cancel()
                clearVideoBuffer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    self.recordingState = .Normal
                })
                break
            }
        }
    }
    
    func start(videoRec: Bool = true, audioRec: Bool = true, fileRec: Bool, streamName: String?) {
        self.streamName = streamName
        if videoRec && audioRec {
            self.recordingType = .Camera_Microphone
        } else if videoRec {
            self.recordingType = .Camera
        } else if audioRec {
            self.recordingType = .Microphone
        } else if fileRec {
            self.recordingType = .File
        }
        recordingState = .RequestRecording
    }
    
    func stop() {
        recordingState = .RequestStop
    }
    
    private func stopTimer() {
        videoTimer?.invalidate()
        videoTimer = nil
    }
    
    private func startTimer() {
        DispatchQueue.global().async {
            self.videoTimer = Timer.scheduledTimer(timeInterval: 0.005, target: self, selector: #selector(self.handleFeed), userInfo: nil, repeats: true)
            RunLoop.current.add(self.videoTimer!, forMode: .default)
            RunLoop.current.run()
        }
    }
    
    @objc func handleFeed() {
        if isInBackground {
            self.appendToVideoBuffer(data: self.blankFrames!)
            if self.videoDataBuffer.count > 10*1000000 {
                print("Flushing....")
                self.feedToVideoPipe()
            }
        } else {
            feedToVideoPipe()
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
    
    func clearVideoBuffer() {
        self.videoBufferLock.lock()
        self.videoDataBuffer.removeAll()
        self.videoBufferLock.unlock()
    }
    
    private func generateVideoInputCommand() -> String {
        return "-f \(options.inputVideoFileType) -pixel_format \(options.inputVideoPixelFormat) -video_size \(options.inputVideoSize.0)x\(options.inputVideoSize.1) -framerate 30 -i \(videoPipe!)"
    }
    
    private func generateAudioInputCommand() -> String {
        return "-f \(options.inputAudioFileType) -ar \(options.inputAudioRate) -ac \(options.inputAudioChannel) -itsoffset \(options.inputAudioItsOffset) -i \(audioPipe!)"
    }
    
    private func generateVideoOutputCommand() -> String {
        return "-framerate \(options.outputVideoFramerate) -pixel_format \(options.outputVideoPixelFormat) -c:v \(options.outputVideoCodec) -vf \"transpose=1,scale=\(options.outputVideoSize.0):\(options.outputVideoSize.1)\" -b:v \(options.outputVideoBitrate)"
    }
    
    private func generateAudioOutputCommand() -> String {
        return "-c:a \(options.outputAudioCodec) -b:a \(options.outputAudioBitrate)"
    }
    
    private func executeVideoOnly() {
        let cmd = "-re \(generateVideoInputCommand()) \(generateVideoOutputCommand()) -f \(outputFormat) \(url)"
        execute(cmd: cmd)
    }
    
    private func executeAudioOnly() {
        let cmd = "-re \(generateAudioInputCommand()) -vn \(generateAudioOutputCommand()) -f \(outputFormat) \(url)"
        execute(cmd: cmd)
    }
    
    private func generateFileInputCommand() -> String {
        return "-f \(options.inputVideoFileType) -i \(options.inputFilePath)"
    }
    
    private func generateFileOutputCommand() -> String {
        return "-c:v \(options.outputVideoCodec) -c:a \(options.outputAudioCodec)"
    }
    
    private func executeVideo_Audio() {
        let cmd = "-re \(generateVideoInputCommand()) \(generateAudioInputCommand()) \(generateVideoOutputCommand()) \(generateAudioOutputCommand()) -vsync 1 -f \(outputFormat) \(url)"
        
        execute(cmd: cmd)
    }
    
    private func executeFile() {
        let cmd = "-re \(generateFileInputCommand()) \(generateFileOutputCommand()) -f \(outputFormat) \(url)"
        execute(cmd: cmd)
    }
    
    private func execute(cmd: String) {
        print("Executing \(cmd)..........")
        FFmpegKit.executeAsync(cmd, withCompleteCallback: {session in
            self.stop()
        }, withLogCallback: nil, withStatisticsCallback: {stats in
            guard let stats = stats else {
                return
            }
            /// For Video
            if stats.getVideoFps() > 0 {
                if self.isVideoRecording == false {
                    DispatchQueue.main.async {
                        //                            self.delegate?.didVideoRecordingStatusChanged(isVideoRecording: true)
                    }
                }
                self.isVideoRecording = true
            } else if stats.getSize() > 0, stats.getVideoFps() == 0 {
                if self.isAudioRecording == false {
                    DispatchQueue.main.async {
                        //                            self.delegate?.didAudioRecordingStatusChanged(isAudioRecording: true)
                    }
                }
                self.isAudioRecording = true
            }
            if self.recordingState == .RequestRecording {
                if self.recordingType == .Camera_Microphone {
                    if self.isVideoRecording && self.isAudioRecording {
                        self.recordingState = .Recording
                    }
                } else if self.recordingType == .Microphone {
                    if self.isAudioRecording {
                        self.recordingState = .Recording
                    }
                } else if self.recordingType == .Camera {
                    if self.isVideoRecording {
                        self.recordingState = .Recording
                    }
                } else if self.recordingType == .File {
                    self.recordingState = .Recording
                }
            }
            DispatchQueue.main.async {
                self.delegate?.FFmpegUtils(onStats: FFStat(stat: stats, isVideoRecording: self.isVideoRecording, isAudioRecording: self.isAudioRecording))
            }
        })
    }
    
    func _CameraSource(onData: Data) {
        if !self.isInBackground, self.running, let data = isInBackground ? blankFrames : onData {
            if !self.isVideoRecording {
                self.writeToVideoPipe(data: data)
            } else {
                self.appendToVideoBuffer(data: data)
            }
        }
    }
    
    func _CameraSource(switchStarted: Bool) {
        running = false
        clearVideoBuffer()
    }
    
    func _CameraSource(switchEnded: Bool) {
        running = true
    }
    
    func _MicrophoneSource(onData: Data) {
        if self.running {
            self.writeToAudioPipe(data: onData)
        }
    }
}
