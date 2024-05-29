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
                }.disabled(scene.playbackTime == 0.0)

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
        scene.events = self.events
        return scene
    }
}
