# Overview:

This is just a research to dig up the power of FFmpegKit to enable live streaming from the device's camera to RTMP or RTSP servers. FFmpegKit provides a convenient wrapper around FFmpeg, making it easy to capture, encode, and transmit audio and video streams.

This is also to to check how well it does against the existing live streaming packages like [Haishinkit](https://github.com/shogo4405/HaishinKit.swift)

# Features:

- Live stream video and audio from the device's camera to RTMP or RTSP servers.
- Customize FFmpeg commands to meet specific streaming requirements.
- Seamless integration with AVCaptureSession for camera and microphone access.
- Asynchronous execution for smooth streaming without blocking the main thread.



# Motivation

I have worked with lots of live streaming apps. I have been using libraries such as HaishinKit and LFLiveKit. I always wonder if we can publish the live feeds using ffmpeg on mobile apps. FFmpeg is indeed capable of live streaming to a server, and it's a commonly used tool for this purpose. FFmpeg is a powerful multimedia processing tool that can capture, encode, and transmit audio and video in real-time. But I was not sure if we could do this on mobile end.

### Stage 1 (AVFoundation)

The FFmpeg avfoundation input format allows you to capture video and audio from macOS and iOS devices using AVFoundation.

```sh
ffmpeg -f avfoundation -i "0:0" -c:v libx264 -c:a aac -f flv rtmp://your-rtmp-server/app/stream
```

Although it supports ```avfoundation``` as an input device, it doesn't inherently provide a preview of the camera feed. avfoundation is more focused on capturing and processing audio and video data rather than rendering a live preview.


### Stage 2 (Named Pipe)

While doing my research on using named pipe on ffmpeg on iOS. I found a wonderful example related to this done using flutter by [dji_flutter](https://github.com/DragonX-cloud/dji_flutter_plugin/blob/main/example/lib/example.dart) 


# Demo

https://private-user-images.githubusercontent.com/31989781/311260826-f0fa60e3-41a7-4ac7-90fb-385a5ab6b97f.mp4?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MDk5MDgxMzEsIm5iZiI6MTcwOTkwNzgzMSwicGF0aCI6Ii8zMTk4OTc4MS8zMTEyNjA4MjYtZjBmYTYwZTMtNDFhNy00YWM3LTkwZmItMzg1YTVhYjZiOTdmLm1wND9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDAzMDglMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQwMzA4VDE0MjM1MVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTI4NDIyZWIzMmRiZDhmYWE5YzVmNjIwMTEzMjc2ZWE4OGM5NzhjODNjYTFmYTU3MmI2NjZjNWJmMzBlMGRkZDYmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JmFjdG9yX2lkPTAma2V5X2lkPTAmcmVwb19pZD0wIn0.37E4cEEE5_mMLM5yqN4UwoQDwGdWrDpFUtIKVyvU5Pw
