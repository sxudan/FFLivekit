# Overview:

This is just a research to dig up the power of FFmpegKit to enable live streaming from the device's camera to RTMP or RTSP servers. FFmpegKit provides a convenient wrapper around FFmpeg, making it easy to capture, encode, and transmit audio and video streams.

This is also to to check how well it does against the existing live streaming packages like [Haishinkit](https://github.com/shogo4405/HaishinKit.swift)

# Features:

- Live stream video and audio from the device's camera to RTMP or RTSP servers.
- Customize FFmpeg commands to meet specific streaming requirements.
- Seamless integration with AVCaptureSession for camera and microphone access.
- Asynchronous execution for smooth streaming without blocking the main thread.



# Usage

```Swift
let cameraSource = CameraSource(position: .front)
let microphoneSource = MicrophoneSource()
let ffLiveKit = FFLiveKit()
```

```Swift
try? ffLiveKit.connect(connection: RTMPConnection(baseUrl: "rtmp://192.168.1.100:1935"))
ffLiveKit.addSource(camera: cameraSource, microphone: microphoneSource)
cameraSource.startPreview(previewView: self.view)
ffLiveKit.prepare(delegate: self)
```

```Swift
if !isRecording {
    try? ffLiveKit.publish(name: "mystream")
} else {
    ffLiveKit.stop()
}
```

# Demo

https://private-user-images.githubusercontent.com/31989781/311260826-f0fa60e3-41a7-4ac7-90fb-385a5ab6b97f.mp4?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MDk5NjQ0NzcsIm5iZiI6MTcwOTk2NDE3NywicGF0aCI6Ii8zMTk4OTc4MS8zMTEyNjA4MjYtZjBmYTYwZTMtNDFhNy00YWM3LTkwZmItMzg1YTVhYjZiOTdmLm1wND9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDAzMDklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQwMzA5VDA2MDI1N1omWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWY2OWM4OTg0ZDIxNzdhNmQ3MTU2Yjk2MDdlZjFhZTAzMjc4ZGM5ZDhiN2NjMDNlMjM3ZDJhZDc4MzMzMWZjMTAmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JmFjdG9yX2lkPTAma2V5X2lkPTAmcmVwb19pZD0wIn0.gmtVos0Xx--lM74gZzrQ_gSwr3lnWqE5uvaMcOisjyk


# Research

Please find the research on https://github.com/sxudan/FFLivekit/blob/research/README.md


