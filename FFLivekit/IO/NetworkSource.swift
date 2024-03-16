//
//  NetworkSource.swift
//  FFLivekit
//
//  Created by xkal on 14/3/2024.
//

import Foundation
import ffmpegkit

public class NetworkSource: Source {
    
    let connection: Connection!
    public var pipe1: String?
    private var fileDescriptor: Int32!
    
    public init(connection: Connection) {
        self.connection = connection
        super.init()
        initFFmpeg()
    }
    
    public func initFFmpeg() {
        FFmpegKitConfig.enableLogCallback({log in
            guard let log = log else {
                return
            }
            print(log.getMessage())
        })
    }
    
    public override func start() {
        print("Starting")
        pipe1 = FFmpegKitConfig.registerNewFFmpegPipe()
        fileDescriptor = open(pipe1!, O_RDWR)
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("segment%d.mp4").path
        let cmd = "-re -i \(connection.baseUrl!) -fflags nobuffer+discardcorrupt+noparse+nofillin+ignidx+flush_packets+fastseek -avioflags direct -max_delay 0 -flags low_delay -f hls -hls_time 0 -hls_allow_cache 0 -hls_segment_filename \"\(tempFile)\" \(pipe1!)"
        
        
//        let cmd = "-re -i \(connection.baseUrl!) -c copy -f flv \(pipe1!)"
        print(cmd)
        FFmpegKitConfig.closeFFmpegPipe(pipe1)
        
        FFmpegKit.executeAsync(cmd, withCompleteCallback: {session in
            
        }, withLogCallback: {log in
//            print(log!.getMessage()!)
        }, withStatisticsCallback: {stats in
            self.readPipe()
        })
        
    }
    
    func readPipe() {
        if let currentPipe = self.pipe1 {
            self.delegate?._Source(self, type: .Video_Audio, onPath: currentPipe)
        }
//        if let currentPipe = self.pipe1, let fileHandle = try? FileHandle(forReadingAtPath: currentPipe) {
//            if #available(iOS 13.4, *) {
//                if let data = try? fileHandle.readToEnd() {
//                    self.delegate?._Source(self, type: .Video_Audio, onData: data)
//                }
//            } else {
//                // Fallback on earlier versions
//            }
//        } else {
//            print("Failed to open video file handle for reading")
//        }
    }
    
    public override func stop() {
        print("stopping")
        FFmpegKitConfig.closeFFmpegPipe(pipe1)
        if fileDescriptor != nil {
            close(fileDescriptor)
        }
        FFmpegKit.cancel()
    }
}
