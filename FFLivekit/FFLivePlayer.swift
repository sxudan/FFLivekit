//
//  FFLivePlayer.swift
//  FFLivekit
//
//  Created by xkal on 15/3/2024.
//

import Foundation
import AVFoundation

public class FFLivePlayer: NSObject, SourceDelegate, AVAssetResourceLoaderDelegate, AssetPlaybackDelegate {
    
//    var playerManager = AssetPlaybackManager.sharedManager
    var player: AVPlayer?
    var source: NetworkSource!
    var view: UIView?
    var asset: AVURLAsset?
    
    public init(source: NetworkSource, view: UIView) {
        super.init()
//        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("temp.m3u8")
        self.view = view
        self.source = source
        self.source.delegate = self
//        initPlayer(url: nil)
//        AssetPlaybackManager.sharedManager.delegate = self
        
//        AssetPlaybackManager.sharedManager.setAssetForPlayback(nil)
        
        player = AVPlayer()
        initPlayer()
    }
    
    var timer: Timer?
    
    private func initPlayer() {
        guard let player = self.player else {
            return
        }
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view!.bounds
        playerLayer.videoGravity = .resizeAspectFill
        view!.layer.insertSublayer(playerLayer, at: 0)
        // Optionally, observe AVQueuePlayer's playback status
        player.addObserver(self, forKeyPath: "status", options: .new, context: nil)
        // Add observer to handle player item's playback status changes
        player.addObserver(self, forKeyPath: "currentItem.status", options: .new, context: nil)
    }
    
    public func play() {
//        AssetPlaybackManager.sharedManager.setAssetForPlayback(AVURLAsset(url: URL(string: "http://192.168.1.100:8888/mystream/index.m3u8")!))
        source.start()
//        if let currentPipe = self.source.pipe1 {
//            print("Pipe = \(currentPipe)")
//            playerManager.setAssetForPlayback(AVURLAsset(url: URL(fileURLWithPath: currentPipe)))
//        }
//        player.play()
//        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(onFeed), userInfo: nil, repeats: true)
    }
    
    @objc func onFeed() {
//        let playerItem = AVPlayerItem(url: URL(string: "http://192.168.1.100:8888/mystream/index.m3u8")!)
//        player.replaceCurrentItem(with: playerItem)
        AssetPlaybackManager.sharedManager.setAssetForPlayback(AVURLAsset(url: URL(string: "http://192.168.1.100:8888/mystream/index.m3u8")!))
    }
    
    public func stop() {
        source.stop()
        player?.pause()
        timer?.invalidate()
        timer = nil
    }
    
    public func _Source(_ source: Source, type: SourceType, onData: Data) {
        
    }
    
    public func _Source(_ source: Source, extra: [String : Any]) {
        
    }
    
    var currentCount = 0
    
    public func _Source(_ source: Source, type: SourceType, onPath: String) {
//        if let asset = self.asset {
//            let playerItem = AVPlayerItem(asset: asset)
//            player?.replaceCurrentItem(with: playerItem)
//        }
        if let fileHandle = FileHandle(forReadingAtPath: onPath) {
            if #available(iOS 13.4, *) {
                if let data = try? fileHandle.readToEnd() {
                    let folder = FileManager.default.temporaryDirectory.path
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("index.m3u8").path
                   
                    var str = String(data: data, encoding: .utf8)
//                    str = str?.replacingOccurrences(of: "\nsegment", with: "\n\(folder)/segment")
                    print(str!)
//                    let modified = str?.data(using: .utf8) ?? Data()
                    try! data.write(to: URL(fileURLWithPath: url), options: .atomic)
                    let asset = AVURLAsset(url: URL(fileURLWithPath: url))
                    
                    let item = AVPlayerItem(asset: asset)
                    player?.replaceCurrentItem(with: item)
//                    AssetPlaybackManager.sharedManager.setAssetForPlayback(AVURLAsset(url:  URL(fileURLWithPath: url)))
                }
            } else {
                // Fallback on earlier versions
            }
        }
//        AssetPlaybackManager.sharedManager.setAssetForPlayback(AVURLAsset(url: URL(fileURLWithPath: onPath)))
    }
    
    // Optional: Handle AVQueuePlayer's playback status changes
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if player?.status == .failed {
                print("Playback failed")
            } else if player?.status == .readyToPlay {
                print("Playback ready")
                player?.play()
            }
        } else if keyPath == "currentItem.status",
                  let playerItem = player?.currentItem {

                   // Check the status of the player item
                   switch playerItem.status {
                   case .failed:
                       print("Playback failed for item: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                       // Handle playback failure
                   case .unknown:
                       print("Playback status is unknown for item")
                       // Handle unknown status
                   case .readyToPlay:
                       print("Playback ready for item")
                       // Playback is ready, you can perform additional actions if needed
                   @unknown default:
                       print("Unhandled status")
                       // Handle any other unknown status
                   }
               }
    }
    
    
//    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
//        print("Loading ...")
//        guard let url = loadingRequest.request.url else {
//            // Unable to get URL, return false
//            return false
//        }
//        // 2. Read data from the local file
//        do {
//            let data = try Data(contentsOf: url)
//            print("Data \(data)")
//            // 3. Provide the data to the loading request
//            loadingRequest.dataRequest?.respond(with: data)
//            
//            // 4. Finish loading request
//            loadingRequest.finishLoading()
//            
//            // Return true to indicate that you're handling the loading of the requested resource
//            return true
//        } catch {
//            // Error occurred while reading data from file
//            // Handle error, then return false
//            return false
//        }
//    }
    
    func streamPlaybackManager(_ streamPlaybackManager: AssetPlaybackManager, playerReadyToPlay player: AVPlayer) {
        print("Play called")
        self.player?.play()
    }

    func streamPlaybackManager(_ streamPlaybackManager: AssetPlaybackManager,
                               playerCurrentItemDidChange player: AVPlayer) {
        print("Player init")
        self.player = player
        self.initPlayer()
    }
    
    func streamPlaybackManager(_ streamPlaybackManager: AssetPlaybackManager, playerDidStalled player: AVPlayer) {
//        AssetPlaybackManager.sharedManager.setAssetForPlayback(AVURLAsset(url: URL(string: "http://192.168.1.100:8888/mystream/index.m3u8")!))
    }
    
}
