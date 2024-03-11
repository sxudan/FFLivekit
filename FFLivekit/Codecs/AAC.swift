//
//  AAC.swift
//  FFLivekit
//
//  Created by xkal on 11/3/2024.
//

import Foundation

public class AACEncoder: Encoder {
    public init() {
        super.init(str: "-c:a aac")
    }
}
