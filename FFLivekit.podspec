Pod::Spec.new do |s|
  s.name             = 'FFLivekit'
  s.version          = '0.0.2'
  s.summary          = "This is a live streaming FFmpeg based package to publish the live streams to RTMP or RTSP servers"
  s.description      = "FFLivekit is a robust live streaming package that seamlessly integrates with FFmpeg to enable the effortless publishing of live streams to RTMP (Real-Time Messaging Protocol) or RTSP (Real-Time Streaming Protocol) servers. Leveraging the powerful capabilities of FFmpeg, this package empowers developers to create high-quality, real-time video broadcasts with ease. Whether you're building a live streaming platform, video conferencing application, or any real-time video communication tool, FFLivekit simplifies the integration of live streaming features, providing a reliable solution for delivering dynamic content to your audience."
  s.homepage         = 'https://github.com/sxudan/FFLivekit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Sudan Suwal' => 'sudosuwal@gmail.com.com' }
  s.source           = { :git => 'https://github.com/sxudan/FFLivekit.git', :tag => s.version.to_s }
  s.swift_version    = '5.0'
  s.platforms        = { :ios => '13.0' }
  s.source_files     = 'FFLivekit/**/*.{h,swift}'
  s.dependency 'ffmpeg-kit-srt'
end
