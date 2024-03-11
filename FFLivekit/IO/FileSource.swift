//
//  FileSource.swift
//  live-demo
//
//  Created by xkal on 11/3/2024.
//

import Foundation

public class FileSource: Source {
    let path: String
    
    public init(filetype: String, url: String) {
        self.path = url
        super.init()
        command = "-f \(filetype) -i \(url)"
        encoder = Encoder(str: "-c:v h264 -c:a aac")
    }
}
