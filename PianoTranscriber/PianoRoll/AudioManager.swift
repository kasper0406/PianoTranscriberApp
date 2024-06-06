//
//  AudioManager.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 29/05/2024.
//

import Foundation
import AVFoundation

class AudioManager: ObservableObject {
    let sampleRate = 44100.0
    
    // Audio library instances
    let engine: AVAudioEngine
    let sampler: AVAudioUnitSampler
    let sequencer: AVAudioSequencer
    let audioSession: AVAudioSession
    
    init() {
        // Set up formats and export settings
        let format = AVAudioFormat(
            commonFormat: AVAudioCommonFormat.pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: false)!

        engine = AVAudioEngine()
        sampler = AVAudioUnitSampler()

        // Setup the engine
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)

        // Setup the sequencer
        sequencer = AVAudioSequencer(audioEngine: engine)
        
        self.audioSession = AVAudioSession.sharedInstance()
        handleNotificationInterruptions()
    }
    
    func setup() throws {
        try engine.start()
        
        // Load the instrument
        guard let pianoSamplesUrl = Bundle.main.url(forResource: "PianoSamples", withExtension: "sf2") else {
            fatalError("Piano samples not found!")
        }
        try sampler.loadInstrument(at: pianoSamplesUrl)
        
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
    }
    
    private func handleNotificationInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        // Handle interruptions (e.g., pause, resume audio)
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Interruption began, pause audio
            self.pause()
            
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Interruption ended. Resume playback, if appropriate
                    do {
                        try self.play()
                    } catch {
                        print("Failed to resume playing")
                    }
                }
            }
        @unknown default:
            print("A new type of audio session interruption was added that is not handled")
        }
    }

    @objc private func handleAudioRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .newDeviceAvailable:
            return
            
        case .oldDeviceUnavailable:
            // The old device (e.g., headphones) became unavailable
            // This is a good spot to pause the audio if the headphones are unplugged
            self.pause()

        case .categoryChange:
            return
            
        default:
            print("Audio route has changed for some other reason.")
        }
    }
    
    func stageEvents(events: [MidiEvent]) {
        if sequencer.tracks.isEmpty {
            sequencer.createAndAppendTrack()
        }
        let track = sequencer.tracks[0]

        for event in events {
            let noteMidiEvent = AVMIDINoteEvent(
                channel: 0,
                key: UInt32(event.note + 21),
                velocity: UInt32(Double(127) * Double(event.velocity) / Double(10)),
                duration: event.duration * 2)
            track.addEvent(noteMidiEvent, at: event.attackTime * 2)
        }
        sequencer.prepareToPlay()
    }
    
    func play() throws {
        try sequencer.start()
    }
    
    func pause() {
        sequencer.stop()
    }
    
    func setPlaybackTime(_ time: TimeInterval) {
        sequencer.currentPositionInSeconds = time
    }
}
