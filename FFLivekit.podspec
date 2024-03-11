Pod::Spec.new do |s|
  s.name             = 'FFLivekit'
  s.version          = '0.0.1'
  s.summary          = 'A summary of your project.'
  s.description      = 'A detailed description of your project.'
  s.homepage         = 'https://github.com/sxudan/FFLivekit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Sudan Suwal' => 'sudosuwal@gmail.com.com' }
  s.source           = { :git => 'https://github.com/sxudan/FFLivekit.git', :tag => s.version.to_s }
  s.swift_version    = '5.0'
  s.platforms        = { :ios => '13.0' }
  s.source_files     = 'FFLivekit/**/*.{h,swift}'
  s.dependency 'ffmpeg-kit-ios-full'
end
