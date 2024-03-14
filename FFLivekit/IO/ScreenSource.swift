//
//  Screencapture.swift
//  FFLivekit
//
//  Created by xkal on 14/3/2024.
//

import AVFoundation
import ReplayKit

public class ScreenSource: Source {
    
//    private var screenRecorder = RPScreenRecorder.shared()
    private var screenRecorder = RPBroadcastController()
    
    var view: UIView?

    
    public init(encoder: Encoder = H264_VTEncoder()) {
        
        super.init()
        self.encoder = encoder
        command = "-f rawvideo -pixel_format bgra -video_size \(888)x\(1920) -framerate 30 -i %videoPipe%"
    }
    
    public func startPreview(view: UIView) {
        self.view = view
    }
    
    public override func start() {
        DispatchQueue.global().async {[weak self] in
            guard let this = self else {
                return
            }
            this.screenRecorder.startBroadcast(handler: {error in
                    print(error)
            })
//            if this.screenRecorder.isAvailable {
//                this.screenRecorder.startCapture(handler: {sampleBuffer, type, error in
//                    switch type {
//                    case .video:
//                        if this.screenRecorder.isRecording, let data = BufferConverter.extractBGRAData(from: sampleBuffer) {
//                            print("Sending \(data)")
//                            this.delegate?._Source(this, type: .Video, onData: data)
//                        }
//                    default:
//                        break
//                    }
//                }, completionHandler: {error in
//                        print(error)
//                })
//            }
        }
    }
    
    public override func stop() {
//        screenRecorder.stopCapture()
    }
    
    
    
}
