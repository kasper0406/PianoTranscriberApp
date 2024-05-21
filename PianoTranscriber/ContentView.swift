//
//  ContentView.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 15/05/2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var modelManager = ModelManager()
    
    @State private var resultText: String = "Calling model..."
    
    var body: some View {
        VStack {
            Text(resultText)
                .padding()
                .onAppear {
                    if let result = modelManager.runModel() {
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
