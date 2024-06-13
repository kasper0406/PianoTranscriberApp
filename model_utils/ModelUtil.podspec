Pod::Spec.new do |s|
  s.name             = 'ModelUtil'
  s.version          = '0.0.1'
  s.summary          = 'A simple library for interacting with the audio2midi model'
  s.homepage         = 'https://github.com/kasper0406/audio-to-midi'
  s.author           = { 'Kasper Nielsen' => 'kasper0406@gmail.com' }
  s.license          = { :type => 'MIT', :text => "Copyright 2024" }
  s.source           = { :http => 'https://github.com/kasper0406/audio-to-midi/rust-plugins' }
  s.platform         = :ios, '17.0'
  s.requires_arc     = true

  s.vendored_frameworks     = 'ModelUtil.xcframework'
  s.source_files            = 'Headers/*.h'
  s.public_header_files     = 'Headers/*.h'
end
