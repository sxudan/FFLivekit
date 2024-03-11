//
//  RTMPConnection.swift
//  live-demo
//
//  Created by xkal on 10/3/2024.
//

import Foundation

public class RTMPConnection: Connection {
    
    public init(baseUrl: String) throws {
        guard let url = URL(string: baseUrl), url.scheme == "rtmp" || url.scheme == "rtmps" else {
            throw ConnectionError.SchemeError
        }
        super.init(fileType: "flv", baseUrl: baseUrl)
    }
}
