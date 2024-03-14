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
    private var url = ""
    var ffmpegUtil: FFmpegUtils?
    private var delegate: FFLiveKitDelegate?
    
    private var sources: [Source] = []
    private var encoders: [Encoder] = []
    private var options: [FFLivekitSettings] = []
    
    public init(options: [FFLivekitSettings] = []) {
        self.options = options
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
        ffmpegUtil = FFmpegUtils(sources: sources, outputFormat: connection!.fileType, url: connection!.baseUrl, delegate: delegate, options: options)
    }
    
    public func addSources(sources: [Source]) {
        self.sources = sources
    }
    
    /// Publish the stream to the server. For example: <url>/mystream?pkt_size=1024:name=hello
    /// - Parameters:
    ///   - name: "mystream". name of the stream. No need to add /
    ///   - queryString: pkt_size=1024:name=hello. No need to add ?
    public func publish() throws {
        guard let connection = self.connection else {
            throw FFLiveKitError.NotInitialized
        }
        self.url = connection.baseUrl
        ffmpegUtil?.start()
    }
    
    public func stop() {
        for source in sources {
            source.stop()
        }
        ffmpegUtil?.stop()
    }
}
