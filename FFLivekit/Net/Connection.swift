//
//  Connection.swift
//  live-demo
//
//  Created by xkal on 10/3/2024.
//

import Foundation

enum ConnectionError: Error {
    case SchemeError
}

public enum FileType: String {
    case RTSP = "rtsp"
    case RTMP = "flv"
    case MPEGTS = "mpegts"
}

public class Connection {
    
    let fileType: String!
    let baseUrl: String!
    
    public init(fileType: String, baseUrl: String) {
        self.fileType = fileType
        self.baseUrl = baseUrl
    }
}
