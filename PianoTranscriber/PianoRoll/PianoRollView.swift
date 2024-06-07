//
//  PianoRollView.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 28/05/2024.
//

import SwiftUI
import SpriteKit

struct PianoRollView: View {
    
    let events: [MidiEvent]
    let audioFileUrl: URL
    let audioManager: AudioManager
    
    @StateObject var scene = PianoRoll()
    
    // TODO: Consider if I can get rid of this
    @State var audioSelect: AudioSelector = AudioSelector.midi
    
    init(events: [MidiEvent], audioFileUrl: URL, audioManager: AudioManager) {
        self.events = events
        self.audioFileUrl = audioFileUrl
        self.audioManager = audioManager
    }

    var body: some View {
        VStack {
            GeometryReader { geo in
                SpriteView(scene: scene)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea(.container)
                    .onChange(of: events) { setupScene(size: geo.size) }
                    .onAppear { setupScene(size: geo.size) }
            }
            HStack {
                Button(action: {
                    scene.setPlaybackTime(0.0)
                }) {
                    Image(systemName: "backward.end")
                }.disabled(scene.isAtBeginning)

                Button(action: {
                    if scene.isPlaying {
                        scene.pause()
                    } else {
                        scene.play()
                    }
                }) {
                    if scene.isPlaying {
                        Image(systemName: "pause")
                    } else {
                        Image(systemName: "play")
                    }
                }
                
                Picker("Audio", selection: $audioSelect) {
                    Text("Midi").tag(AudioSelector.midi)
                    Text("Original").tag(AudioSelector.original)
                    Text("Mix").tag(AudioSelector.mix)
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: audioSelect) {
                    self.audioManager.selectAudio(audioSelect)
                }
            }
        }
    }
    
    func setupScene(size: CGSize) {
        scene.size = size
        do {
            try scene.setup(events, audioFileUrl, audioManager)
        } catch {
            print("Failed to set up piano roll! :(")
        }
    }
}
