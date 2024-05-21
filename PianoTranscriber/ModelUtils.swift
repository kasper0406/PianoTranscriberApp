//
//  ModelUtils.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 16/05/2024.
//

import Foundation
import CoreML

struct MidiEvent {
    var attackTime: Int
    var duration: Int
    var note: Int
    var velocity: Int
}

func extractEvents(modelOutput: MLMultiArray) -> [MidiEvent] {
    let numFrames = modelOutput.shape[1]
    let numNotes = modelOutput.shape[2]
    
    print("Calling rust!")
    let rawEvents = modelOutput.withUnsafeBytes({ rawPtr in
        let ptr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self)
        return extract_midi_events(numFrames.int32Value, numNotes.int32Value, ptr)
    })

    var events: [MidiEvent] = []
    
    print("Got a pointer from rust: \(String(describing: rawEvents))")
    for i in 0..<rawEvents!.pointee.length {
        let rawEvent = rawEvents!.pointee.ptr[Int(i)]
        events.append(MidiEvent(
            attackTime: Int(rawEvent.attack_time),
            duration: Int(rawEvent.duration),
            note: Int(rawEvent.note),
            velocity: Int(rawEvent.velocity)
        ))
    }
    
    free_midi_events(rawEvents)
    print("It has now been freed!!!")
    
    return events
}
