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
        let bytesPerPixel = 4
        let bitsPerComponent = 8

        let dataSize = width * height * bytesPerPixel
        var rgbaData = [UInt8](repeating: 0, count: dataSize)

        return Data(bytes: &rgbaData, count: dataSize)
    }
    
}
