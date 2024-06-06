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
    @StateObject private var audioManager = AudioManager()
    
    @State private var inferenceResult: InferenceResult?
    @State private var isFilePickerShowing = false;
    
    var body: some View {
        let showInferenceProgress = switch modelManager.inferenceStatus {
        case InferenceProgress.notRunning:
            false
        default:
            true
        }
        
        ZStack {
            NavigationView {
                VStack {
                    if let result = inferenceResult {
                        Text("Inference completed for \(result.audioFileUrl.lastPathComponent)")
                        PianoRollView(events: result.events, audioManager: audioManager)
                    } else {
                        Text("Import a file ^^")
                    }
                }
                .padding()
                .navigationBarItems(trailing: Button(action: {
                        isFilePickerShowing = true
                    }) {
                        Image(systemName: "plus")
                    }.fileImporter(
                        isPresented: $isFilePickerShowing,
                        allowedContentTypes: [.audio],
                        onCompletion: { pickedFile in
                            do {
                                let audioFileUrl = try pickedFile.get()
                                Task {
                                    inferenceResult = await modelManager.runModel(audioFileUrl)
                                }
                            } catch {
                                inferenceResult = nil
                            }
                        })
                )
            }
            .blur(radius: showInferenceProgress ? 3 : 0)
            
            if showInferenceProgress {
                InferenceProgressView(progress: modelManager.inferenceStatus)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: showInferenceProgress)
        .onAppear() {
            do {
                try audioManager.setup()
            } catch {
                print("Failed to set up audio manager")
            }
        }
    }
}
