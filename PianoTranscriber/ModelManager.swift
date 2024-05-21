//
//  ModelManager.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 15/05/2024.
//

import Foundation
import CoreML
import AVFoundation

enum Audio2MidiModelErrors: Error {
    case audioFormatTooManyChannels
    case resamplingFailed
}

class ModelManager: ObservableObject {
    private var model: audio2midi?

    private let channels = 2
    private let numFrames = 197
    private let frameSize = 2048
    private let sampleRate = 8000.0
    
    private let audioEngine = AVAudioEngine()
    
    init() {
        do {
            model = try audio2midi()
        } catch {
            print("Failed to load model!")
        }
    }

    func runModel(_ audioFileUrl: URL) -> String? {
        do {
            let (leftSamples, rightSamples) = try extractSamples(audioFileUrl)
            let input = try zeroInput()
            let output = try model?.prediction(input: input)
            
            let logits = output!.Identity
            let probs = output!.Identity_1
            
            let events = extractEvents(modelOutput: probs)
            
            return "Successfully called the model ^^\nPredicted \(events.count) events"
        } catch {
            return "Failed to call the model!"
        }
    }
    
    private func extractSamples(_ audioFileUrl: URL) throws -> ([Float], [Float]) {
        let audioFile = try AVAudioFile(forReading: audioFileUrl)
        let audioFormat = audioFile.processingFormat
        if audioFormat.channelCount > 2 {
            throw Audio2MidiModelErrors.audioFormatTooManyChannels
        }
        
        let outputAudioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: audioFormat.channelCount)!
        let converter = AVAudioConverter(
            from: audioFormat,
            to: outputAudioFormat
        )!
        
        let inputBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(audioFile.length))!
        try audioFile.read(into: inputBuffer)

        let outputBuffer = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: inputBuffer.frameLength)!
        var errorPtr: NSErrorPointer = nil;
        var dataProvided = false
        converter.convert(to: outputBuffer, error: errorPtr, withInputFrom: { inNumPackets, outStatus in
            if dataProvided {
                outStatus.pointee = .endOfStream
                return nil
            } else {
                dataProvided = true
                outStatus.pointee = .haveData
                return inputBuffer
            }
        })
        if errorPtr != nil {
            throw Audio2MidiModelErrors.resamplingFailed
        }

        let outputFrames = outputBuffer.frameLength
        let leftChannel = Array(UnsafeBufferPointer(
            start: outputBuffer.floatChannelData?.advanced(by: 0).pointee,
            count: Int(outputBuffer.frameLength))
        )
        
        var rightChannel = leftChannel
        if audioFormat.channelCount == 2 {
            rightChannel = Array(UnsafeBufferPointer(
                start: outputBuffer.floatChannelData?.advanced(by: 1).pointee,
                count: Int(outputBuffer.frameLength))
            )
        }
        
        return (leftChannel, rightChannel)
    }

    func zeroInput() throws -> audio2midiInput {
        let data = try MLMultiArray(
            shape: [1, channels as NSNumber, numFrames as NSNumber, frameSize as NSNumber],
            dataType: MLMultiArrayDataType.float16)

        data.withUnsafeMutableBytes({ rawPtr, _strides in
            let floatPtr = rawPtr.bindMemory(to: Float16.self)
            for i in 0..<data.count {
                floatPtr[i] = 0.0
            }
        })

        let input = audio2midiInput(data: data)
        return input
    }
    
}

