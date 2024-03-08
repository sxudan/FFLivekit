//
//  Helper.swift
//  live-demo
//
//  Created by xkal on 7/3/2024.
//

import Foundation
import CoreGraphics

class Helper {
    static func createEmptyRGBAData(width: Int, height: Int) -> Data? {
        // RGBA color space

        // Allocate memory for image data
        let bytesPerPixel = 4
        let bitsPerComponent = 8
        let bytesPerRow = width * bytesPerPixel
        let imageData = UnsafeMutablePointer<UInt8>.allocate(capacity: height * bytesPerRow)
 
        return Data(bytes: imageData, count: height * bytesPerRow)
    }
    
}
