//
//  FFLiveKit.swift
//  live-demo
//
//  Created by xkal on 10/3/2024.
//

import Foundation

enum FFLiveKitError: Error {
    case NotInitialized
    case EmptyUrl
    case IOError(message: String)
}

public protocol FFLiveKitDelegate: FFmpegUtilsDelegate {
    
}

public class FFLiveKit {

    private var connection: Connection?
    private var cameraSource: CameraSource?
    private var microphoneSource: MicrophoneSource?
    private var fileSource: FileSource?
    private var url = ""
    var ffmpegUtil: FFmpegUtils?
    private var delegate: FFLiveKitDelegate?
    
    public init() {
        
    }
    
    
    public func connect(connection: Connection) throws {
        /// compute url
        if connection.baseUrl.isEmpty {
            throw FFLiveKitError.EmptyUrl
        }
        self.connection = connection
    }
    
    public func prepare(delegate: FFLiveKitDelegate?) {
        self.delegate = delegate
        ffmpegUtil = FFmpegUtils(outputFormat: connection!.fileType, url: connection!.baseUrl, options: FFmpegOptions(
            inputVideoFileType: fileSource != nil ? (fileSource?.type ?? "") : (cameraSource?.type ?? ""),
            inputVideoPixelFormat: "bgra",
            inputVideoSize: cameraSource != nil ? (cameraSource!.getDimensions().0, cameraSource!.getDimensions().1) : (0, 0),
            inputAudioFileType: microphoneSource?.type ?? "",
            inputAudioRate: 48000,
            inputAudioChannel: 1,
            inputAudioItsOffset: -5,
            outputVideoFramerate: 30,
            outputVideoCodec: "h264",
            outputVideoPixelFormat: "bgra",
            outputVideoSize: (360, 640),
            outputVideoBitrate: "640k",
            outputAudioBitrate: "64k",
            outputAudioCodec: "aac", inputFilePath: fileSource?.path ?? ""), delegate: delegate)
        /// delegate
        cameraSource?.delegate = ffmpegUtil
        microphoneSource?.delegate = ffmpegUtil
    }
    
    public func addSource(camera: CameraSource?, microphone: MicrophoneSource?, file: FileSource?) {
        self.cameraSource = camera
        self.microphoneSource = microphone
        self.fileSource = file
        
    }
    
    public func publish(name: String?) throws {
        guard let connection = self.connection else {
            throw FFLiveKitError.NotInitialized
        }
        self.url = connection.baseUrl + "/" + (name ?? "")
        /// start
        cameraSource?.start()
        do {
            try microphoneSource?.start()
        } catch {
            throw FFLiveKitError.IOError(message: error.localizedDescription)
        }
        ffmpegUtil?.start(videoRec: self.cameraSource != nil, audioRec: self.microphoneSource != nil, fileRec: self.fileSource != nil, streamName: name)
    }
    
    public func stop() {
        cameraSource?.stop()
        microphoneSource?.stop()
        ffmpegUtil?.stop()
    }
}
