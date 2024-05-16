//
//  ModelManager.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 15/05/2024.
//

import Foundation
import TensorFlowLite

class ModelManager: ObservableObject {
    private var interpreter: Interpreter?

    private let batchSize: Int
    private let channels = 2
    private let numFrames = 197
    private let frameSize = 2048
    
    init(modelName: String, batchSize: Int) {
        self.batchSize = batchSize
        loadModel(modelName: modelName)
    }

    private func loadModel(modelName: String) {
        guard let modelPath = Bundle.main.path(forResource: modelName, ofType: "tflite") else {
            print("Failed to load model file.")
            return
        }

        do {
            var delegate: Delegate? = CoreMLDelegate()
            if delegate == nil {
              delegate = MetalDelegate()
            }

            print("Creating interpreter")
            let interpreter = try Interpreter(modelPath: modelPath, delegates: [delegate!])
            print("Resizing input")
            // Set the batch size of the interpreter
            try interpreter.resizeInput(at: 0, to: Tensor.Shape([batchSize, channels, numFrames, frameSize]))
            print("Allocating tensors")
            try interpreter.allocateTensors()
        } catch {
            print("Failed to create interpreter with error: \(error.localizedDescription)")
        }
    }

    func runModel(inputData: Data) -> String? {
        // Todo...
        do {
            try interpreter?.copy(inputData, toInputAt: 0)
            try interpreter?.invoke()
            
            // TODO: Copy the output
            var outputData = try interpreter?.output(at: 0).data
            let events = outputData?.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
                let floatPointer = bytes.baseAddress!.assumingMemoryBound(to: Float32.self)
                extract_events(modelOutput: floatPointer)
            }
            
            return "Model invocation was successful ^^"
        } catch {
            print("Failed to call model!")
            return nil
        }
    }
    
    func zeroInput() -> Data {
        var zeros: [Float] = Array(repeating: 0.0, count: batchSize * channels * numFrames * frameSize)
        let data = zeros.withUnsafeBufferPointer { buffer in
            return Data(buffer: buffer)
        }
        return data;
    }
    
}

