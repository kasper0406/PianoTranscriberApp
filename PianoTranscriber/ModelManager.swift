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

struct InferenceResult {
    let audioFileUrl: URL
    let events: [MidiEvent]
}

class ModelManager: ObservableObject {
    @Published private(set) var inferenceStatus: InferenceProgress = InferenceProgress.notRunning
    // @Published var cancelRunningInferrence: Bool = false
    
    private var model: Audio2Midi?

    // TODO(knielsen): Export these constants in the CoreML model metadata
    private let channels = 2
    private let sampleRate = 8000.0 // Hz
    private let windowDuration = 2.0 // seconds
    private let windowOverlap = 0.25 // seconds
    
    private let audioEngine = AVAudioEngine()
    
    init() {
        do {
            let inferenceConfig = MLModelConfiguration()
            inferenceConfig.computeUnits = .cpuAndNeuralEngine
            model = try Audio2Midi(configuration: inferenceConfig)
        } catch {
            print("Failed to load model!")
        }
    }

    func runModel(_ audioFileUrl: URL) async -> InferenceResult? {
        defer {
            // ¯\_(ツ)_/¯
            Task { @MainActor in
                self.inferenceStatus = InferenceProgress.notRunning
            }
        }
        
        let result = Task.detached(priority: .userInitiated) {
            await MainActor.run {
                self.inferenceStatus = InferenceProgress.loadingAudio
            }
            
            let inputs = try self.prepareSamples(audioFileUrl)
            
            // TODO: Update the status
            await MainActor.run {
                self.inferenceStatus = InferenceProgress.inferring(0.5)
            }
            let outputs = try self.model!.predictions(inputs: inputs)
            
            // TODO: Stitch the predicted events
            
            await MainActor.run {
                self.inferenceStatus = InferenceProgress.eventizing
            }
            let middleProbs = outputs[outputs.count / 2].probs
            let events = extractEvents(modelOutput: middleProbs)
            
            for event in events {
                print("Predicted event (\(event.attackTime), \(event.duration), \(event.note))")
            }
            
            return InferenceResult(audioFileUrl: audioFileUrl, events: events)
        }
        
        do {
            return try await result.value
        } catch {
            return nil
        }
    }
    
    private func prepareSamples(_ audioFileUrl: URL) throws -> [Audio2MidiInput] {
        let samplesInWindow = Int(sampleRate * windowDuration)
        let overlap = Int(sampleRate * windowOverlap)
        let (leftSamples, rightSamples) = try extractSamples(audioFileUrl)

        let numWindows = Int(ceil(Double(leftSamples.count) / Double(samplesInWindow - overlap)))
        var windows: [Audio2MidiInput] = []
        for i in 0 ..< numWindows {
            let sampleInputs = Audio2MidiInput(
                data: try MLMultiArray(shape: [2, samplesInWindow] as [NSNumber], dataType: .float16)
            )
            
            let windowStart = i * (samplesInWindow - overlap)
            let windowEnd = windowStart + samplesInWindow
            for (windowIdx, sampleIdx) in zip(0...samplesInWindow, windowStart..<windowEnd) {
                let leftSample = if sampleIdx < leftSamples.count { leftSamples[sampleIdx] } else { Float(0.0) }
                sampleInputs.data[[0, windowIdx] as [NSNumber]] = NSNumber(value: leftSample)

                let rightSample = if sampleIdx < rightSamples.count { rightSamples[sampleIdx] } else { Float(0.0) }
                sampleInputs.data[[1, windowIdx] as [NSNumber]] = NSNumber(value: rightSample)
            }
            windows.append(sampleInputs)
        }
        
        return windows
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

