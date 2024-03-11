//
//  RTSPConnection.swift
//  live-demo
//
//  Created by xkal on 10/3/2024.
//

import Foundation

public class RTSPConnection: Connection {
    public init(baseUrl: String) throws {
        guard let url = URL(string: baseUrl), url.scheme == "rtsp" else {
            throw ConnectionError.SchemeError
        }
        super.init(fileType: FileType.RTSP.rawValue, baseUrl: baseUrl)
    }
}
