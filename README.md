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

<image src="https://private-user-images.githubusercontent.com/31989781/311412141-3f4fddb3-c38c-47ce-a1a6-80529651ae9d.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MDk5NTkxMTUsIm5iZiI6MTcwOTk1ODgxNSwicGF0aCI6Ii8zMTk4OTc4MS8zMTE0MTIxNDEtM2Y0ZmRkYjMtYzM4Yy00N2NlLWExYTYtODA1Mjk2NTFhZTlkLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDAzMDklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQwMzA5VDA0MzMzNVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTU0ZGE3NTkyMmYwMjViNGViYzNlZDc1MjZkYzA4ZGQ4Y2Q5YWNlZDY3ZWZlNjc1YWQ1YjgxNjllZWJjNzY0MjkmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JmFjdG9yX2lkPTAma2V5X2lkPTAmcmVwb19pZD0wIn0.7UwiIcL2Z1btwWh4-3QdoyxHJlKNr7mVocTrA18kMOM" />


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

https://private-user-images.githubusercontent.com/31989781/311260826-f0fa60e3-41a7-4ac7-90fb-385a5ab6b97f.mp4?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MDk5MDgxMzEsIm5iZiI6MTcwOTkwNzgzMSwicGF0aCI6Ii8zMTk4OTc4MS8zMTEyNjA4MjYtZjBmYTYwZTMtNDFhNy00YWM3LTkwZmItMzg1YTVhYjZiOTdmLm1wND9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDAzMDglMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQwMzA4VDE0MjM1MVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTI4NDIyZWIzMmRiZDhmYWE5YzVmNjIwMTEzMjc2ZWE4OGM5NzhjODNjYTFmYTU3MmI2NjZjNWJmMzBlMGRkZDYmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JmFjdG9yX2lkPTAma2V5X2lkPTAmcmVwb19pZD0wIn0.37E4cEEE5_mMLM5yqN4UwoQDwGdWrDpFUtIKVyvU5Pw


## Performance compared to HaishinKit 🤔🤔

> FFmpeg
<Image width=300 src="https://private-user-images.githubusercontent.com/31989781/311413608-eca92a65-25dc-4aa5-a58e-8490bac5c242.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MDk5NjExMzIsIm5iZiI6MTcwOTk2MDgzMiwicGF0aCI6Ii8zMTk4OTc4MS8zMTE0MTM2MDgtZWNhOTJhNjUtMjVkYy00YWE1LWE1OGUtODQ5MGJhYzVjMjQyLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDAzMDklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQwMzA5VDA1MDcxMlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTA0MDY3NmYxYjEwNDZmMGYxZjQwN2FhOGJjNDk0MzBjYTUzZGE3NzQ2OGIxZTE0NDE0MDg1Nzc2MzRjZjYwM2MmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JmFjdG9yX2lkPTAma2V5X2lkPTAmcmVwb19pZD0wIn0.WtVAO5_CMKyepBdx5JiqwNQ8a-BnywEUsor8noRMWH8" />

----
> Haishinkit
<image width=300 src="https://private-user-images.githubusercontent.com/31989781/311413610-0d777045-4c8f-496b-81bf-4b397d61bff8.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MDk5NjExMzIsIm5iZiI6MTcwOTk2MDgzMiwicGF0aCI6Ii8zMTk4OTc4MS8zMTE0MTM2MTAtMGQ3NzcwNDUtNGM4Zi00OTZiLTgxYmYtNGIzOTdkNjFiZmY4LnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDAzMDklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQwMzA5VDA1MDcxMlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWI5ZWRlNjllNmYwMTljM2U1NzVkYjJiYzU4OWRiNTlmMjBlYjNhYjA2NzlmNWM4ZmUwNGEyMWY4OGQ1NjVlMzkmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JmFjdG9yX2lkPTAma2V5X2lkPTAmcmVwb19pZD0wIn0.FLVCBHDeSPGTsJV4FF8Yqv5613PO_nhL4Cf11_sW8jI" />


# TODO

- CPU Optimization
- Continue live streaming when app is put in background (Audio)


