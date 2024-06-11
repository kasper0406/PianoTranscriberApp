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

    @State var _wasPlaying = false
    private func userChangingTimeAction(_ isEditing: Bool) {
        if isEditing {
            self._wasPlaying = self.scene.isPlaying
            self.scene.pause()
        }
        if !isEditing {
            if _wasPlaying {
                self.scene.play()
            }
        }
    }
    
    var body: some View {
        VStack {
            GeometryReader { geo in
                SpriteView(scene: scene)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea(.container)
                    .onChange(of: events) { setupScene(size: geo.size) }
                    .onAppear {
                        setupScene(size: geo.size)
                    }
            }
            
            HStack {
                Text("\(formatTime(time: 0))")  // Start time
                Spacer()
                Text("\(formatTime(time: self.scene.playbackTime))")  // Current time
                Spacer()
                Text("\(formatTime(time: self.scene.duration))")  // End time
            }
            .padding(.horizontal)
            Slider(
                value: Binding(
                    get: {
                        self.scene.playbackTime
                    },
                    set: {(newValue) in
                        self.scene.setEventsOnlyPlaybackTime(newValue)
                    }
                ),
                in: 0...self.scene.duration,
                onEditingChanged: userChangingTimeAction
            )
            .padding(.horizontal)
            
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
    
    private func formatTime(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
