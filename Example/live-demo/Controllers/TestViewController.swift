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
    let microphoneSource = try! MicrophoneSource()
    let fileSource = FileSource(filetype: "mp4", url: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
    let ffLiveKit = FFLiveKit(options: [.outputVideoSize((360, 640)), .outputVideoBitrate("400k")])
    var isRecording = false
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup camera preview
        cameraSource.startPreview(previewView: self.view)
        
        // Add sources
        ffLiveKit.addSources([cameraSource, microphoneSource])
        
        // Initialize connections (example - choose one)
        do {
            // You can choose any of these connection types:
             let srtConnection = try SRTConnection(baseUrl: "srt://192.168.0.135:8890?streamid=publish:mystream&pkt_size=1316")
//             let rtmpConnection = try RTMPConnection(baseUrl: "rtmp://192.168.0.135:1935/mystream")
//            let rtspConnection = try RTSPConnection(baseUrl: "rtsp://192.168.0.135:8554/mystream")
            // let udpConnection = try UDPConnection(baseUrl: "udp://192.168.1.100:1234?pkt_size=1316")
            
            try ffLiveKit.connect(connection: srtConnection)
            try ffLiveKit.prepare(delegate: self)
        } catch {
            print("Failed to setup FFLiveKit: \(error)")
        }
        
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
    }
    
    func _FFLiveKit(onError error: String) {
        print("Error \(error)")
    }
    
    @IBAction func onTap(_ sender: Any) {
        if !isRecording {
            do {
                try ffLiveKit.publish()
            } catch {
                print("Failed to publish: \(error)")
                // Show error to user
                let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
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
