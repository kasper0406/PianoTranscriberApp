//
//  PianoRoll.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 28/05/2024.
//

import Foundation
import SpriteKit
import Algorithms

enum PianoKeyType {
    case white
    case black
}

private func findMidiEventJustAfter(_ events: [MidiEvent], _ time: Double) -> Int? {
    var low = 0
    var high = events.count

    while low < high {
        let mid = low + (high - low) / 2
        if events[mid].attackTime < time {
            low = mid + 1
        } else {
            high = mid
        }
    }

    if low >= events.count {
        return nil
    }
    return low
}

func createRoundedRectImage(size: CGSize, cornerRadius: CGFloat) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)

    let rect = CGRect(origin: .zero, size: size)
    let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

    UIColor.white.setFill()
    path.fill()

    let image = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()

    return image
}

class PianoRollScene: SKScene, ObservableObject {
    
    private var audioManager: AudioManager?
    
    private var events: [MidiEvent] = []
    private var eventToNode: [MidiEvent:SKSpriteNode] = [:]
    private var keyToNode: [Int:(PianoKeyType, SKSpriteNode)] = [:]
    private var nextEventIdx: Int? = 0
    
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var duration: Double = 0.0
    @Published var playbackTime: Double = 0.0
    
    let pianoWidth: Double = 35.0
    let pianoBorder1Width: Double = 1.0
    let pianoBorder2Width: Double = 3.0
    private lazy var eventStartPosition: Double = pianoWidth + pianoBorder1Width + pianoBorder2Width
    
    var keyRange: ClosedRange<Int> = 0...87
    
    private var internalPlaybackTime: Double = 0
    private var lastUpdateTime: TimeInterval = 0
    private var eventNode: SKNode? = nil
    private var keysNode: SKNode? = nil
    
    let timeScaleFactor = 400.0 // (x units / second)
    
    let eventColor: UIColor = UIColor.systemBlue // UIColor(red: 0.6, green: 0.6, blue: 1.0, alpha: 1.0)
    let eventActivationColor: UIColor = UIColor.systemRed // UIColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0)
    let keyColorWhite: UIColor = UIColor(red: 0.99, green: 0.96, blue: 0.94, alpha: 1.0)
    let keyColorBlack: UIColor = .black
    
    func setup(_ events: [MidiEvent], _ audioFileUrl: URL, _ audioManager: AudioManager) throws {
        print("Setting up scene")

        pause()
        
        self.events = events
        self.audioManager = audioManager
        self.audioManager!.stageEvents(events: events, originalAudioFileUrl: audioFileUrl)
        self.duration = self.audioManager!.originalAudioDuration
        
        nextEventIdx = 0
        internalPlaybackTime = 0
        lastUpdateTime = 0
        isPlaying = false
        playbackTime = 0.0
        
        redrawAll()
    }
    
    func play() {
        print("Playing at position \(internalPlaybackTime)")
        audioManager?.setPlaybackTime(internalPlaybackTime) // This is kind of hacky, but it is to make sure user editing time works
        isPlaying = true
        
        // It is slightly incorrect to play here, and then in the update function we use a
        // potentially wrong delta time to update event positions.
        // However, the update function should be called very frequently, so I expect the delay
        // to be insignificant.
        do {
            try audioManager?.play()
        } catch {
            print("Failed to play")
        }
    }
    
    func pause() {
        print("Pause called")
        audioManager?.pause()
        isPlaying = false
    }

    override func didMove(to view: SKView) {
        backgroundColor = .systemBackground
        view.ignoresSiblingOrder = true
        redrawAll()
    }
    
    private func redrawAll() {
        eventToNode = [:]
        keyToNode = [:]
        
        removeAllChildren()
        
        self.keyRange = computeKeyRangeFromEvents()
        let noteLines = drawPiano()
        drawEvents(
            noteLines: noteLines
        )
        // scalePianoAndEvents()
    }
    
    override func update(_ sceneTime: TimeInterval) {
        if isPlaying {
            var possibleEventsToActivateIdx = self.nextEventIdx
            let deltaTime = sceneTime - lastUpdateTime
            updateEventsToPosition(self.internalPlaybackTime + deltaTime)

            while possibleEventsToActivateIdx != nil && self.events[possibleEventsToActivateIdx!].attackTime < self.internalPlaybackTime {
                // The event was just activated - animate it!
                let event = self.events[possibleEventsToActivateIdx!]
                let eventNode = eventToNode[event]!
                let (keyType, keyNode) = keyToNode[event.note]!

                let fadeInTime = 0.01
                let fadeOutTime = 0.01
                let activeDuration = event.duration
                let changeColor = SKAction.colorize(with: eventActivationColor, colorBlendFactor: 1.0, duration: fadeInTime)
                let keepColor = SKAction.colorize(with: eventActivationColor, colorBlendFactor: 1.0, duration: activeDuration)
                
                let revertColorEvent = SKAction.colorize(with: eventColor, colorBlendFactor: 1.0, duration: fadeOutTime)
                let sequenceEvent = SKAction.sequence([changeColor, keepColor, revertColorEvent])
                eventNode.run(sequenceEvent)

                let keyColor = switch keyType {
                case .black: keyColorBlack
                case .white: keyColorWhite
                }
                let revertColorKey = SKAction.colorize(with: keyColor, colorBlendFactor: 1.0, duration: fadeOutTime)
                let sequenceKey = SKAction.sequence([changeColor, keepColor, revertColorKey])
                keyNode.run(sequenceKey)

                possibleEventsToActivateIdx! += 1
                if possibleEventsToActivateIdx! >= self.events.count {
                    possibleEventsToActivateIdx = nil
                }
            }
        }
        
        lastUpdateTime = sceneTime
    }
    
    func setPlaybackTime(_ time: TimeInterval) {
        audioManager?.setPlaybackTime(time)
        setEventsOnlyPlaybackTime(time)
    }
    
    func setEventsOnlyPlaybackTime(_ time: TimeInterval) {
        nextEventIdx = findMidiEventJustAfter(self.events, time)
        updateEventsToPosition(time)
    }
    
    private func updateEventsToPosition(_ time: TimeInterval) {
        if self.eventNode == nil {
            // Nothing to do
            return
        }
        
        let distance = (self.internalPlaybackTime - time) * timeScaleFactor
        self.eventNode!.position.x += distance
        self.internalPlaybackTime = time
        
        // It is expensive to update the playbackTime variable, as it updates the SwiftUI view
        // Therefore we only do it occationally
        let playbackTimeLack = 0.2 // seconds
        if abs(self.internalPlaybackTime - self.playbackTime) > playbackTimeLack {
            self.playbackTime = self.internalPlaybackTime
            if self.internalPlaybackTime >= audioManager!.originalAudioDuration {
                pause()
            }
        }
        
        // Update the nextEventId
        while self.nextEventIdx != nil && !self.events.isEmpty &&
                self.events[nextEventIdx!].attackTime < time {
            self.nextEventIdx! += 1
            if self.nextEventIdx! >= self.events.count {
                self.nextEventIdx = nil
            }
        }
        
        updateEventVisibility()
    }

    func noteNameFromMIDINote(_ midiNote: Int) -> String {
        let noteNames = ["A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"]
        let noteIndex = midiNote % 12
        return noteNames[noteIndex] // + " (\(midiNote))"
    }
    
    private func drawEvents(noteLines: [(CGFloat, CGFloat)]) {
        self.eventNode = SKNode()
        self.eventNode!.position.x = frame.minX + eventStartPosition
        addChild(eventNode!)

        for midiEvent in events {
            // In principle the max is not needed, but to guard against crashes we add it
            let (startY, endY) = noteLines[midiEvent.note - self.keyRange.lowerBound]
            let height = CGFloat(endY - startY)
            
            let startX = midiEvent.attackTime * timeScaleFactor
            let endX = (midiEvent.attackTime + midiEvent.duration) * timeScaleFactor
            let width = min(1000.0, CGFloat(endX - startX))

            let cornerRadius: CGFloat = height / 4
            let roundedImage = createRoundedRectImage(size: CGSize(width: width, height: height), cornerRadius: cornerRadius)
            let roundedTexture = SKTexture(image: roundedImage)
            let event = SKSpriteNode(texture: roundedTexture)
            event.colorBlendFactor = 1.0
            event.color = eventColor
            
            event.position = CGPoint(x: Double(startX) + width / 2, y: (startY + endY) / 2)
            event.zPosition = 1.0
            eventToNode.updateValue(event, forKey: midiEvent)

            // --- Add Note Name Label ---
            let noteName = noteNameFromMIDINote(midiEvent.note) // Helper function (see below)
            let labelNode = SKLabelNode(text: noteName)

            //Crucial: Font Size and Scaling.  We need to do this *before* positioning.
            labelNode.fontSize = 12 // Adjust as needed.  Start small.
            labelNode.fontName = "HelveticaNeue-Bold" // Or your preferred font
            labelNode.fontColor = .white

            //Scale the label so it fit it, accounting for the cases when there is not enough space available.
            let scaleFactor = event.size.height / labelNode.frame.size.height
            labelNode.xScale = scaleFactor
            labelNode.yScale = scaleFactor

            labelNode.position = CGPoint(x: 0, y: 0)
            labelNode.zPosition = 1.1 // Ensure label is above the event rectangle
            labelNode.verticalAlignmentMode = .center
            labelNode.horizontalAlignmentMode = .left

            event.addChild(labelNode)
        }
        
        updateEventVisibility()
    }
    
    private func updateEventVisibility() {
        let isVisible = { (eventNode: SKSpriteNode) -> Bool in
            let startX = eventNode.position.x - eventNode.size.width / 2
            let endX = eventNode.position.x + eventNode.size.width / 2
            
            let currentPosition = self.internalPlaybackTime * self.timeScaleFactor
            let lastVisiblePosition = currentPosition + self.size.width
            return endX >= currentPosition && startX <= lastVisiblePosition
        }
        
        // Detach all events that we not on the screen
        for node in self.eventNode!.children {
            if let eventNode = node as? SKSpriteNode {
                if !isVisible(eventNode) {
                    eventNode.removeFromParent()
                }
            }
        }
        
        // Walk back from maybeIdx to get the first index that is visible,
        // then walk forwards to ensure everything is dispalyed
        // The backward walking is necessary because a user may select an earlier playback time
        var onScreenIdx = if let idx = self.nextEventIdx {
            idx
        } else { self.events.count }
        while onScreenIdx > 0 && isVisible(self.eventToNode[self.events[onScreenIdx - 1]]!) {
            onScreenIdx -= 1
        }
        
        while onScreenIdx < self.events.count {
            let eventNode = self.eventToNode[self.events[onScreenIdx]]!
            // The node is already displayed
            if eventNode.parent != nil {
                onScreenIdx += 1
                continue
            }
            
            // The node should now be displayed
            if isVisible(eventNode) {
                self.eventNode!.addChild(eventNode)
                onScreenIdx += 1
                continue
            }

            break
        }
        
    }
    
    private func drawPiano() -> [(CGFloat, CGFloat)] {
        let keyMargin = 0.5
        let numWhiteKeys = countWhiteKeys(self.keyRange)
        // print("Num white keys: \(numWhiteKeys)")
        let whiteKeyHeight = (self.frame.height / CGFloat(numWhiteKeys)) - keyMargin
        let blackKeyHeight = whiteKeyHeight * 0.58

        var noteLines: [(CGFloat, CGFloat)] = [] // Start to end of key
        noteLines.reserveCapacity(self.keyRange.count)

        let spacing1 = whiteKeyHeight * 0.63
        let spacing2 = whiteKeyHeight * 0.64
        let spacing3 = whiteKeyHeight * 0.52

        let keyStartSpacing = [
            0.0,
            spacing1,
            (whiteKeyHeight + keyMargin) * 1,
            spacing1 + blackKeyHeight + spacing1,
            (whiteKeyHeight + keyMargin) * 2,
            (whiteKeyHeight + keyMargin) * 3,
            (whiteKeyHeight + keyMargin) * 3 + spacing2,
            (whiteKeyHeight + keyMargin) * 4,
            (whiteKeyHeight + keyMargin) * 3 + spacing2 + (blackKeyHeight + spacing3) * 1,
            (whiteKeyHeight + keyMargin) * 5,
            (whiteKeyHeight + keyMargin) * 3 + spacing2 + (blackKeyHeight + spacing3) * 2,
            (whiteKeyHeight + keyMargin) * 6,
            (whiteKeyHeight + keyMargin) * 7,
        ]
        
        // We start on an a node for key 0. We do some offset magic to make this work out
        let keyOffset = 9
        var yPosition = self.frame.maxY + keyStartSpacing[(keyOffset + self.keyRange.lowerBound) % 12]

        self.keysNode = SKNode()
        for keyId in self.keyRange {
            let keyIdx = (keyId + keyOffset) % 12
            let keyType = getKeyType(midiKey: keyId)
            // print("Drawing keyId: \(keyId), keyIdx: \(keyIdx), type: \(keyType)")
            let keyColor = switch keyType {
            case .black: keyColorBlack
            case .white: keyColorWhite
            }
            let keyHeight = switch keyType {
            case .black: blackKeyHeight
            case .white: whiteKeyHeight
            }
            let keyWidth = switch keyType {
            case .black: 0.63 * pianoWidth
            case .white: pianoWidth
            }
            
            let key = SKSpriteNode(color: keyColor, size: CGSize(width: keyWidth, height: keyHeight))
            key.zPosition = switch keyType {
            case .black: 4.0
            case .white: 3.0
            }
            
            let keyStart = yPosition - keyStartSpacing[keyIdx % 12]
            let keyEnd = keyStart - keyHeight
            noteLines.append((keyEnd, keyStart)) // Direction reversed because we draw in reverse
            key.position = CGPoint(x: self.frame.minX + pianoBorder1Width + pianoWidth - keyWidth / 2, y: keyStart - keyHeight / 2)
            self.keysNode!.addChild(key)
            keyToNode.updateValue((keyType, key), forKey: keyId)
            
            if keyIdx == 0 {
                // Draw a line indicating a new octave starts
                let octaveLine = SKSpriteNode(color: UIColor.systemGray5, size: CGSize(width: frame.width, height: 1.0))
                octaveLine.position = CGPoint(x: self.frame.maxX - frame.width / 2, y: yPosition)
                octaveLine.zPosition = 0.8
                addChild(octaveLine)
            }
            
            if keyIdx % 12 == 11 {
                yPosition -= keyStartSpacing[12]
            }
        }
        addChild(self.keysNode!)

        // Draw piano borders
        let borderColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        let border1 = SKSpriteNode(color: borderColor, size: CGSize(width: pianoBorder1Width, height: self.frame.height))
        border1.position = CGPoint(x: self.frame.minX + pianoBorder1Width / 2, y: self.frame.midY)
        border1.zPosition = 2.0
        addChild(border1)
        
        let border2 = SKSpriteNode(color: borderColor, size: CGSize(width: pianoBorder2Width, height: self.frame.height))
        border2.position = CGPoint(x: self.frame.minX + pianoBorder1Width + pianoWidth + pianoBorder2Width / 2, y: self.frame.midY)
        border2.zPosition = 2.0
        addChild(border2)
        
        // Draw piano background
        let pianoBackground = SKSpriteNode(color: .black, size: CGSize(width: pianoWidth, height: self.frame.height))
        pianoBackground.position = CGPoint(x: self.frame.minX + pianoBorder1Width + pianoWidth / 2, y: self.frame.midY)
        pianoBackground.zPosition = 2.0
        addChild(pianoBackground)
        
        return noteLines
    }
    
    // Scale the piano and key nodes to match the range of the keys in the music
    private func computeKeyRangeFromEvents() -> ClosedRange<Int> {
        var keyRange = 25...71
        for event in self.events {
            // Round the key range to only white keys to make the height and scalign line up
            let keyType = getKeyType(midiKey: event.note)
            let eventLowerBound = switch keyType {
            case .black: event.note - 1
            case .white: event.note
            }
            let eventUpperBound = switch keyType {
            case .black: event.note + 1
            case .white: event.note
            }
            
            keyRange = min(keyRange.lowerBound, eventLowerBound)...max(keyRange.upperBound, eventUpperBound)
        }
        print("Computed key range: \(keyRange)")
        return keyRange
    }
    
    private func countWhiteKeys(_ range: ClosedRange<Int>) -> Int {
        var count = 0
        for i in range {
            if getKeyType(midiKey: i) == PianoKeyType.white {
                count += 1
            }
        }
        return count
    }
    
    private func getKeyType(midiKey key: Int) -> PianoKeyType {
        switch key % 12 {
        case 0, 2, 3, 5, 7, 8, 10: PianoKeyType.white
        default: PianoKeyType.black
        }
    }
}
