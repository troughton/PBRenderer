//
//  KickSnareEvent.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 30/05/16.
//
//

#if os(OSX)
    
    import Foundation
    import PBRenderer
    import SGLMath
    
private var cameraBaseTranslation : vec3! = nil
    func processKickEvent(_ event: MIDIEventType, scene: Scene, beatNumber: Double, strength: Double = 1.0) {
        
        if case let .noteMessage(noteMessage) = event {
            
            let camera = scene.namesToNodes["camera1"]!
            
            if cameraBaseTranslation == nil {
                cameraBaseTranslation = camera.transform.translation
            }
            
            let animation = AnimationSystem.Animation(startBeat: beatNumber, duration: 0.08, repeatsUntil: nil, onTick: { (elapsedBeats, percentage) in
                let zOffset = -sin(percentage * M_PI) * 0.3 * strength
                camera.transform.translation = cameraBaseTranslation + (camera.transform.nodeToWorldMatrix * vec4(0, 0, Float(zOffset), 0)).xyz
            })
            AnimationSystem.addAnimation(animation)
            
        }
    }

    private var pyramidBaseScale : vec3! = nil
    func processSnareEvent(_ event: MIDIEventType, scene: Scene, beatNumber: Double, strength: Double = 1.0) {
        
        if case let .noteMessage(noteMessage) = event {
            
            
            let pyramid = scene.namesToNodes["Pyramid1"]!
            
            if pyramidBaseScale == nil {
                pyramidBaseScale = pyramid.transform.scale
            }
            
            let animation = AnimationSystem.Animation(startBeat: beatNumber, duration: 0.08, repeatsUntil: nil, onTick: { (elapsedBeats, percentage) in
                let scaleOffset = sin(percentage * M_PI) * 0.05 * strength + 1.0
                pyramid.transform.scale = pyramidBaseScale * Float(scaleOffset)
            })
            AnimationSystem.addAnimation(animation)
            
        }
    }
    
    func processDrumEvent(_ event: MIDIEventType, scene: Scene, beatNumber: Double) {
     
        if case let .noteMessage(noteMessage) = event {
            if noteMessage.note == 36 {
                processKickEvent(event, scene: scene, beatNumber: beatNumber, strength: 0.1)
            } else if noteMessage.note == 38 {
                processSnareEvent(event, scene: scene, beatNumber: beatNumber, strength: 0.1)
            }
        }
    }

#endif