//
//  StreamPublisher.swift
//  live-demo
//
//  Created by xkal on 8/3/2024.
//


import AVFoundation
import ffmpegkit

protocol StreamPublisherDelegate {
    func onStats(stats: Statistics)
    func onRecordingStateChanged(isRecording: Bool)
}

class StreamPublisher: NSObject, AudioVideoDelegate {
    
    private let background = DispatchQueue.global(qos: .background)
    private let videoFeedThread = DispatchQueue.global(qos: .background)
    private let audioFeedThread = DispatchQueue.global(qos: .background)
    private var url: String?
    private var running = false
    private var videoPipe: String?
    private var audioPipe: String?
    private var videoFileDescriptor: Int32!
    private var audioFileDescriptor: Int32!
    private var videoTimer: Timer?
    private var audioTimer: Timer?
    private let videoBufferLock = NSLock()
    private var videoDataBuffer = Data()
    
    private let audioBufferLock = NSLock()
    private var audioDataBuffer = Data()
    
    private var cameraUtility: CameraUtility?
    
    var delegate: StreamPublisherDelegate?
    
    private var isRecording = false
    
    override init () {
        super.init()
        initFFmpeg()
    }
    
    func attach(mediaUtil: CameraUtility) {
        self.cameraUtility = mediaUtil
        self.cameraUtility?.setDelegate(delegate: self)
    }
    
    func initFFmpeg() {
        FFmpegKitConfig.enableLogCallback({log in
            if let log = log {
                print(log.getMessage()!)
            }
        })
    }
    
    func publish(url: String) {
        self.url = url
        self.cameraUtility?.startAudioCapture()
        self.running = true
        // create a pipe for video
        videoPipe = FFmpegKitConfig.registerNewFFmpegPipe()
        audioPipe = FFmpegKitConfig.registerNewFFmpegPipe()
        // open the videopipe so that ffempg doesnot closes when the video pipe receives EOF
        videoFileDescriptor = open(videoPipe!, O_RDWR)
        audioFileDescriptor = open(audioPipe!, O_RDWR)
        /// Start FFMPEG
        background.async {
            self.executeVideo_Audio()
        }
        startTimer()
    }
    
    func appendToVideoBuffer(data: Data) {
        videoFeedThread.sync {
//            print("appending video___")
            self.videoBufferLock.lock()
            self.videoDataBuffer.append(data)
            self.videoBufferLock.unlock()
        }
    }
    
    func appendToAudioBuffer(data: Data) {
        audioFeedThread.async {
//            print("appending audio___")
            self.audioBufferLock.lock()
            self.audioDataBuffer.append(data)
            self.audioBufferLock.unlock()
        }
    }
    
    func stop() {
        running = false
        stopTimer()
        closePipes()
        stopFFmpeg()
        self.audioDataBuffer.removeAll()
        self.videoDataBuffer.removeAll()
        self.isRecording = false
        DispatchQueue.main.async {
            self.delegate?.onRecordingStateChanged(isRecording: false)
        }
    }
    
    func closePipes() {
        if videoFileDescriptor != nil {
            close(videoFileDescriptor)
        }
        if audioFileDescriptor != nil {
            close(audioFileDescriptor)
        }
        FFmpegKitConfig.closeFFmpegPipe(videoPipe)
        FFmpegKitConfig.closeFFmpegPipe(audioPipe)
    }
    
    func stopFFmpeg() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            FFmpegKit.cancel()
        })
    }
    
    private func startTimer() {
        DispatchQueue.global().async {
            self.videoTimer = Timer.scheduledTimer(timeInterval: 0.005, target: self, selector: #selector(self.feedToVideoPipe), userInfo: nil, repeats: true)
            RunLoop.current.add(self.videoTimer!, forMode: .default)
            RunLoop.current.run()
        }
//        DispatchQueue.global().async {
//            self.audioTimer = Timer.scheduledTimer(timeInterval: 0.005, target: self, selector: #selector(self.feedToAudioPipe), userInfo: nil, repeats: true)
//            RunLoop.current.add(self.audioTimer!, forMode: .default)
//            RunLoop.current.run()
//        }
    }
    
    private func stopTimer() {
        videoTimer?.invalidate()
        audioTimer?.invalidate()
        videoTimer = nil
        audioTimer = nil
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
        self.audioFeedThread.sync {
//            print("Feeding audio")
            self.audioBufferLock.lock()
            // Feed audio
            if !self.audioDataBuffer.isEmpty {
                self.writeToAudioPipe(data: self.audioDataBuffer)
                self.audioDataBuffer.removeAll()
            }
            self.audioBufferLock.unlock()
        }
    }
    
    private func executeVideoOnly() {
        let cmd = "-f rawvideo -pixel_format bgra -video_size 1920x1080 -framerate 30 -i \(videoPipe!) -framerate 30 -pixel_format yuv420p -c:v h264 -an -vf \"transpose=1,scale=360:640\" -b:v 2M -f flv \(url!)"
        execute(cmd: cmd)
    }
    
    private func executeAudioOnly() {
        let cmd = "-f s16le -ar 44100 -ac 1 -i \(audioPipe!) -vn -c:a aac -f rtsp \(url!)"
        execute(cmd: cmd)
    }
    
    private func executeVideo_Audio() {
        let cmd = "-re -f rawvideo -pixel_format bgra -video_size 1920x1080 -framerate 30 -i \(videoPipe!) -f s16le -ar 44100 -ac 1 -itsoffset -5 -i \(audioPipe!) -framerate 30 -pixel_format yuv420p -c:v h264 -c:a aac -vf \"transpose=1,scale=1080:1920\" -b:v 2M -vsync 1 -f flv \(url!)"
 
        execute(cmd: cmd)
    }
    
    private func execute(cmd: String) {
        print("Executing \(cmd)..........")
        FFmpegKit.executeAsync(cmd, withCompleteCallback: {session in
            self.stop()
        }, withLogCallback: nil, withStatisticsCallback: {stats in
            if stats != nil, stats?.getSessionId() != nil {
                if self.isRecording == false {
                    DispatchQueue.main.async {
                        self.delegate?.onRecordingStateChanged(isRecording: true)
                    }
                }
                self.isRecording = true
                DispatchQueue.main.async {
                    self.delegate?.onStats(stats: stats!)
                }
            }
        })
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
//                print("Data written successfully")
            } else {
                print("Failed to open file handle for writing")
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
//                print("Audio written successfully")
            } else {
                print("Failed to open file handle for writing")
            }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output is AVCaptureVideoDataOutput {
//            print("Video")
            if self.running, let data = extractBGRAData(from: sampleBuffer) {
                if !self.isRecording {
                    self.writeToVideoPipe(data: data)
                } else {
                    self.appendToVideoBuffer(data: data)
                }
            }
        } else if output is AVCaptureAudioDataOutput {
//            print("Audio")
//            print(sampleBuffer)
            if self.running, let data = convertCMSampleBufferToPCM16Data(sampleBuffer: sampleBuffer) {
                self.writeToAudioPipe(data: data)
//                self.appendToAudioBuffer(data: data)
            }
        }
        
    }
    
    func convertCMSampleBufferToPCM16Data(sampleBuffer: CMSampleBuffer) -> Data? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }

        guard let data = NSMutableData(length: CMBlockBufferGetDataLength(blockBuffer)) else {
            return nil
        }

        CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: CMBlockBufferGetDataLength(blockBuffer), destination: data.mutableBytes)

        return data as Data
    }
    
    func extractBGRAData(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let byteBuffer = UnsafeBufferPointer(start: baseAddress.assumingMemoryBound(to: UInt8.self), count: bytesPerRow * height)

        let rawPointer = UnsafeRawPointer(byteBuffer.baseAddress!)
        
        return Data(bytes: rawPointer, count: bytesPerRow * height)
    }
    
    func onAudioEngine(data didReceived: Data) {
        if self.running {
            self.writeToAudioPipe(data: didReceived)
        }
    }
}
