//
//  PianoRoll.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 28/05/2024.
//

import Foundation
import SpriteKit

enum PianoKeyType {
    case white
    case black
}

class PianoRoll: SKScene {
    
    var events: [MidiEvent] = []
    
    let pianoWidth: Double = 35.0
    let pianoBorder1Width: Double = 1.0
    let pianoBorder2Width: Double = 3.0
    
    
    let numKeys: Int = 88
    let numWhiteKeys: Int = 52

    override func didMove(to view: SKView) {
        backgroundColor = .systemBackground
        
        let noteLines = drawPiano()
        drawEvents(
            beginningX: pianoWidth + pianoBorder1Width + pianoBorder2Width,
            noteLines: noteLines
        )
    }
    
    private func drawEvents(beginningX: Double, noteLines: [(CGFloat, CGFloat)]) {
        let scaleFactor = 1
        
        let eventColor = UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
        for event in events {
            let (startY, endY) = noteLines[event.note]
            let height = CGFloat(endY - startY)
            
            let startX = event.attackTime * scaleFactor
            let endX = (event.attackTime + event.duration) * scaleFactor
            let width = CGFloat(endX - startX)
            
            let event = SKSpriteNode(color: eventColor, size: CGSize(width: width, height: height))
            event.position = CGPoint(x: beginningX + Double(startX) + width / 2, y: (startY + endY) / 2)
            addChild(event)
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
            case .black: UIColor.black
            case .white: UIColor(red: 0.99, green: 0.96, blue: 0.94, alpha: 1.0)
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
            case .black: 2.0
            case .white: 1.0
            }
            
            let keyStart = yPosition - keyStartSpacing[keyIdx % 12]
            let keyEnd = keyStart + keyHeight
            noteLines.append((keyStart, keyEnd))
            key.position = CGPoint(x: self.frame.minX + pianoBorder1Width + pianoWidth - keyWidth / 2, y: keyStart - keyHeight / 2)
            addChild(key)
            
            if keyIdx % 12 == 11 {
                yPosition -= keyStartSpacing[12]
            }
        }
        
        // Draw piano borders
        let borderColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        let border1 = SKSpriteNode(color: borderColor, size: CGSize(width: pianoBorder1Width, height: self.frame.height))
        border1.position = CGPoint(x: self.frame.minX + pianoBorder1Width / 2, y: self.frame.midY)
        addChild(border1)
        
        let border2 = SKSpriteNode(color: borderColor, size: CGSize(width: pianoBorder2Width, height: self.frame.height))
        border2.position = CGPoint(x: self.frame.minX + pianoBorder1Width + pianoWidth + pianoBorder2Width / 2, y: self.frame.midY)
        addChild(border2)
        
        return noteLines
    }
}
