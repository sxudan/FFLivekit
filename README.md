# FFLiveKit

A Swift library for live streaming video and audio from iOS devices to RTMP, RTSP, SRT, or UDP servers using FFmpegKit. This project demonstrates how to leverage FFmpegKit to capture, encode, and transmit real-time media streams.

## Overview

FFLiveKit provides a high-level API for live streaming that abstracts away the complexity of FFmpeg command-line operations. It handles:
- Camera and microphone capture
- Real-time encoding (H.264 video, AAC audio)
- Network streaming to various protocols
- Buffer management and data pipeline optimization

This is also a research project to evaluate how well FFmpegKit performs compared to existing live streaming packages like [Haishinkit](https://github.com/shogo4405/HaishinKit.swift).

# Features:

Inputs

- [x] Camera
- [x] Microphone
- [x] File

RTMP 

- [x] Ingest to RTMP server
- [ ] Playback (Todo)

RTSP

- [x] Ingest to RTSP server
- [ ] Playbakc (Todo)

SRT

- [x] Ingest to SRT server

HLS

- [ ] Playback (Todo)

UDP Support

- [x] Ingest using UDP protocol

Others minor features
- [x] Toggle Torch
- [x] Switch Camera
- [x] Background Publishing


# How It Works

## Architecture

FFLiveKit uses a pipeline architecture that efficiently moves data from iOS capture sources through FFmpeg to streaming servers:

```
[Camera/Mic Sources] → [Data Buffers] → [Named Pipes] → [FFmpeg] → [Streaming Server]
```

## Data Flow

### 1. Source Capture
- **CameraSource**: Captures video frames using `AVCaptureSession`, converts to BGRA format
- **MicrophoneSource**: Captures audio using `AVAudioEngine`, converts to PCM format
- Data is delivered via delegate callbacks to `FFmpegUtils`

### 2. State Management
The system operates in four states:
- **Normal**: Idle, no streaming
- **RequestRecording**: Initializing pipes and FFmpeg process
- **Recording**: Actively streaming (data is buffered and fed to FFmpeg)
- **RequestStop**: Cleaning up and shutting down

### 3. Data Pipeline

#### During RequestRecording State
- Data is written **directly** to pipes (no buffering)
- This ensures FFmpeg receives initial frames immediately
- Helps FFmpeg establish the stream connection faster

#### During Recording State
- Data is **buffered** in memory (`videoDataBuffer`, `audioDataBuffer`)
- A 10ms timer continuously feeds buffered data to pipes
- This provides smooth, continuous data flow to FFmpeg

### 4. Timer-Based Feeding
- A background timer runs every 10ms (`handleFeed()`)
- On each tick:
  - Locks buffers
  - Writes all buffered video data to video pipe
  - Writes all buffered audio data to audio pipe
  - Unlocks buffers
- This ensures FFmpeg receives data at a steady rate

### 5. Named Pipes
- FFmpegKit creates named pipes (FIFOs) for video and audio
- File descriptors are kept open to prevent EOF
- Persistent `FileHandle` objects are used for efficient writes
- Falls back to creating new handles if persistent ones fail

### 6. FFmpeg Processing
- FFmpeg reads from named pipes as input streams
- Encodes video (H.264 via VideoToolbox) and audio (AAC)
- Applies filters (scaling, rotation, bitrate control)
- Streams to destination server (RTMP/RTSP/SRT/UDP)

## Buffer Management

### Overflow Handling
- Video buffer: Max 100MB, keeps last 50MB if overflow (FIFO)
- Audio buffer: Max 50MB, keeps last 25MB if overflow (FIFO)
- Prevents memory issues while maintaining recent data

### Background Mode
- When app goes to background, sends blank frames to maintain stream
- Prevents server disconnection during app backgrounding
- Clears buffers when returning to foreground

## Key Components

### FFLiveKit
- Main entry point
- Manages sources, connection, and FFmpeg utilities
- Provides high-level API for streaming control

### FFmpegUtils
- Core pipeline manager
- Handles state transitions
- Manages buffers, pipes, and timer
- Implements `SourceDelegate` to receive data from sources

### Source Classes
- **CameraSource**: AVFoundation-based video capture
- **MicrophoneSource**: AVAudioEngine-based audio capture
- **FileSource**: File-based input (for testing)

### Connection Classes
- Protocol-specific connection handlers (RTMP, RTSP, SRT, UDP)
- Validates URLs and sets appropriate FFmpeg output format

## Performance Optimizations

1. **Persistent File Handles**: Reuses file handles instead of creating new ones for each write
2. **Efficient Buffering**: FIFO-based overflow handling prevents memory bloat
3. **Thread Safety**: Uses locks and dedicated queues for buffer operations
4. **Timer-Based Feeding**: Ensures steady data rate to FFmpeg (10ms intervals)
5. **Direct Writes During Init**: Reduces latency when starting stream

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

### Add sources and prepare
```Swift
ffLiveKit.addSources([cameraSource, microphoneSource])
cameraSource.startPreview(previewView: self.view)
try ffLiveKit.prepare(delegate: self)
```

### Start or Stop

```Swift
do {
    if !isRecording {
        try ffLiveKit.publish()
    } else {
        ffLiveKit.stop()
    }
} catch {
    print("Error: \(error)")
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


