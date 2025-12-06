//
//  FFLiveKit.swift
//  live-demo
//
//  Created by xkal on 10/3/2024.
//

import Foundation

public enum FFLiveKitError: Error {
    case notInitialized
    case emptyUrl
    case noConnection
    case noSources
    case sourceMissingEncoder(Source)
    case ioError(message: String)
}

public protocol FFLiveKitDelegate: FFmpegUtilsDelegate {
    // Inherits all methods from FFmpegUtilsDelegate
}

public class FFLiveKit {

    private var connection: Connection?
    private var url = ""
    var ffmpegUtil: FFmpegUtils?
    private weak var delegate: FFLiveKitDelegate?
    
    private var sources: [Source] = []
    
    private var options: [FFLivekitSettings] = []
    
    public init(options: [FFLivekitSettings] = []) {
        self.options = options
    }
    
    
    public func connect(connection: Connection) throws {
        guard !connection.baseUrl.isEmpty else {
            throw FFLiveKitError.emptyUrl
        }
        self.connection = connection
    }
    
    public func prepare(delegate: FFLiveKitDelegate?) throws {
        guard let connection = connection else {
            throw FFLiveKitError.noConnection
        }
        
        guard !sources.isEmpty else {
            throw FFLiveKitError.noSources
        }
        
        self.delegate = delegate
        ffmpegUtil = FFmpegUtils(outputFormat: connection.fileType, url: connection.baseUrl, delegate: delegate, options: options)
        
        // Connect sources to FFmpeg pipeline
        for source in sources {
            source.delegate = ffmpegUtil
        }
    }
    
    public func addSources(_ sources: [Source]) {
        self.sources = sources
    }
    
//    public func addSource(camera: CameraSource?, microphone: MicrophoneSource?, file: FileSource?) {
//        self.cameraSource = camera
//        self.microphoneSource = microphone
//        self.fileSource = file
//        
//    }
    
    /// Publish the stream to the server. For example: <url>/mystream?pkt_size=1024:name=hello
    /// - Parameters:
    ///   - name: "mystream". name of the stream. No need to add /
    ///   - queryString: pkt_size=1024:name=hello. No need to add ?
    public func publish() throws {
        guard let connection = connection else {
            throw FFLiveKitError.notInitialized
        }
        
        guard let ffmpegUtil = ffmpegUtil else {
            throw FFLiveKitError.notInitialized
        }
        
        // Validate all sources have encoders
        for source in sources {
            guard source.encoder != nil else {
                throw FFLiveKitError.sourceMissingEncoder(source)
            }
        }
        
        let inputs = sources.map { $0.command }
        let encoders = sources.compactMap { $0.encoder?.command }
        
        guard encoders.count == sources.count else {
            throw FFLiveKitError.notInitialized
        }
        
        // Start all sources
        sources.forEach { $0.start() }
        
        // Start FFmpeg pipeline
        ffmpegUtil.start(inputcommands: inputs, encoders: encoders)
    }
    
    public func stop() {
        for source in sources {
            source.stop()
        }
        ffmpegUtil?.stop()
    }
}
