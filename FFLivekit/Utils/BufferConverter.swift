//
//  BufferConverter.swift
//  live-demo
//
//  Created by xkal on 10/3/2024.
//


import AVFAudio

class BufferConverter {
    class func bufferToData(buffer: AVAudioPCMBuffer) -> Data {
        let channelData = buffer.int16ChannelData![0]
        let dataSize = Int(buffer.frameLength) * MemoryLayout<Int16>.size
        let data = Data(bytes: channelData, count: dataSize)
        return data
    }
    
    class func extractBGRAData(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let byteBuffer = UnsafeBufferPointer(start: baseAddress.assumingMemoryBound(to: UInt8.self), count: bytesPerRow * height)
        let rawPointer = UnsafeRawPointer(byteBuffer.baseAddress!)
        return Data(bytes: rawPointer, count: bytesPerRow * height)
    }
    
    class func createEmptyRGBAData(width: Int, height: Int) -> Data {
        let bytesPerPixel = 4 // Assuming BGRA format (8 bits per channel)
        let bitsPerComponent = 8
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow

        // Allocate a single Data object with the total size
        var pixelData = Data(count: totalBytes * 2)
        return pixelData
    }
    
    class func convert(from inputFormat: AVAudioFormat, to outputFormat: AVAudioFormat, buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)!
        var newBufferAvailable = true
        let inputCallback: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            if newBufferAvailable {
                outStatus.pointee = .haveData
                newBufferAvailable = false
                return buffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }
        let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(outputFormat.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate))!
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputCallback)
        assert(status != .error)
        return convertedBuffer
    }
}
