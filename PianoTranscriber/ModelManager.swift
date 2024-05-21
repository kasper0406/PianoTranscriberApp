//
//  ModelManager.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 15/05/2024.
//

import Foundation
import CoreML

class ModelManager: ObservableObject {
    private var model: audio2midi?

    private let channels = 2
    private let numFrames = 197
    private let frameSize = 2048
    
    init() {
        do {
            model = try audio2midi()
        } catch {
            print("Failed to load model!")
        }
    }

    func runModel() -> String? {
        do {
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

