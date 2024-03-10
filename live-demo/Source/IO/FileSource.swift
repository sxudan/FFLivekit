//
//  FileSource.swift
//  live-demo
//
//  Created by xkal on 11/3/2024.
//

import Foundation

class FileSource: Source {
    let path: String
    
    init(url: String) {
        self.path = url
        super.init(fileType: "mp4")
    }
}
