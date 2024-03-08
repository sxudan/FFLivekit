//
//  CameraUtility.swift
//  live-demo
//
//  Created by xkal on 8/3/2024.
//

import AVFoundation
import UIKit

protocol AudioVideoDelegate: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func onAudioEngine(data didReceived: Data)
}

class CameraUtility {
    
    private let previewLayer = AVCaptureVideoPreviewLayer()
    let videoOutput = AVCaptureVideoDataOutput();
    let audioOutput = AVCaptureAudioDataOutput();
    let backgroundVideoQueue = DispatchQueue.global(qos: .background)
    let backgroundAudioQueue = DispatchQueue.global(qos: .background)
    private var sessionOutputDelegate: AudioVideoDelegate?
    private var useAudioEngine = false
    private var audioEngine: AVAudioEngine?
    
    init(useAudioEngine: Bool = false) {
        self.useAudioEngine = useAudioEngine
        if useAudioEngine {
            setupAudioEngine()
        }
        
        // Add observers for AVCaptureSession notifications
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: .AVCaptureSessionWasInterrupted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: .AVCaptureSessionInterruptionEnded, object: nil)
    }
    
    // Handle AVCaptureSession runtime error
        @objc func sessionRuntimeError(notification: Notification) {
            if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error {
                print("AVCaptureSession runtime error: \(error.localizedDescription)")
                // Handle the error as needed
            }
        }

        // Handle AVCaptureSession interruption
        @objc func sessionWasInterrupted(notification: Notification) {
            if let reasonValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int,
               let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue) {
                print("AVCaptureSession was interrupted. Reason: \(reason)")
                // Handle the interruption as needed
            }
        }

        // Handle AVCaptureSession interruption ended
        @objc func sessionInterruptionEnded(notification: Notification) {
            print("AVCaptureSession interruption ended.")
            // Handle the interruption end as needed
        }

        // Remove observers when the view controller is deallocated
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    
    func attach(view: UIView) {
        setupCameraPreview(view: view)
    }
    
    func setDelegate(delegate: AudioVideoDelegate) {
        self.sessionOutputDelegate = delegate
        
        videoOutput.setSampleBufferDelegate(self.sessionOutputDelegate, queue: backgroundVideoQueue)
        
        audioOutput.setSampleBufferDelegate(self.sessionOutputDelegate, queue: backgroundAudioQueue)
    }
    
    private func addDevice_Camera(session: AVCaptureSession) -> AVCaptureDeviceInput? {
        do {
            // Check if the device has a camera
            guard let camera = AVCaptureDevice.default(for: .video) else {
                print("Camera not available")
                return nil
            }
            
            // Create input from the camera
            let input = try AVCaptureDeviceInput(device: camera)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            return input
        } catch {
            print(error)
            
        }
        return nil
    }
    
    private func addDevice_Microphone(session: AVCaptureSession) -> AVCaptureDeviceInput? {
        do {
            // Check if the device has a microphone
            guard let mic = AVCaptureDevice.default(for: .audio) else {
                print("Microphone not available")
                return nil
            }
            
            // Create input from the camera
            let input = try AVCaptureDeviceInput(device: mic)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            return input
        } catch {
            print(error)
            
        }
        return nil
    }
    
    private func setupCameraPreview(view: UIView) {
        do {
            // Create a session and add the input
            let session = AVCaptureSession()
            
            let cameraInput = addDevice_Camera(session: session)
            
            
            guard let camera = cameraInput?.device else {
                return
            }
            
            if !useAudioEngine {
                let audioInput = addDevice_Microphone(session: session)
                
                if session.canAddOutput(audioOutput) {
                    session.addOutput(audioOutput)
                }
            }
            
            
            
            videoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String) : NSNumber(value: kCVPixelFormatType_32BGRA as UInt32),]
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                
            }
            
            
            // Set the preview layer to display the camera feed
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
            
            // Add the preview layer to your view's layer
            view.layer.insertSublayer(previewLayer, at: 0)
            
            // Optional: Adjust the frame of the preview layer
            previewLayer.frame = view.layer.bounds
            
            
            do {
                try camera.lockForConfiguration()
                
                let desiredFrameRate = CMTimeMake(value: 1, timescale: 30)
                camera.activeVideoMinFrameDuration = desiredFrameRate
                camera.activeVideoMaxFrameDuration = desiredFrameRate
                
                let availableFormats = camera.formats
                
                for format in availableFormats {
                    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    let width = dimensions.width
                    let height = dimensions.height
                    
                    print("Resolution: \(width) x \(height)")
                }
                
                camera.unlockForConfiguration()
                
            } catch {
                print("Error accessing video device: \(error)")
            }
            
            let activeFormat = camera.activeFormat.formatDescription
            let dimensions = CMVideoFormatDescriptionGetDimensions(activeFormat)
            let width = dimensions.width
            let height = dimensions.height
            
            print("Resolution: \(width) x \(height)")
            
            // Start the capture session
            do {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
                try AVAudioSession.sharedInstance().setPreferredSampleRate(44100) // Set your preferred sample rate here
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to set audio session settings: \(error.localizedDescription)")
                return
            }
            
            
            // Set the session to output video frames
            DispatchQueue.global().async {
                session.startRunning()
            }
            
        } catch {
            print("Error setting up AVCaptureDeviceInput: \(error)")
        }
    }
    
    func startAudioCapture() {
        if useAudioEngine {
            do {
                try audioEngine?.start()
            } catch {
                print("Error starting audio engine: \(error.localizedDescription)")
            }
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 1, interleaved: false)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
            let audioData = self.bufferToData(buffer: buffer)
            self.backgroundAudioQueue.async {
                self.sessionOutputDelegate?.onAudioEngine(data: audioData)
            }
        }
    }
    
    private func bufferToData(buffer: AVAudioPCMBuffer) -> Data {
        let channelData = buffer.int16ChannelData![0]
        let dataSize = Int(buffer.frameLength) * MemoryLayout<Int16>.size
        let data = Data(bytes: channelData, count: dataSize)
        return data
    }
}
