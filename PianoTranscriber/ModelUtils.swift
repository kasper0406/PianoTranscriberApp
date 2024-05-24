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
    let numFrames = modelOutput.shape[0].int32Value
    let numNotes = modelOutput.shape[1].int32Value
    let frameStride = modelOutput.strides[0].int32Value
    let noteStride = modelOutput.strides[1].int32Value

    let rawEvents = modelOutput.withUnsafeBytes({ rawPtr in
        let ptr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self)
        return extract_midi_events(numFrames, frameStride, numNotes, noteStride, ptr)
    })

    var events: [MidiEvent] = []
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
    
    return events
}
