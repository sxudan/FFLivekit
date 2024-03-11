//
//  Encoder.swift
//  FFLivekit
//
//  Created by xkal on 11/3/2024.
//

import Foundation

public class Encoder: FFmpegBlock  {
    override init() {}
    
    init(str: String) {
        super.init()
        command = str
        
    }
}
