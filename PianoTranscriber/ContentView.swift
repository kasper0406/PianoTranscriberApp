//
//  ContentView.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 15/05/2024.
//

import SwiftUI
import UniformTypeIdentifiers

struct MidiExportState: Equatable {
    var isShowing: Bool
    var url: URL?
}

struct ContentView: View {
    @StateObject private var modelManager = ModelManager()
    @StateObject private var audioManager = AudioManager()
    
    @State private var inferenceResult: InferenceResult?
    @State private var isFilePickerShowing = false;
    
    @State private var midiExportState = MidiExportState(isShowing: false);
    
    @StateObject private var pianoRollModel = PianoRollViewModel()
    
    var body: some View {
        let showInferenceProgress = switch modelManager.inferenceStatus {
        case InferenceProgress.notRunning:
            false
        default:
            true
        }
        
        ZStack {
            VStack {
                HStack {
                    exportMidiButton()
                    Spacer()
                    loadFileButtonIfFilePresent()
                }
                
                if let pianoRollView = pianoRollModel.pianoRollView {
                    let filename = inferenceResult!.audioFileUrl.deletingPathExtension().lastPathComponent
                    Text("\(filename)")
                        .font(.title)
                        .padding()
                    
                    pianoRollView
                } else {
                    VStack {
                        Image("SmileWithEars")
                            .resizable()
                            .scaledToFit()
                            .padding()
                        loadFileButton()
                            .padding()
                    }
                }
            }
            .padding()
            
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
    
    private func exportMidiButton() -> some View {
        return Group {
            if inferenceResult != nil {
                Button(action: {
                    pianoRollModel.pause()
                    
                    let fileName = inferenceResult!.audioFileUrl.deletingPathExtension().lastPathComponent
                    if let midiFile = audioManager.exportMidiFile(fileName) {
                        print("Setting showing to true")
                        midiExportState = MidiExportState(isShowing: true, url: midiFile)
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Midi")
                }.sheet(isPresented: $midiExportState.isShowing, onDismiss: {
                    if let midiFileUrl = midiExportState.url {
                        do {
                            try FileManager.default.removeItem(at: midiFileUrl)
                            midiFileUrl.stopAccessingSecurityScopedResource()
                        } catch {
                            print("Failed to clean up temp midi file")
                        }
                        midiExportState = MidiExportState(isShowing: false)
                    }
                }) {
                    if let midiFileUrl = midiExportState.url {
                        FileExporterViewController(
                            items: [midiFileUrl]
                        )
                    }
                }
                // HACK: Ensure the view depends on midiExportState to make rendering of the sheet work correctly
                // https://stackoverflow.com/questions/77169389/swiftui-bound-state-variable-not-updated-when-showing-sheet
                .onChange(of: midiExportState) { _ in }
            }
        }
    }
    
    private func loadFileButtonIfFilePresent() -> some View {
        return Group {
            if inferenceResult != nil {
                loadFileButton()
            }
        }
    }
    
    private func loadFileButton() -> some View {
        return Button(action: {
            pianoRollModel.pause()
            isFilePickerShowing = true
        }) {
            Text("New piano file")
            Image(systemName: "plus")
        }.fileImporter(
            isPresented: $isFilePickerShowing,
            allowedContentTypes: [.audio],
            onCompletion: { pickedFile in
                do {
                    let audioFileUrl = try pickedFile.get()
                    Task {
                        let maybeInferenceResult = await modelManager.runModel(audioFileUrl)
                        if let inferenceResult = maybeInferenceResult {
                            await MainActor.run {
                                self.inferenceResult = inferenceResult
                                self.pianoRollModel.show(inferenceResult, audioManager)
                            }
                        }
                    }
                } catch {
                    inferenceResult = nil
                    pianoRollModel.hide()
                }
            })
    }
}
