//
//  DrivingChordsEvent.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 30/05/16.
//
//

import Foundation
import PBRenderer

private var lastEventBeat = 0.0

func processDrivingChordsEvent(_ event: MIDIEventType, scene: Scene, beatNumber: Double) {
    
    guard lastEventBeat != beatNumber else {
        return
    }
    defer { lastEventBeat = beatNumber }
    
    if case let .noteMessage(noteMessage) = event {
        
        
        if let pyramidNode = scene.idsToNodes["_Pyramid1"] {
            
            let animation = AnimationSystem.Animation(startBeat: beatNumber, duration: Double(noteMessage.duration), repeatsUntil: nil, onTick: { (elapsedBeats, percentage) in
                
                for materialElement in pyramidNode.materials.values {
                    materialElement.withElement({ (material) -> Void in
                        material.smoothness = Float(percentage)
                    })
                }
                
            })
            
            AnimationSystem.addAnimation(animation)
        }
        
    }
}