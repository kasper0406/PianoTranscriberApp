//
//  ModelManager.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 15/05/2024.
//

import Foundation
import CoreML
import AVFoundation
import Algorithms

enum Audio2MidiModelErrors: Error {
    case audioFormatTooManyChannels
    case resamplingFailed
    case failedToObtainPermission
    case imbalancedNumberOfSamples
}

struct InferenceResult {
    let audioFileUrl: URL
    let events: [MidiEvent]
}

// TODO(knielsen): Make this nicer!
extension MLMultiArray {
    func prependDimension() throws -> MLMultiArray? {
        if self.shape.count != 2 {
            return nil
        }
        let oldShape = self.shape as [NSNumber]
        let newShape = [1, oldShape[0], oldShape[1]] as [NSNumber]

        let newArray = try MLMultiArray(shape: newShape, dataType: self.dataType)
        for i in 0..<oldShape[0].intValue {
            for j in 0..<oldShape[1].intValue {
                newArray[[0, i, j] as [NSNumber]] = self[[i, j] as [NSNumber]]
            }
        }

        return newArray
    }
}

class ModelManager: ObservableObject {
    @Published private(set) var inferenceStatus: InferenceProgress = InferenceProgress.notRunning
    // @Published var cancelRunningInferrence: Bool = false
    
    private var model: Audio2Midi?

    // TODO(knielsen): Export these constants in the CoreML model metadata
    private let channels = 2
    private let sampleRate = 16000.0 // Hz
    private let windowDuration = 5.0 // seconds
    private let windowOverlap = 0.50 // seconds
    
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
            
            // Re-sample audio
            let inputs = try self.prepareSamples(audioFileUrl)
            
            // Infer events
            await MainActor.run {
                self.inferenceStatus = InferenceProgress.inferring(0.0)
            }
            let batchSize = 2 // * 5 seconds
            var outputProbs: [MLMultiArray] = []
            outputProbs.reserveCapacity(inputs.count)
            for chunk in inputs.chunks(ofCount: batchSize) {
                let chunkOutputs = try self.model!.predictions(inputs: Array(chunk))
                    .map({ output in output.probs })
                    .map({ output in try output.prependDimension()! })
                outputProbs.append(contentsOf: chunkOutputs)
                
                let progress = outputProbs.count
                await MainActor.run {
                    self.inferenceStatus = InferenceProgress.inferring(Double(progress) / Double(inputs.count))
                }
            }
            let combinedProbs = MLMultiArray.init(concatenating: outputProbs, axis: 0, dataType: .float16)
            
            // Extract events
            await MainActor.run {
                self.inferenceStatus = InferenceProgress.eventizing
            }
            let durationPerFrame = self.windowDuration / combinedProbs.shape[1].doubleValue
            let events = extractEvents(combinedOutput: combinedProbs, overlap: self.windowOverlap, durationPerFrame: durationPerFrame)
            
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
                samples: try MLMultiArray(shape: [2, samplesInWindow] as [NSNumber], dataType: .float16)
            )
            
            let windowStart = i * (samplesInWindow - overlap)
            let windowEnd = windowStart + samplesInWindow
            for (windowIdx, sampleIdx) in zip(0...samplesInWindow, windowStart..<windowEnd) {
                let leftSample = if sampleIdx < leftSamples.count { leftSamples[sampleIdx] } else { Float(0.0) }
                sampleInputs.samples[[0, windowIdx] as [NSNumber]] = NSNumber(value: leftSample * 20)

                let rightSample = if sampleIdx < rightSamples.count { rightSamples[sampleIdx] } else { Float(0.0) }
                sampleInputs.samples[[1, windowIdx] as [NSNumber]] = NSNumber(value: rightSample * 20)
            }
            windows.append(sampleInputs)
        }
        
        return windows
    }
    
    private func extractSamples(_ audioFileUrl: URL) throws -> ([Float], [Float]) {
        if !audioFileUrl.startAccessingSecurityScopedResource() {
            throw Audio2MidiModelErrors.failedToObtainPermission
        }
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
        let errorPtr: NSErrorPointer = nil;
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
        return try normalizeSamples(left: leftChannel, right: rightChannel)
    }

    private func normalizeSamples(left: [Float], right: [Float]) throws -> ([Float], [Float]) {
        let totalElements = Double(left.count + right.count)

        // guard to avoid crash if left and right have different number of elements
        guard left.count == right.count else {
            throw Audio2MidiModelErrors.imbalancedNumberOfSamples
        }

        // Calculate the variance.  Use zip to iterate over both arrays simultaneously.
        let variance = zip(left, right).reduce(0.0) { (acc, pair) in
            let (leftVal, rightVal) = pair
            return acc + (pow(Double(leftVal), 2) + pow(Double(rightVal), 2)) / totalElements
        }
        
        guard variance > 0.01 else {
            return (left, right)
        }
        let adjustment = sqrt(1.0 / variance) / 4.0
        print("Adjusting samples with a factor of \(adjustment)")

        // Apply the adjustment to each sample.
        let normalizedLeft = left.map { Float(Double($0) * adjustment) }
        let normalizedRight = right.map { Float(Double($0) * adjustment) }

        return (normalizedLeft, normalizedRight)
    }
}

