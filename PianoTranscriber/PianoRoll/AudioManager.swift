//
//  AudioManager.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 29/05/2024.
//

import Foundation
import AVFoundation

enum AudioSelector: Equatable {
    case mix
    case original
    case midi
}

class AudioManager: ObservableObject {
    let sampleRate = 44100.0
    
    // Audio library instances
    let engine: AVAudioEngine
    let sampler: AVAudioUnitSampler
    let sequencer: AVAudioSequencer
    let player: AVAudioPlayerNode
    let audioSession: AVAudioSession
    
    var originalAudioFile: AVAudioFile?
    
    @Published var audioSelector = AudioSelector.midi
    
    init() {
        // Set up formats and export settings
        let format = AVAudioFormat(
            commonFormat: AVAudioCommonFormat.pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: false)!

        engine = AVAudioEngine()
        sampler = AVAudioUnitSampler()
        player = AVAudioPlayerNode()

        // Setup the engine
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: format)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)

        // Setup the sequencer
        sequencer = AVAudioSequencer(audioEngine: engine)
        
        audioSession = AVAudioSession.sharedInstance()
        handleNotificationInterruptions()
        
        selectAudio(self.audioSelector)
    }
    
    deinit {
        if let audioFile = self.originalAudioFile?.url {
            audioFile.stopAccessingSecurityScopedResource()
        }
    }
    
    func selectAudio(_ audioSelector: AudioSelector) {
        self.audioSelector = audioSelector
        switch audioSelector {
        case .midi:
            player.volume = 0.0
            sampler.volume = 1.0
        case .original:
            player.volume = 1.0
            sampler.volume = 0.0
        case .mix:
            player.volume = 0.6
            sampler.volume = 0.6
        }
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
    
    func stageEvents(events: [MidiEvent], originalAudioFileUrl: URL) {
        // Set up the original audio player
        if let oldFile = self.originalAudioFile?.url {
            oldFile.stopAccessingSecurityScopedResource()
        }
        do {
            originalAudioFileUrl.startAccessingSecurityScopedResource()
            self.originalAudioFile = try AVAudioFile(forReading: originalAudioFileUrl)
            player.scheduleSegment(originalAudioFile!,
                                   startingFrame: AVAudioFramePosition(0),
                                   frameCount: AVAudioFrameCount(originalAudioFile!.length),
                                   at: nil)
        } catch {
            originalAudioFileUrl.stopAccessingSecurityScopedResource()
            print("Failed to play original audio!")
        }

        // Setup the sequencer
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
        player.play()
    }
    
    func pause() {
        sequencer.stop()
        player.stop()
    }
    
    func setPlaybackTime(_ time: TimeInterval) {
        sequencer.currentPositionInSeconds = time
        
        if let audioFile = self.originalAudioFile {
            let playerStartFrame = AVAudioFramePosition(audioFile.fileFormat.sampleRate * time)
            player.scheduleSegment(audioFile,
                                   startingFrame: playerStartFrame,
                                   frameCount: AVAudioFrameCount(audioFile.length),
                                   at: nil)
        }
    }
}
