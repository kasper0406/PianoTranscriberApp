//
//  ContentView.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 15/05/2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var modelManager = ModelManager(
        modelName: "audio_to_midi_v1.tflite",
        batchSize: 4)
    
    @State private var resultText: String = "Calling model..."
    
    var body: some View {
        VStack {
            Text(resultText)
                .padding()
                .onAppear {
                    let modelInput = modelManager.zeroInput()
                    if let result = modelManager.runModel(inputData: modelInput) {
                        resultText = result
                    } else {
                        resultText = "Failed to call the model :("
                    }
                }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
