//
//  Source.swift
//  live-demo
//
//  Created by xkal on 11/3/2024.
//

import Foundation

public enum SourceType {
    case Audio
    case Video
}

public protocol SourceDelegate {
    func _Source(_ source: Source,type: SourceType, onData: Data)
    func _Source(_ source: Source, extra: [String: Any])
}

public class Source: FFmpegBlock {
    var delegate: SourceDelegate?
    var encoder: Encoder?
    
    public func start() {}
    public func stop() {}
}
