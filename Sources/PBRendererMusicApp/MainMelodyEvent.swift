//
//  MainMelodyEvent.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 2/06/16.
//
//

#if os(OSX)
    
    import Foundation
    import PBRenderer
    import SGLMath
    
    
let mainMelodyNotes : [UInt8] = [50, 52, 55, 57, 59, 62]
    func processMainMelodyEvent(_ event: MIDIEventType, scene: Scene, beatNumber: Double) {
        
        if case let .noteMessage(noteMessage) = event {
            
            let lightNumber = mainMelodyNotes.index(of: noteMessage.note)!
            
            let light = scene.namesToNodes["BackgroundAreaLight\(lightNumber + 1)"]?.lights.first
            light?.colour = .Temperature(8000)
            
            let backgroundAreaLightPlane = scene.namesToNodes["BackgroundAreaLightPlane\(lightNumber + 1)"]!
            let materialElement = backgroundAreaLightPlane.materials.values.first!
            
            let animation = AnimationSystem.Animation(startBeat: beatNumber, duration: Double(noteMessage.duration), repeatsUntil: nil, onTick: { (elapsedBeats, percentage) in
                
                materialElement.withElement({ material in
                    
                    if percentage >= 1.0 {
                        
                        material.emissive = vec4(0)
                        light?.intensity.value = 0.0
                    } else {
                        
                        material.emissive = vec4(1000)
                        light?.intensity.value = 100.0
                    }
                    
                })

            })
            AnimationSystem.addAnimation(animation)
            
        }
    }
    
#endif