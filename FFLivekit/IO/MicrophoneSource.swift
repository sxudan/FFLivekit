//
//  MicrophoneSource.swift
//  live-demo
//
//  Created by xkal on 10/3/2024.
//

import AVFoundation

//public protocol MicrophoneSourceDelegate {
//    func _MicrophoneSource(onData: Data)
//}

public class MicrophoneSource: Source {
    
    private var audioEngine: AVAudioEngine?
    let backgroundAudioQueue = DispatchQueue.global(qos: .background)
//    var delegate: MicrophoneSourceDelegate?
    
    public init(sampleRate: Double = 48000) throws {
        super.init()
        command = "-f s16le -ar \(sampleRate) -ac 1 -itsoffset -5 -i %audioPipe%"
        setupSession(sampleRate: sampleRate)
        try setupAudioEngine(sampleRate: sampleRate)
    }
    
    
    private func setupSession(sampleRate: Double) {
        /// Start the capture session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoChat, options: [.allowAirPlay, .allowBluetooth])
            try AVAudioSession.sharedInstance().setPreferredSampleRate(sampleRate) // Set your preferred sample rate here
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session settings: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioEngine(sampleRate: Double, channels: Int = 1) throws {
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let defaultFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: inputNode.inputFormat(forBus: 0).sampleRate, channels: 1, interleaved: false)!
        print("Default sample rate \(inputNode.inputFormat(forBus: 0).sampleRate)")
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: false)!
        
       
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: defaultFormat) { buffer, time in
            let convertedBuffer = outputFormat.sampleRate != defaultFormat.sampleRate ? BufferConverter.convert(from: defaultFormat, to: outputFormat, buffer: buffer) : buffer
            
            let audioData = BufferConverter.bufferToData(buffer: convertedBuffer)
            self.backgroundAudioQueue.async {
                self.delegate?._Source(self, type: .Audio, onData: audioData)
            }
        }
    }
    
    public override func start() {
        do {
//            audioEngine?.prepare()
            try audioEngine?.start()
        } catch {
            print(error)
        }
    }
    
    public override func stop() {
        audioEngine?.stop()
    }
}
