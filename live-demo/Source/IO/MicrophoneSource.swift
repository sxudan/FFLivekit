//
//  MicrophoneSource.swift
//  live-demo
//
//  Created by xkal on 10/3/2024.
//

import AVFoundation

protocol MicrophoneSourceDelegate {
    func _MicrophoneSource(onData: Data)
}

class MicrophoneSource {
    
    private var audioEngine: AVAudioEngine?
    let backgroundAudioQueue = DispatchQueue.global(qos: .background)
    var delegate: MicrophoneSourceDelegate?
    
    init() {
        setupSession()
        setupAudioEngine()
    }
    
    private func setupSession() {
        /// Start the capture session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoChat, options: [.allowAirPlay, .allowBluetooth])
            try AVAudioSession.sharedInstance().setPreferredSampleRate(48000) // Set your preferred sample rate here
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session settings: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let defaultFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 1, interleaved: false)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: defaultFormat) { buffer, time in
            let audioData = BufferConverter.bufferToData(buffer: buffer)
            self.backgroundAudioQueue.async {
                self.delegate?._MicrophoneSource(onData: audioData)
            }
        }

    }
    
    func start() throws {
        do {
//            audioEngine?.prepare()
            try audioEngine?.start()
        } catch {
            throw(error)
        }
    }
    
    func stop() {
        audioEngine?.stop()
    }
}
