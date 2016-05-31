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
    func processKickEvent(_ event: MIDIEventType, scene: Scene, beatNumber: Double) {
        
        if case let .noteMessage(noteMessage) = event {
            
            let camera = scene.idsToNodes["_camera1"]!
            
            if cameraBaseTranslation == nil {
                cameraBaseTranslation = camera.transform.translation
            }
            
            let animation = AnimationSystem.Animation(startBeat: beatNumber, duration: 0.08, repeatsUntil: nil, onTick: { (elapsedBeats, percentage) in
                let zOffset = -sin(percentage * M_PI) * 0.3
                camera.transform.translation = cameraBaseTranslation + (camera.transform.nodeToWorldMatrix * vec4(0, 0, Float(zOffset), 0)).xyz
            })
            AnimationSystem.addAnimation(animation)
            
        }
    }

    private var pyramidBaseScale : vec3! = nil
    func processSnareEvent(_ event: MIDIEventType, scene: Scene, beatNumber: Double) {
        
        if case let .noteMessage(noteMessage) = event {
            
            let pyramid = scene.idsToNodes["_Pyramid1"]!
            
            if pyramidBaseScale == nil {
                pyramidBaseScale = pyramid.transform.scale
            }
            
            let animation = AnimationSystem.Animation(startBeat: beatNumber, duration: 0.08, repeatsUntil: nil, onTick: { (elapsedBeats, percentage) in
                let scaleOffset = sin(percentage * M_PI) * 0.05 + 1.0
                pyramid.transform.scale = pyramidBaseScale * Float(scaleOffset)
            })
            AnimationSystem.addAnimation(animation)
            
        }
    }

#endif