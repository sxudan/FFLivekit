# Overview:

This is just a research to dig up the power of FFmpegKit to enable live streaming from the device's camera to RTMP or RTSP servers. FFmpegKit provides a convenient wrapper around FFmpeg, making it easy to capture, encode, and transmit audio and video streams.

This is also to to check how well it does against the existing live streaming packages like [Haishinkit](https://github.com/shogo4405/HaishinKit.swift)

# Features:

- Live stream video and audio from the device's camera to RTMP or RTSP servers.
- Customize FFmpeg commands to meet specific streaming requirements.
- Seamless integration with AVCaptureSession for camera and microphone access.
- Asynchronous execution for smooth streaming without blocking the main thread.


# Limitation of FFmpeg

- Although it supports ```avfoundation``` as an input device, it doesnot provide any way to preview the output of the session. That's the reason I am using ```AVCaptureSession``` and feed the data to ffmpeg using pipes.


# Demo

https://private-user-images.githubusercontent.com/31989781/311260826-f0fa60e3-41a7-4ac7-90fb-385a5ab6b97f.mp4?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MDk5MDgxMzEsIm5iZiI6MTcwOTkwNzgzMSwicGF0aCI6Ii8zMTk4OTc4MS8zMTEyNjA4MjYtZjBmYTYwZTMtNDFhNy00YWM3LTkwZmItMzg1YTVhYjZiOTdmLm1wND9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDAzMDglMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQwMzA4VDE0MjM1MVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTI4NDIyZWIzMmRiZDhmYWE5YzVmNjIwMTEzMjc2ZWE4OGM5NzhjODNjYTFmYTU3MmI2NjZjNWJmMzBlMGRkZDYmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JmFjdG9yX2lkPTAma2V5X2lkPTAmcmVwb19pZD0wIn0.37E4cEEE5_mMLM5yqN4UwoQDwGdWrDpFUtIKVyvU5Pw
