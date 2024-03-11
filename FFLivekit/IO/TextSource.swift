//
//  TextSource.swift
//  FFLivekit
//
//  Created by xkal on 12/3/2024.
//

import Foundation


public class TextSource: Source {
    
    public init(text: String, size: Int = 24, color: String = "black", duration: Int = 10) {
        super.init()
        command = "-f lavfi -i color=c=black:s=1280x720:r=30:d=10 -vf \"drawtext=text='\(text)':fontsize=\(size):fontcolor=\(color):x=(w-text_w)/2:y=(h-text_h)/2\" -t \(duration)"
        encoder = Encoder(str: "-c:v h264 -c:a aac")
    }
}
