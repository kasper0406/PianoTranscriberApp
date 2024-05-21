//
//  ContentView.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 15/05/2024.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var modelManager = ModelManager()
    
    @State private var resultText: String = "Calling model..."
    @State private var audioFileURL: URL?
    
    @State private var isFilePickerShowing = false;
    
    var body: some View {
        VStack {
            if let url = audioFileURL {
                Text("File seslected \(url.lastPathComponent)")
                Text(resultText)
                    .padding()
                    .onAppear {
                        if let result = modelManager.runModel(url) {
                            resultText = result
                        } else {
                            resultText = "Failed to call the model :("
                        }
                    }
            } else {
                Button("Selected an audio file xD") {
                    isFilePickerShowing.toggle()
                }.fileImporter(
                    isPresented: $isFilePickerShowing,
                    allowedContentTypes: [.audio],
                    onCompletion: { pickedFile in
                        do {
                            self.audioFileURL = try pickedFile.get()
                        } catch {
                            self.audioFileURL = nil
                        }
                    })
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
