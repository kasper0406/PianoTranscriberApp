//
//  PianoRollViewModel.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 12/06/2024.
//

import Foundation

class PianoRollViewModel: ObservableObject {
    
    @Published var pianoRollView: PianoRollView? = nil
    @Published var scene = PianoRollScene()
    
    func show(_ inferenceResult: InferenceResult, _ audioManager: AudioManager) {
        pianoRollView = PianoRollView(
            events: inferenceResult.events,
            audioFileUrl: inferenceResult.audioFileUrl,
            audioManager: audioManager,
            scene: scene)
    }

    func hide() {
        pianoRollView = nil
    }
    
    func pause() {
        pianoRollView?.pause()
    }
}
