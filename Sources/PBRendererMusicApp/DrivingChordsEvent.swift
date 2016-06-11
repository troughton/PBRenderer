//
//  DrivingChordsEvent.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 30/05/16.
//
//

#if os(OSX)

import Foundation
import PBRenderer

private var lastEventBeat = 0.0

func processDrivingChordsEvent(_ event: MIDIEventType, scene: Scene, beatNumber: Double) {
    
    guard lastEventBeat != beatNumber else {
        return
    }
    defer { lastEventBeat = beatNumber }
    
    if case let .noteMessage(noteMessage) = event {
        
        
        let pyramidNode = scene.idsToNodes["PyramidGroup_Pyramid1"]!
        
        let topLightMinIntensity = 0.5
        let topLightMaxIntensity = 1040.0
        
        let smoothnessMin = 0.3
        let smoothnessMax = 0.9
        
        if let pyramidTopLight = scene.idsToNodes["PyramidTopLight"] {
            
            let decreasing = fmod(beatNumber, 8.0) > 3.0
            
            let animation = AnimationSystem.Animation(startBeat: beatNumber, duration: Double(noteMessage.duration), repeatsUntil: nil, onTick: { (elapsedBeats, percentage) in
                
                let from = decreasing ? topLightMaxIntensity : topLightMinIntensity
                let to = decreasing ? topLightMinIntensity : topLightMaxIntensity
                
                let light = pyramidTopLight.lights.first
                light?.intensity.value = Float(lerp(from: from, to: to, percentage: percentage))
                
                
                let fromSmoothness = decreasing ? smoothnessMax : smoothnessMin
                let toSmoothness = decreasing ? smoothnessMin : smoothnessMax
                
                for materialElement in pyramidNode.materials.values {
                    materialElement.withElement({ (material) -> Void in
                        material.smoothness = Float(lerp(from: fromSmoothness, to: toSmoothness, percentage: percentage))
                    })
                }
            })
            
            AnimationSystem.addAnimation(animation)
        }
        
    }
}

#endif