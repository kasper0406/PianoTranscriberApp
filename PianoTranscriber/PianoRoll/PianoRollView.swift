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
    let audioManager: AudioManager
    
    @StateObject var scene = PianoRoll()
    
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
            }
        }
    }
    
    func setupScene(size: CGSize) -> PianoRoll {
        scene.size = size
        do {
            try scene.setup(events, audioManager)
        } catch {
            print("Failed to set up piano roll! :(")
        }
        return scene
    }
}
