platform :ios, '17.0'
use_frameworks!

target 'PianoTranscriber' do
    pod 'TensorFlowLiteSwift', :subspecs => ['CoreML', 'Metal']
    pod 'ModelUtil', :path => "/Volumes/git/ml/models/audio-to-midi/rust-plugins/target/universal-ios/release/"
end
