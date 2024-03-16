//
//  TestViewController.swift
//  live-demo
//
//  Created by xkal on 10/3/2024.
//

import UIKit
import FFLivekit
import MobileVLCKit

class TestViewController: UIViewController, FFLiveKitDelegate {
    
   
    @IBOutlet weak var actionBtn: UIControl!
    
    @IBOutlet weak var fpsLabel: UILabel!
    @IBOutlet weak var audioRecLabel: UILabel!
    @IBOutlet weak var videoRecLabel: UILabel!
    
    let cameraSource = CameraSource(position: .front, preset: .hd1280x720)
//    let screenSource = ScreenSource()
    let microphoneSource = try! MicrophoneSource()
    let fileSource = FileSource(filetype: "mp4", url: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
    let ffLiveKit = FFLiveKit(options: [.outputVideoSize((360, 640)), .outputVideoBitrate("400k")])
    var isRecording = false
    
    var vlcPlayer = VLCMediaPlayer()
    

//    var player: FFLivePlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        player = FFLivePlayer(source: NetworkSource(connection: Connection(fileType: "", baseUrl: "rtsp://192.168.1.100:8554/mystream")), view: self.view)
//        initVlc()
        initialisePusher()
    }
    
    func initialisePusher() {
        ffLiveKit.addSources(sources: [cameraSource,microphoneSource])
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
    
    func initVlc() {
        vlcPlayer.drawable = self.view
        vlcPlayer.media = VLCMedia(url: URL(string: "rtsp://192.168.1.100:8554/mystream")!)
    }
    
    func _FFLiveKit(didChange status: RecordingState) {
        print(status)
        self.videoRecLabel.text = "\(status)"
        switch status {
        case .RequestRecording, .Booting:
            initLoadingActionBtn()
            break
        case .Recording, .BackgroundRecording:
            isRecording = true
            initStopActionBtn()
            break
        case .RequestStop:
            initLoadingActionBtn()
            break
        default:
            isRecording = false
            initStartActionBtn()
            break
        }
    }
    
    func _FFLiveKit(onStats stats: FFStat) {
        self.fpsLabel.text = "FPS: \(stats.fps)"
        self.audioRecLabel.text = "Video Buff = \(stats.currentVideoBufferSize), Audio Buff = \(stats.currentAudioBufferSize)"
    }
    
    func _FFLiveKit(onError error: String) {
        print("Error \(error)")
    }
    
    @IBAction func onTap(_ sender: Any) {
        if !isRecording {
//            vlcPlayer.play()
            try? ffLiveKit.publish()
//            screenSource.start()

            
        } else {
//            vlcPlayer.stop()
//            player?.stop()
            ffLiveKit.stop()
//            screenSource.stop()
    
        }
//        isRecording = !isRecording
    }
    
    @IBAction func toggleTorch(_ sender: Any) {
//        cameraSource.toggleTorch()
    }
    
    @IBAction func onCameraSwitch(_ sender: Any) {
//        cameraSource.switchCamera()
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
