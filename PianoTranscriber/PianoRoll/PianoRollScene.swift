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

class PianoRoll: SKScene, ObservableObject {
    
    private var audioManager: AudioManager?
    
    private var events: [MidiEvent] = []
    private var eventToNode: [MidiEvent:SKSpriteNode] = [:]
    private var keyToNode: [Int:(PianoKeyType, SKSpriteNode)] = [:]
    private var nextEventIdx: Int? = 0
    
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isAtBeginning: Bool = true
    
    let pianoWidth: Double = 35.0
    let pianoBorder1Width: Double = 1.0
    let pianoBorder2Width: Double = 3.0
    private lazy var eventStartPosition: Double = pianoWidth + pianoBorder1Width + pianoBorder2Width
    
    let numKeys: Int = 88
    let numWhiteKeys: Int = 52
    
    private var playbackTime: Double = 0
    private var lastUpdateTime: TimeInterval = 0
    private var eventNode: SKNode? = nil
    
    let timeScaleFactor = 400.0 // (x units / second)
    
    let eventColor: UIColor = UIColor(red: 0.2, green: 0.2, blue: 1.0, alpha: 1.0)
    let keyColorWhite: UIColor = UIColor(red: 0.99, green: 0.96, blue: 0.94, alpha: 1.0)
    let keyColorBlack: UIColor = .black
    
    func setup(_ events: [MidiEvent], _ audioFileUrl: URL, _ audioManager: AudioManager) throws {
        self.events = events
        self.audioManager = audioManager
        self.audioManager?.stageEvents(events: events, originalAudioFileUrl: audioFileUrl)
    }
    
    func play() {
        print("Playing at position \(playbackTime)")
        isAtBeginning = false
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
        audioManager?.pause()
        isPlaying = false
    }

    override func didMove(to view: SKView) {
        backgroundColor = .systemBackground
        view.ignoresSiblingOrder = true

        let noteLines = drawPiano()
        drawEvents(
            noteLines: noteLines
        )
    }
    
    override func update(_ sceneTime: TimeInterval) {
        if isPlaying {
            var possibleEventsToActivateIdx = self.nextEventIdx
            let deltaTime = sceneTime - lastUpdateTime
            updateEventsToPosition(self.playbackTime + deltaTime)

            while possibleEventsToActivateIdx != nil && self.events[possibleEventsToActivateIdx!].attackTime < self.playbackTime {
                // The event was just activated - animate it!
                let event = self.events[possibleEventsToActivateIdx!]
                let eventNode = eventToNode[event]!
                let (keyType, keyNode) = keyToNode[event.note]!

                let fadeInTime = 0.01
                let fadeOutTime = 0.1
                let activeDuration = event.duration
                let changeColor = SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: fadeInTime)
                let keepColor = SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: activeDuration)
                
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
        isAtBeginning = time == 0.0
        audioManager?.setPlaybackTime(time)
        nextEventIdx = findMidiEventJustAfter(self.events, time)
        updateEventsToPosition(time)
    }
    
    private func updateEventsToPosition(_ time: TimeInterval) {
        let distance = (self.playbackTime - time) * timeScaleFactor
        self.eventNode!.position.x += distance
        self.playbackTime = time
        
        // Update the nextEventId
        while self.nextEventIdx != nil &&
                self.events[nextEventIdx!].attackTime < time {
            self.nextEventIdx! += 1
            if self.nextEventIdx! >= self.events.count {
                self.nextEventIdx = nil
            }
        }
        
        updateEventVisibility()
    }
    
    private func drawEvents(noteLines: [(CGFloat, CGFloat)]) {
        self.eventNode = SKNode()
        self.eventNode!.position.x = frame.minX + eventStartPosition
        addChild(eventNode!)

        for midiEvent in events {
            let (startY, endY) = noteLines[midiEvent.note]
            let height = CGFloat(endY - startY)
            
            let startX = midiEvent.attackTime * timeScaleFactor
            let endX = (midiEvent.attackTime + midiEvent.duration) * timeScaleFactor
            let width = CGFloat(endX - startX)
            
            let event = SKSpriteNode(color: eventColor, size: CGSize(width: width, height: height))
            event.position = CGPoint(x: Double(startX) + width / 2, y: (startY + endY) / 2)
            event.zPosition = 1.0
            eventToNode.updateValue(event, forKey: midiEvent)
        }
        
        updateEventVisibility()
    }
    
    private func updateEventVisibility() {
        let isVisible = { (eventNode: SKSpriteNode) -> Bool in
            let startX = eventNode.position.x - eventNode.size.width / 2
            let endX = eventNode.position.x + eventNode.size.width / 2
            
            let currentPosition = self.playbackTime * self.timeScaleFactor
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
        
        // Show all events from maybeIdx until they are off-screen
        var onScreenIdx = if let idx = self.nextEventIdx {
            idx
        } else { self.events.count }
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
        let whiteKeyHeight = (self.frame.height / CGFloat(numWhiteKeys)) - keyMargin
        let blackKeyHeight = whiteKeyHeight * 0.496
        
        var noteLines: [(CGFloat, CGFloat)] = [] // Start to end of key
        noteLines.reserveCapacity(numKeys)
        
        let spacing1 = whiteKeyHeight * 0.63
        let spacing2 = whiteKeyHeight * 0.72
        let spacing3 = whiteKeyHeight * 0.64
        
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
        var yPosition = self.frame.maxY + keyStartSpacing[keyOffset]

        for keyId in 0..<numKeys {
            let keyIdx = (keyId + keyOffset) % 12
            let keyType = switch keyIdx % 12 {
            case 0, 2, 4, 5, 7, 9, 11: PianoKeyType.white
            default: PianoKeyType.black
            }
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
            addChild(key)
            keyToNode.updateValue((keyType, key), forKey: keyId)
            
            if keyIdx % 12 == 11 {
                yPosition -= keyStartSpacing[12]
            }
        }
        
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
}
