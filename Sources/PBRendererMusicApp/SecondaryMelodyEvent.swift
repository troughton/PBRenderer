//
//  SecondaryMelodyEvent.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 10/06/16.
//
//

#if os(OSX)
    
    import Foundation
    import PBRenderer
    import SGLMath
    
    
let secondaryMelodyNotes : [UInt8] = [62, 64, 67, 69, 71, 74, 76]
    func processSecondaryMelodyEvent(_ event: MIDIEventType, scene: Scene, beatNumber: Double) {

        if case let .noteMessage(noteMessage) = event {
            let lightNumber = secondaryMelodyNotes.index(of: noteMessage.note)!
            
            let light = scene.idsToNodes["PyramidGroup_SecondMelodyStripLight\(7 - lightNumber)"]?.lights.first
            light?.colour = .temperature(9600)
            
            let animation = AnimationSystem.Animation(startBeat: beatNumber, duration: Double(noteMessage.duration * 0.8), repeatsUntil: nil, onTick: { (elapsedBeats, percentage) in
                
                if percentage >= 1.0 {
                    light?.intensity.value = 0.0
                } else {
                    light?.intensity.value = 400.0
                }

                
            })
            AnimationSystem.addAnimation(animation)
            
        }
    }
    
#endif
