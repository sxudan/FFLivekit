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

I am using FFmpeg-kit https://github.com/arthenica/ffmpeg-kit

### Stage 1 (AVFoundation)

The FFmpeg avfoundation input format allows you to capture video and audio from macOS and iOS devices using AVFoundation.

```sh
ffmpeg -f avfoundation -i "0:0" -c:v libx264 -c:a aac -f flv rtmp://your-rtmp-server/app/stream
```

Although it supports ```avfoundation``` as an input device, it doesn't inherently provide a preview of the camera feed. avfoundation is more focused on capturing and processing audio and video data rather than rendering a live preview.


### Stage 2 (Named Pipe)

While doing my research on using named pipe on ffmpeg on iOS. I found a wonderful example related to this done using flutter by [dji_flutter](https://github.com/DragonX-cloud/dji_flutter_plugin/blob/main/example/lib/example.dart) 

![image](https://github.com/sxudan/ffmpeg-ios-publisher-example/assets/31989781/b1d39f39-8794-4f39-a1cc-c97243ce7d48)



You can create a named pipe like following

```
let videoPipe = FFmpegKitConfig.registerNewFFmpegPipe()
let audioPipe = FFmpegKitConfig.registerNewFFmpegPipe()
```

```Swift
let ffmpegCommand = "-re -f rawvideo -pixel_format bgra -video_size 1920x1080 -framerate 30 -i \(videoPipe!) 
-f s16le -ar 48000 -ac 1 -itsoffset -5 -i \(audioPipe!) 
-framerate 30 -pixel_format yuv420p -c:v h264 -c:a aac -vf "transpose=1,scale=360:640" -b:v 640k -b:a 64k -vsync 1 
-f flv \(url!)"

// Execute FFmpeg command
FFmpegKit.executeAsync(ffmpegCommand) { session in
    // Handle FFmpeg execution completion
    print("FFmpeg execution completed with return code \(session.returnCode)")
}
```

> Writing to pipe

To write to the pipe we just simply use FileHandle and specify the pipe path.

```Swift
if let currentPipe = self.videoPipe, let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: currentPipe)) {
    if #available(iOS 13.4, *) {
        try? fileHandle.write(contentsOf: data)
    } else {
        fileHandle.write(data)
    }
    fileHandle.closeFile()
} else {
    print("Failed to open file handle for writing")
}
```

The output video was laggy because I was not using any kind of buffers. While using buffer lead to another problem where ffmpeg quits while streaming because the named pipe pipe would reach EOF during buffering process.

### Stage 3

I looked up the solutions for this problem and found out this - https://unix.stackexchange.com/questions/483359/how-can-i-stop-ffmpeg-from-quitting-when-it-reaches-the-end-of-a-named-pipe

We just need to open the named pipe. On Swift we can do this by:

```Swift
let videoFileDescriptor = open(videoPipe!, O_RDWR)
let audioFileDescriptor = open(audioPipe!, O_RDWR)
```

This worked very well!!



# Demo

https://private-user-images.githubusercontent.com/31989781/311260826-f0fa60e3-41a7-4ac7-90fb-385a5ab6b97f.mp4?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MDk5NjQ0NzcsIm5iZiI6MTcwOTk2NDE3NywicGF0aCI6Ii8zMTk4OTc4MS8zMTEyNjA4MjYtZjBmYTYwZTMtNDFhNy00YWM3LTkwZmItMzg1YTVhYjZiOTdmLm1wND9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDAzMDklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQwMzA5VDA2MDI1N1omWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWY2OWM4OTg0ZDIxNzdhNmQ3MTU2Yjk2MDdlZjFhZTAzMjc4ZGM5ZDhiN2NjMDNlMjM3ZDJhZDc4MzMzMWZjMTAmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JmFjdG9yX2lkPTAma2V5X2lkPTAmcmVwb19pZD0wIn0.gmtVos0Xx--lM74gZzrQ_gSwr3lnWqE5uvaMcOisjyk


## Performance compared to HaishinKit 🤔🤔

> FFmpeg

![image](https://github.com/sxudan/ffmpeg-ios-publisher-example/assets/31989781/6c10dad3-6a9c-4cde-8003-c809c8eef500)

----
> HaishinKit

![image](https://github.com/sxudan/ffmpeg-ios-publisher-example/assets/31989781/b3a192af-b3da-4ac9-8ae0-4b442a135f5a)



# TODO

- CPU Optimization
- Continue live streaming when app is put in background (Audio)


