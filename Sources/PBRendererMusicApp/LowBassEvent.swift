//
//  LowBassEvent.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 2/06/16.
//
//

import Foundation


#if os(OSX)
    
    import Foundation
    import PBRenderer
    import SGLMath
    
var originalSmoothness : Float! = nil
    func processLowBassEvent(_ event: MIDIEventType, scene: Scene, beatNumber: Double) {
        
        if case let .noteMessage(noteMessage) = event {
            
            let groundPlane = scene.idsToNodes["GroundPlane"]
            let material = groundPlane!.materials.values.first!
            if originalSmoothness == nil {
                originalSmoothness = material.withElementNoUpdate { return $0.smoothness }
            }
            
            let animation = AnimationSystem.Animation(startBeat: beatNumber, duration: Double(noteMessage.duration), repeatsUntil: nil, onTick: { (elapsedBeats, percentage) in
                material.withElement({ material in
                    if percentage >= 1.0 {
                        material.smoothness = originalSmoothness
                    } else {
                        material.smoothness = randomFloat() * 0.04 + 0.8
                    }

                })
            })
            AnimationSystem.addAnimation(animation)
            
        }
    }
    
#endif