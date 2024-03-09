//
//  Helper.swift
//  live-demo
//
//  Created by xkal on 7/3/2024.
//

import Foundation
import CoreGraphics

class Helper {
    static func createEmptyRGBAData(width: Int, height: Int) -> Data {
        let bytesPerPixel = 4 // Assuming BGRA format (8 bits per channel)
        let bitsPerComponent = 8
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow

        // Allocate a single Data object with the total size
        var pixelData = Data(count: totalBytes * 2)
        return pixelData
    }
    
    
}
