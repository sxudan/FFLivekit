//
//  H264_VT.swift
//  FFLivekit
//
//  Created by xkal on 11/3/2024.
//

import Foundation

public class H264_VTEncoder: Encoder {
    public override init() {
        super.init()
        self.command = "-c:v h264_videotoolbox"
    }
}
