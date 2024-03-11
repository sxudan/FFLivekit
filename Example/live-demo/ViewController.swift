//
//  ViewController.swift
//  live-publish-demo
//
//  Created by xkal on 24/2/2024.
//

import UIKit
import AVFoundation
import ffmpegkit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, UIImagePickerControllerDelegate, AVCaptureFileOutputRecordingDelegate, UINavigationControllerDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print(outputFileURL)
        let cmd = "-re -i \(outputFileURL.path) -c:a aac -c:v h264 -b:v 2M -f flv rtmp://192.168.1.100:1935/mystream"
        print(cmd)
        background.async {
            let session = FFmpegKit.executeAsync(cmd, withCompleteCallback: {data in
                print("completed")
                self.startPublish()
            })
            self.sessionId = session?.getId()
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        
        background.asyncAfter(deadline: .now() + 3, execute: {
            self.stopPublish()
        })
        
    }
    

    @IBOutlet weak var cameraView: UIView!
    
    let captureSession = AVCaptureSession()
    var frontCamera: AVCaptureDevice?
    var rearCamera: AVCaptureDevice?
    var microphone: AVCaptureDevice?
    
    var frontCameraInput: AVCaptureDeviceInput?
    var backCameraInput: AVCaptureDeviceInput?
    var microphoneInput: AVCaptureDeviceInput?
    var currentCameraPosition: AVCaptureDevice.Position = .back
    
    var movieOutput = AVCaptureMovieFileOutput()

    
    var sessionOutput = AVCaptureVideoDataOutput();
    

    
    var _currentWritingStatus: AVAssetWriter.Status = .unknown
    
    var videoUrl: String?
    
    var sessionId: Int?
    
    
    let background = DispatchQueue.global(qos: .background)
    
    
    
    private let previewLayer = AVCaptureVideoPreviewLayer()
    
    
//    var currentWritingStatus: AVAssetWriter.Status {
//        set {
//            _currentWritingStatus = newValue
//        }
//
//        get {
//            return _currentWritingStatus
//        }
//    }
   
    
    var tempVideoFileUrl: URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent("temp.mp4")
    }
    
    
    func createNamedPipe(atPath path: String) -> Bool {
        if FileManager.default.fileExists(atPath: path) {
            return true
        }
        let result = mkfifo(path, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH)

        if result == 0 {
            print("Named pipe created at: \(path)")
            return true
        } else {
            perror("mkfifo")
            return false
        }
    }
    
    let pipePath = FileManager.default.temporaryDirectory.appendingPathComponent("fff").path
    
    @IBAction func onPick(_ sender: Any) {
//        imagePickerController.sourceType = .photoLibrary
//        imagePickerController.delegate = self
//          imagePickerController.mediaTypes = ["public.image", "public.movie"]
//
//        present(imagePickerController, animated: true, completion: nil)
        background.async {
            self.writeToNamedPipe(atPath: self.pipePath, data: "Hello world bitch")
        }
    }
    
    func writeToNamedPipe(atPath path: String, data: String) {
        if let fileHandle = FileHandle(forWritingAtPath: path) {
//            defer {
//                fileHandle.closeFile()
//            }

            if let data = data.data(using: .utf8) {
                fileHandle.write(data)
                print("Data written to named pipe: \(data)")
            } else {
                print("Error converting string to data")
            }
        } else {
            print("Error opening file handle for writing")
        }
    }
    

    func readFromNamedPipe(atPath path: String) {
        if let fileHandle = FileHandle(forReadingAtPath: path) {
//            defer {
//                fileHandle.closeFile()
//            }
            
            fileHandle.readabilityHandler = { handler in
                let string = String(data: handler.availableData, encoding: .utf8)
                print("Data read from named pipe: \(string)")
            }
//            let data = fileHandle.readDataToEndOfFile()
            
        } else {
            print("Error opening file handle for reading")

        }
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let url = (info[UIImagePickerController.InfoKey.mediaURL] as? NSURL)?.path
        copyFileToTemporaryDirectory(source: url!)
//        copyFileToTemporaryDirectory(source: url)
        
          imagePickerController.dismiss(animated: true, completion: nil)
    }
    
    func copyFileToTemporaryDirectory(source: String) {
        
        let fileManager = FileManager.default
        
        // Replace "sourceFilePath" with the path to your source file
        let sourceFilePath = source
        
        // Create a URL for the source file
        let sourceFileURL = URL(fileURLWithPath: sourceFilePath)
        
        // Get the temporary directory URL
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        
        // Create a destination URL in the temporary directory
        let destinationFileURL = temporaryDirectoryURL.appendingPathComponent(sourceFileURL.lastPathComponent)
        
        do {
            // Check if the file already exists at the destination
            if fileManager.fileExists(atPath: destinationFileURL.path) {
                // If it exists, you may want to handle it according to your requirements
                print("File already exists in the temporary directory.")
                try fileManager.removeItem(at: destinationFileURL)
            }
            
            // Copy the file to the temporary directory
            try fileManager.copyItem(at: sourceFileURL, to: destinationFileURL)
            
            // Print the path to the copied file in the temporary directory
            print("File copied to: \(destinationFileURL.path)")
            
            videoUrl = destinationFileURL.path

        } catch {
            // Handle the error if the copy operation fails
            print("Error: \(error.localizedDescription)")
        }
    }
    
    var writer: AVAssetWriter?
    var videoWriterInput: AVAssetWriterInput?
    
    
    let imagePickerController = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        setupCameraPreview()
//        setupDevice()
//        setupSessionInput()
//        prepare()
        
        background.async {
            self.listen()
        }
    }
    
    let pipe = Pipe()
   
    
    func listen() {
        // make pipe
        signal(SIGPIPE) { _ in
            print("Received SIGPIPE signal")
        }
        if createNamedPipe(atPath: pipePath) {
            self.readFromNamedPipe(atPath: self.pipePath)
        } else {
            print("Failed")
        }
        
    }
    
    private func setupCameraPreview() {
           // Check if the device has a camera
           guard let camera = AVCaptureDevice.default(for: .video) else {
               print("Camera not available")
               return
           }
           
           do {
               // Create input from the camera
               let input = try AVCaptureDeviceInput(device: camera)
               
               // Create a session and add the input
               let session = AVCaptureSession()
               session.addInput(input)
               
               // Set the session to output video frames
               background.async {
                   session.startRunning()
               }
               
               // Set the preview layer to display the camera feed
               previewLayer.session = session
               previewLayer.videoGravity = .resizeAspectFill
               
               // Add the preview layer to your view's layer
               cameraView.layer.addSublayer(previewLayer)
               
               // Optional: Adjust the frame of the preview layer
               previewLayer.frame = view.layer.bounds
               
           } catch {
               print("Error setting up AVCaptureDeviceInput: \(error)")
           }
       }
       
       override func viewDidLayoutSubviews() {
           super.viewDidLayoutSubviews()
           // Update the frame of the preview layer when the view's bounds change
           previewLayer.frame = view.layer.bounds
       }

    func setupDevice() {
        let session = AVCaptureDevice.DiscoverySession.init(deviceTypes:[.builtInWideAngleCamera, .builtInMicrophone], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
                
        let cameras = (session.devices.compactMap{$0})
                
        for camera in cameras {
            if camera.position == .front {
                
                self.frontCamera = camera
            }
            if camera.position == .back {
                self.rearCamera = camera

                try? camera.lockForConfiguration()
                camera.focusMode = .continuousAutoFocus
                camera.unlockForConfiguration()
            }
            
        }
        
        let audioSession = AVCaptureDevice.DiscoverySession.init(deviceTypes:[.builtInMicrophone], mediaType: AVMediaType.audio, position: AVCaptureDevice.Position.unspecified)
        
        let audioDevices = (audioSession.devices.compactMap{$0})
        
        for audioDevice in audioDevices {
            if audioDevice.hasMediaType(.audio) {
                microphone = audioDevice
            }
        }
    }
    
    func setupSessionInput() {

        do {
            if let rearCamera = self.rearCamera {
                self.backCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                if captureSession.canAddInput(self.backCameraInput!) {
                    captureSession.addInput(self.backCameraInput!)
                    self.currentCameraPosition = .back
                } else {
                    return
                }
            } else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                if captureSession.canAddInput(self.frontCameraInput!) {
                    captureSession.addInput(self.frontCameraInput!)
                    self.currentCameraPosition = .front
                } else {
                    return
                }
            } else {
                print("no cameras ")
                return
            }

            // Add audio input
            if let audioDevice = self.microphone {
                self.microphoneInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession.canAddInput(self.microphoneInput!) {
                    captureSession.addInput(self.microphoneInput!)
                } else {
                    print("cannot add input")
                }
            }
        } catch let error {
            print(error)
        }
    }
    
    func prepare() {
//        let videoSettings: [String: Any] = [
//                       AVVideoCodecKey: AVVideoCodecType.h264,
//                       AVVideoWidthKey: 640,
//                       AVVideoHeightKey: 360,
//        ]
//        if let connection = movieOutput.connection(with: .video) {
//            movieOutput.setOutputSettings(videoSettings, for: connection)
//        }
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }
        
        
        let captureLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        captureLayer.bounds = CGRect(x: 0, y: 0, width: self.cameraView.bounds.width, height: self.cameraView.bounds.height)
        captureLayer.position = CGPoint(x: self.cameraView.bounds.midX, y: self.cameraView.bounds.midY)
        captureLayer.videoGravity = AVLayerVideoGravity.resize
        cameraView.layer.insertSublayer(captureLayer, at: 0)
        
        background.async {[weak self] in
            self?.captureSession.startRunning()
        }
        
//        sessionOutput.setSampleBufferDelegate(self, queue: backgroundQueue)
        
    }
    
    @IBAction func onStartWriting(_ sender: Any) {
//        print("Start wrting")
//        setupWriter()
        self.startPublish()
    }
    
    func startPublish() {
//        let file = FileManager.default.temporaryDirectory.appendingPathComponent("capture.mp4")
//        if FileManager.default.fileExists(atPath: file.path) {
//            try? FileManager.default.removeItem(at: file)
//            print("file removed")
//        }
//        movieOutput.startRecording(to: FileManager.default.temporaryDirectory.appendingPathComponent("capture.mp4"), recordingDelegate: self)
//       
//        var pipe = FFmpegKitConfig.registerNewFFmpegPipe()
//        
//        print(pipe)
        
        
//        let cmd = "-re  -i \(videoUrl!) -c:a aac -c:v h264 -b:v 2M -f mpegts \"srt://192.168.1.100:8890?streamid=publish:mystream&pkt_size=1316\""
        let cmd = """
-f avfoundation -r 30 -video_size 1280x720 -pixel_format bgr0 -rtbufsize 2G -i 1:0 -vsync 1 -vf \"transpose=1\" -af \"asetpts=N/SR/TB\" -c:a aac -c:v h264_videotoolbox -b:v 2M -f flv -
"""
        print(cmd)
        background.async {
            let session = FFmpegKit.execute(cmd)
            self.sessionId = session?.getId()
            
        }
        
    }
    
    func stopPublish() {
//        movieOutput.stopRecording()
        background.async {[weak self] in
            print("stopping session \(self?.sessionId)")
            if let sessionId = self?.sessionId {
                FFmpegKit.cancel(sessionId)
            } else {
                FFmpegKit.cancel()
            }
        }
    }
    
    @IBAction func onStopWriting(_ sender: Any) {
//        movieOutput.stopRecording()
//        stopPublish()
        FFmpegKit.cancel()
//        FFmpegKitConfig.closeFFmpegPipe(pipe)
    }
    
    func setupWriter() {
        do {
            writer = try AVAssetWriter(url: tempVideoFileUrl, fileType: .mp4)
            let videoSettings: [String: Any] = [
                           AVVideoCodecKey: AVVideoCodecType.h264,
                           AVVideoWidthKey: 640,
                           AVVideoHeightKey: 480,
//                           (kCVPixelBufferPixelFormatTypeKey as String) : NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)
                           // Add more settings as needed
                       ]
            videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            
            guard let videoWriterInput = videoWriterInput, writer!.canAdd(videoWriterInput) else {
                fatalError("Cannot add video input to asset writer")
            }
            videoWriterInput.expectsMediaDataInRealTime = true
            writer?.add(videoWriterInput)
        } catch let e {
            print(e)
        }
    }
    
    func imageFromSampleBuffer(sampleBuffer : CMSampleBuffer) -> UIImage?
     {
       // Get a CMSampleBuffer's Core Video image buffer for the media data
       let  imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
       // Lock the base address of the pixel buffer
       CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly);


       // Get the number of bytes per row for the pixel buffer
       let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer!);

       // Get the number of bytes per row for the pixel buffer
       let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!);
       // Get the pixel buffer width and height
       let width = CVPixelBufferGetWidth(imageBuffer!);
       let height = CVPixelBufferGetHeight(imageBuffer!);

       // Create a device-dependent RGB color space
       let colorSpace = CGColorSpaceCreateDeviceRGB();

       // Create a bitmap graphics context with the sample buffer data
       var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue
       bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
       //let bitmapInfo: UInt32 = CGBitmapInfo.alphaInfoMask.rawValue
       let context = CGContext.init(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
       // Create a Quartz image from the pixel data in the bitmap graphics context
       let quartzImage = context?.makeImage();
       // Unlock the pixel buffer
       CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly);
         if quartzImage == nil {
             return nil
         }
       // Create an image object from the Quartz image
       let image = UIImage.init(cgImage: quartzImage!);

       return (image);
     }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
//        let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer)
        background.async {[weak self] in
            guard let imageBuffer = sampleBuffer.imageBuffer else {
                  print("no image buffer :(")
                  return
                }
            let img = UIImage(ciImage: CIImage(cvImageBuffer: imageBuffer))
          guard let jpeg = img.jpegData(compressionQuality: 0.6) else {
            print("failed to compress jpeg :(")
            return
          }
            
         
            

            
        }
//        print(pipe)
//        print(jpeg)
        
//        if let data = image?.jpegData(compressionQuality: 50) {
//            if let str = String(data: jpeg, encoding: .utf8) {
////                pipe!.write(str)
//
//            }
//        }
        
//        if writer != nil {
//            if CMSampleBufferDataIsReady(sampleBuffer) {
//                if writer?.status == .unknown {
//                    let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
//                    writer?.startWriting()
//                    writer?.startSession(atSourceTime: timestamp)
//                }
//                
//                
//                if videoWriterInput?.isReadyForMoreMediaData ?? false {
//                    videoWriterInput?.append(sampleBuffer)
//                }
//                
////                if _currentWritingStatus != writer?.status && writer?.status == .writing {
////                    startPublish()
////                }
//                
//                _currentWritingStatus = writer?.status ?? .unknown
//            }
//        }
    }
    
    
    
//    func prepare() {
//        self.videoOutput = AVCaptureVideoDataOutput()
//        if captureSession.canAddOutput(self.videoOutput!) {
//            captureSession.addOutput(self.videoOutput!)
//            captureSession.add
//        }
//
//        captureSession.startRunning()
//    }
//
//    func recordVideo(completion: @escaping (URL?, Error?) -> Void) {
//        guard let captureSession = self.captureSession, captureSession.isRunning else {
//            completion(nil, CameraControllerError.captureSessionIsMissing)
//            return
//        }
//        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//        let fileUrl = paths[0].appendingPathComponent("output.mp4")
//        try? FileManager.default.removeItem(at: fileUrl)
//        videoOutput!.startRecording(to: fileUrl, recordingDelegate: self)
//        self.videoRecordCompletionBlock = completion
//    }
}



enum VideoError: Error {
  case failedToGetParameterSetCount
  case failedToGetParameterSet(index: Int)
}

extension CMSampleBuffer {
  /// Convert a CMSampleBuffer holding a CMBlockBuffer in AVCC format into Annex B format.
  func dataBufferAsAnnexB() -> Data? {
    guard let dataBuffer, let formatDescription else {
      return nil
    }

    do {
      var result = Data()
      let startCode = Data([0x00, 0x00, 0x00, 0x01])
      
      try formatDescription.forEachParameterSet { buf in
        result.append(startCode)
        result.append(buf)
      }
      
      try dataBuffer.withContiguousStorage { rawBuffer in
        // Since the startCode is 4 bytes, we can append the whole AVCC buffer to the output,
        // and then replace the 4-byte length values with start codes.
        var offset = result.count
        result.append(rawBuffer.assumingMemoryBound(to: UInt8.self))
        result.withUnsafeMutableBytes { resultBuffer in
          while offset + 4 < resultBuffer.count {
            let nalUnitLength = Int(UInt32(bigEndian: resultBuffer.loadUnaligned(fromByteOffset: offset, as: UInt32.self)))
            resultBuffer[offset..<offset+4].copyBytes(from: startCode)
            offset += 4 + nalUnitLength
          }
        }
      }
      
      return result
    } catch let err {
      print("Error converting to Annex B: \(err)")
      return nil
    }
  }
}

extension CMFormatDescription {
  func forEachParameterSet(_ callback: (UnsafeBufferPointer<UInt8>) -> Void) throws {
    var parameterSetCount = 0
    var status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
      self,
      parameterSetIndex: 0,
      parameterSetPointerOut: nil,
      parameterSetSizeOut: nil,
      parameterSetCountOut: &parameterSetCount,
      nalUnitHeaderLengthOut: nil
    )
    guard noErr == status else {
      throw VideoError.failedToGetParameterSetCount
    }
    
    for idx in 0..<parameterSetCount {
      var ptr: UnsafePointer<UInt8>? = nil
      var size = 0
      status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
        self,
        parameterSetIndex: idx,
        parameterSetPointerOut: &ptr,
        parameterSetSizeOut: &size,
        parameterSetCountOut: nil,
        nalUnitHeaderLengthOut: nil
      )
      guard noErr == status else {
        throw VideoError.failedToGetParameterSet(index: idx)
      }
      callback(UnsafeBufferPointer(start: ptr, count: size))
    }
  }
}
