//
//  HighMotifEvent.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 30/05/16.
//
//
#if os(OSX)


import Foundation
import PBRenderer 

func processHighMotifEvent(_ event: MIDIEventType, scene: Scene, beatNumber: Double) {
    
    if case let .noteMessage(noteMessage) = event {
            
            let lightName = highMotifNotes.index(of: Int(noteMessage.note))! + 1
            
            if let lightNode = scene.idsToNodes["PyramidGroup_PyramidSpot\(lightName)"] {
                
                let animation = AnimationSystem.Animation(startBeat: beatNumber, duration: Double(noteMessage.duration), repeatsUntil: nil, onTick: { (elapsedBeats, percentage) in
                    let oneMinusPercentage = 1 - percentage
                    lightNode.lights.forEach { $0.intensity.value = Float(oneMinusPercentage) * 16000 }
                })
                
                AnimationSystem.addAnimation(animation)
            }
    }
}

#endif