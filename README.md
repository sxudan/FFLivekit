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

<video width="640" height="360" controls>
  <source src="[your_video.mp4](https://vimeo.com/921123595?share=copy)" type="video/mp4">
  Your browser does not support the video tag.
</video>
