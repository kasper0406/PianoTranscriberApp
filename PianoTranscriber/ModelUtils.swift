//
//  ModelUtils.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 16/05/2024.
//

import Foundation

func extract_events(modelOutput: UnsafeMutablePointer<Float32>) {
    print("Calling rust!")
    let raw_events = extract_midi_events(2, 197, 4096, modelOutput)
    
    print("Got a pointer from rust: \(String(describing: raw_events))")
    
    free_midi_events(raw_events)
    print("It has now been freed!!!")
}
