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

private struct PreparedFrames {
    let frames: [Audio2MidiInput]
    let durationPerFrame: Double
    let frameWidth: Double
}

class ModelManager: ObservableObject {
    private var model: Audio2Midi?
    private var samplePrep: Audio2MidiSamplePrepare?

    // TODO(knielsen): Export these constants in the CoreML model metadata
    private let channels = 2
    private let numFrames = 197
    private let frameSize = 2048
    private let sampleRate = 8000.0 // Hz
    private let windowDuration = 3.0 // seconds
    private let windowOverlap = 0.5 // seconds
    
    private let audioEngine = AVAudioEngine()
    
    init() {
        do {
            let inferenceConfig = MLModelConfiguration()
            inferenceConfig.computeUnits = .cpuOnly
            model = try Audio2Midi(configuration: inferenceConfig)
            
            // The sample prep model does not currently support running on any accelerated hardware
            // For now just compute things on the CPU
            // Otherwise it errors on the iPhone and returns all 0's in the simulator
            let samplePrepConfig = MLModelConfiguration()
            samplePrepConfig.computeUnits = .cpuOnly
            samplePrep = try Audio2MidiSamplePrepare(configuration: samplePrepConfig)
        } catch {
            print("Failed to load model!")
        }
    }

    func runModel(_ audioFileUrl: URL) -> String? {
        do {
            let inputs = try prepareSamples(audioFileUrl)
            let outputs = try model!.predictions(inputs: inputs.frames)

            let middleProbs = outputs[outputs.count / 2].probs
            let events = extractEvents(modelOutput: middleProbs)
            
            return "Successfully called the model ^^\nPredicted \(events.count) events"
        } catch {
            return "Failed to call the model!"
        }
    }
    
    private func prepareSamples(_ audioFileUrl: URL) throws -> PreparedFrames {
        let samplesInWindow = Int(sampleRate * windowDuration)
        let overlap = Int(sampleRate * windowOverlap)
        let (leftSamples, rightSamples) = try extractSamples(audioFileUrl)

        let numWindows = Int(ceil(Double(leftSamples.count) / Double(samplesInWindow - overlap)))
        var windows: [Audio2MidiSamplePrepareInput] = []
        for i in 0 ..< numWindows {
            let sampleInputs = Audio2MidiSamplePrepareInput(
                samples: try MLMultiArray(shape: [2, samplesInWindow] as [NSNumber], dataType: .float16)
            )
            
            let windowStart = i * (samplesInWindow - overlap)
            let windowEnd = windowStart + samplesInWindow
            for (windowIdx, sampleIdx) in zip(0...samplesInWindow, windowStart..<windowEnd) {
                let leftSample = if sampleIdx < leftSamples.count { leftSamples[sampleIdx] } else { Float(0.0) }
                sampleInputs.samples[[0, windowIdx] as [NSNumber]] = NSNumber(value: leftSample)

                let rightSample = if sampleIdx < rightSamples.count { rightSamples[sampleIdx] } else { Float(0.0) }
                sampleInputs.samples[[1, windowIdx] as [NSNumber]] = NSNumber(value: rightSample)
            }
            windows.append(sampleInputs)
        }
        
        let outputs = try samplePrep!.predictions(inputs: windows)
        
        let durationPerFrame = outputs.first!.duration_per_frame[0]
        let frameWidth = outputs.first!.frame_width[0]
        let frames = outputs.map({ output in Audio2MidiInput(data: output.frames) })

        return PreparedFrames(
            frames: frames,
            durationPerFrame: durationPerFrame.doubleValue,
            frameWidth: frameWidth.doubleValue
        )
    }
    
    private func extractSamples(_ audioFileUrl: URL) throws -> ([Float], [Float]) {
        audioFileUrl.startAccessingSecurityScopedResource()
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
        
        audioFileUrl.stopAccessingSecurityScopedResource()
        return (leftChannel, rightChannel)
    }
    
}

