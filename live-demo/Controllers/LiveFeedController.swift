//
//  File.swift
//  live-demo
//
//  Created by xkal on 8/3/2024.
//

import UIKit
import AVFoundation
import ffmpegkit

enum RecState {
    case RequestRecording
    case RequestStop
    case Recording
    case Normal
}

class LiveFeedController: UIViewController, StreamPublisherDelegate {
   
    @IBOutlet weak var actionBtn: UIControl!
    let camera = CameraUtility(useAudioEngine: false)
    let publisher = StreamPublisher()
    let url = "rtmp://192.168.1.100:1935/mystream"
    @IBOutlet weak var fpsLabel: UILabel!
    
    var recState: RecState = .Normal {
        willSet {
            print(newValue)
            if newValue == .RequestRecording {
                initLoadingActionBtn()
                publisher.publish(url: url)
            } else if newValue == .Recording {
                initStopActionBtn()
            } else if newValue == .RequestStop {
                initLoadingActionBtn()
                publisher.stop()
            } else {
                initStartActionBtn()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        recState = .Normal
        camera.attach(view: self.view)
        publisher.attach(mediaUtil: camera)
        publisher.delegate = self
    }
    
    
    func initStartActionBtn() {
        actionBtn.layer.opacity = 1
        actionBtn.layer.cornerRadius = 25
        actionBtn.layer.masksToBounds = true
        actionBtn.isEnabled = true
    }
    
    func initLoadingActionBtn() {
        actionBtn.layer.opacity = 0.5
        actionBtn.isEnabled = false
    }
    
    func initStopActionBtn() {
        actionBtn.layer.opacity = 1
        actionBtn.layer.cornerRadius = 5
        actionBtn.layer.masksToBounds = false
        actionBtn.isEnabled = true
    }
    
    @IBAction func onActionTapped(_ sender: Any) {
        if recState == .Normal {
            recState = .RequestRecording
        } else if recState == .Recording {
            recState = .RequestStop
        }
    }
    
    func onStats(stats: Statistics) {
        self.fpsLabel.text = "FPS: \(stats.getVideoFps())"
    }
    
    func onRecordingStateChanged(isRecording: Bool) {
        if isRecording {
            self.recState = .Recording
        } else {
            self.recState = .Normal
        }
    }
}
