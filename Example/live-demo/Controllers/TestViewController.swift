//
//  TestViewController.swift
//  live-demo
//
//  Created by xkal on 10/3/2024.
//

import UIKit
import FFLivekit

class TestViewController: UIViewController, FFLiveKitDelegate {
    
   
    @IBOutlet weak var actionBtn: UIControl!
    
    @IBOutlet weak var fpsLabel: UILabel!
    @IBOutlet weak var audioRecLabel: UILabel!
    @IBOutlet weak var videoRecLabel: UILabel!
    
    let cameraSource = CameraSource(position: .front, preset: .hd1280x720)
    let microphoneSource = MicrophoneSource()
    let fileSource = FileSource(filetype: "rtsp", url: "rtsp://192.168.1.100:8554/mystream1")
    let ffLiveKit = FFLiveKit()
    var isRecording = false
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ffLiveKit.addSource(camera: cameraSource, microphone: microphoneSource, file: nil)
        cameraSource.startPreview(previewView: self.view)
        /// initialize the connections
        let srtConnection = try! SRTConnection(baseUrl: "srt://192.168.1.100:8890?streamid=publish:mystream&pkt_size=1316")
        let rtmpConnection = try! RTMPConnection(baseUrl: "rtmp://192.168.1.100:1935/mystream")
        let rtspConnection = try! RTSPConnection(baseUrl: "rtsp://192.168.1.100:8554/mystream")
        let udpConnection = try! UDPConnection(baseUrl: "udp://192.168.1.100:1234?pkt_size=1316")
        try! ffLiveKit.connect(connection: rtmpConnection)
        ffLiveKit.prepare(delegate: self)
        initStartActionBtn()
    }
    
    func _FFLiveKit(didChange status: RecordingState) {
        print(status)
        if status == .RequestRecording {
            initLoadingActionBtn()
        } else if status == .Recording {
            isRecording = true
            initStopActionBtn()
        } else if status == .RequestStop {
            initLoadingActionBtn()
        } else {
            isRecording = false
            initStartActionBtn()
        }
    }
    
    func _FFLiveKit(onStats stats: FFStat) {
        self.fpsLabel.text = "FPS: \(stats.fps)"
        self.videoRecLabel.text = "Video Recording: \(stats.isVideoRecording)"
        self.audioRecLabel.text = "Audio Recording: \(stats.isAudioRecording)"
    }
    
    func _FFLiveKit(onError error: String) {
        print("Error \(error)")
    }
    
    @IBAction func onTap(_ sender: Any) {
        if !isRecording {
            try? ffLiveKit.publish()
        } else {
            ffLiveKit.stop()
        }
    }
    
    @IBAction func toggleTorch(_ sender: Any) {
        cameraSource.toggleTorch()
    }
    
    @IBAction func onCameraSwitch(_ sender: Any) {
        cameraSource.switchCamera()
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
}
