# Overview:

This is just a research to dig up the power of FFmpegKit to enable live streaming from the device's camera to RTMP or RTSP servers. FFmpegKit provides a convenient wrapper around FFmpeg, making it easy to capture, encode, and transmit audio and video streams.

This is also to to check how well it does against the existing live streaming packages like [Haishinkit](https://github.com/shogo4405/HaishinKit.swift)

# Features:

Inputs

- [x] Camera
- [x] Microphone
- [x] File

RTMP 

- [x] Ingest to RTMP server

RTSP

- [x] Ingest to RTSP server

SRT

- [x] Ingest to SRT server

UDP Support

- [x] Ingest using UDP protocol

Others minor features
- [x] Toggle Torch
- [x] Switch Camera
- [x] Background Publishing


# Usage

### Initialize the Source and FFLiveKit
```Swift
let cameraSource = CameraSource(position: .front)
let microphoneSource = MicrophoneSource()
/// add options
let ffLiveKit = FFLiveKit(options: [.outputVideoSize((360, 640)), .outputVideoBitrate("400k")])
```

### Initialize the connections according to your need
```Switf
let srtConnection = try! SRTConnection(baseUrl: "srt://192.168.1.100:8890?streamid=publish:mystream&pkt_size=1316")
let rtmpConnection = try! RTMPConnection(baseUrl: "rtmp://192.168.1.100:1935/mystream")
let rtspConnection = try! RTSPConnection(baseUrl: "rtsp://192.168.1.100:8554/mystream")
let udpConnection = try! UDPConnection(baseUrl: "udp://192.168.1.100:1234?pkt_size=1316")
```

### Connect
```Swift
try! ffLiveKit.connect(connection: rtmpConnection)
```

### Add source
```Swift
ffLiveKit.addSources(sources: [cameraSource, microphoneSource])
cameraSource.startPreview(previewView: self.view)
ffLiveKit.prepare(delegate: self)
```

### Start or Stop

```Swift
if !isRecording {
    try? ffLiveKit.publish()
} else {
    ffLiveKit.stop()
}
```

### Delegates

```Swift
func _FFLiveKit(didChange status: RecordingState)
func _FFLiveKit(onStats stats: FFStat)
func _FFLiveKit(onError error: String)
```

### Options

```Swift
public enum FFLivekitSettings {
    case outputVideoFramerate(Int)
    case outputVideoPixelFormat(String)
    case outputVideoSize((Int, Int))
    /// example "500k" or "2M"
    case outputVideoBitrate(String)
    /// example "128k"
    case outputAudioBitrate(String)

    /// nil to no transpose
    /// 0 - Rotate 90 degrees counterclockwise and flip vertically.
    ///1 - Rotate 90 degrees clockwise.
    /// 2 - Rotate 90 degrees counterclockwise.
    /// 3 - Rotate 90 degrees clockwise and flip vertically.
    case outputVideoTranspose(Int?)
}
```

# Demo

https://private-user-images.githubusercontent.com/31989781/311260826-f0fa60e3-41a7-4ac7-90fb-385a5ab6b97f.mp4?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MDk5NjQ0NzcsIm5iZiI6MTcwOTk2NDE3NywicGF0aCI6Ii8zMTk4OTc4MS8zMTEyNjA4MjYtZjBmYTYwZTMtNDFhNy00YWM3LTkwZmItMzg1YTVhYjZiOTdmLm1wND9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDAzMDklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQwMzA5VDA2MDI1N1omWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWY2OWM4OTg0ZDIxNzdhNmQ3MTU2Yjk2MDdlZjFhZTAzMjc4ZGM5ZDhiN2NjMDNlMjM3ZDJhZDc4MzMzMWZjMTAmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JmFjdG9yX2lkPTAma2V5X2lkPTAmcmVwb19pZD0wIn0.gmtVos0Xx--lM74gZzrQ_gSwr3lnWqE5uvaMcOisjyk


# Research

Please find the research on https://github.com/sxudan/FFLivekit/blob/research/README.md


