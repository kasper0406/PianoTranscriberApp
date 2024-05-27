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

func extractEvents(combinedOutput: MLMultiArray, overlap: Double, durationPerFrame: Double) -> [MidiEvent] {
    let rawEvents = combinedOutput.withUnsafeBytes({ rawPtr in
        let ptr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self)
        let rustArray = MLMultiArrayWrapper3(
            strides: (combinedOutput.strides[0].uint64Value, combinedOutput.strides[1].uint64Value, combinedOutput.strides[2].uint64Value),
            dims: (combinedOutput.shape[0].uint64Value, combinedOutput.shape[1].uint64Value, combinedOutput.shape[2].uint64Value),
            data: ptr
        )
        return extract_midi_events(rustArray, overlap, durationPerFrame)
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
