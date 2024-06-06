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
    
    var body: some View {
        VStack {
            GeometryReader { geo in
                SpriteView(scene: setupScene(size: geo.size))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea(.container)
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
                .onChange(of: audioSelect) { newValue in
                    self.audioManager.selectAudio(newValue)
                }
            }
        }
    }
    
    func setupScene(size: CGSize) -> PianoRoll {
        scene.size = size
        do {
            try scene.setup(events, audioFileUrl, audioManager)
        } catch {
            print("Failed to set up piano roll! :(")
        }
        return scene
    }
}
