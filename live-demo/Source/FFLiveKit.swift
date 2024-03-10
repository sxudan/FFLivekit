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

protocol FFLiveKitDelegate: FFmpegUtilsDelegate {
    
}

class FFLiveKit {

    private var connection: Connection?
    private var cameraSource: CameraSource?
    private var microphoneSource: MicrophoneSource?
    private var url = ""
    var ffmpegUtil: FFmpegUtils?
    private var delegate: FFLiveKitDelegate?
    
    func connect(connection: Connection) throws {
        /// compute url
        if connection.baseUrl.isEmpty {
            throw FFLiveKitError.EmptyUrl
        }
        self.connection = connection
    }
    
    func prepare(delegate: FFLiveKitDelegate?) {
        self.delegate = delegate
        ffmpegUtil = FFmpegUtils(outputFormat: connection!.fileType, url: connection!.baseUrl, delegate: delegate)
        /// delegate
        cameraSource?.delegate = ffmpegUtil
        microphoneSource?.delegate = ffmpegUtil
    }
    
    func addSource(camera: CameraSource?, microphone: MicrophoneSource?) {
        self.cameraSource = camera
        self.microphoneSource = microphone
        
    }
    
    func publish(name: String?) throws {
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
        ffmpegUtil?.start(videoRec: self.cameraSource != nil, audioRec: self.microphoneSource != nil, streamName: name)
    }
    
    func stop() {
        cameraSource?.stop()
        microphoneSource?.stop()
        ffmpegUtil?.stop()
    }
}
