//
//  RTSPConnection.swift
//  live-demo
//
//  Created by xkal on 10/3/2024.
//

import Foundation

class RTSPConnection: Connection {
    init(baseUrl: String) {
        super.init(fileType: "rtsp", baseUrl: baseUrl)
    }
}
