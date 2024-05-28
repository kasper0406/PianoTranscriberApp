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
    
    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: setupScene(size: geo.size))
                .frame(width: geo.size.width, height: geo.size.height)
                .ignoresSafeArea(.container)
        }
    }
    
    func setupScene(size: CGSize) -> PianoRoll {
        let scene = PianoRoll()
        scene.size = size
        scene.events = self.events
        return scene
    }
}
