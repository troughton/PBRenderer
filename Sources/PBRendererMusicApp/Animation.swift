//
//  Animation.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 29/05/16.
//
//
#if os(OSX)


import Foundation

typealias Beat = Double

final class AnimationSystem {
    
    private static var animations = [Animation]()
    private static var animationsToRemove = [Int]()
    
    typealias AnimationTickFunction = (elapsedBeats: Beat, percentage: Double) -> ()
    
    struct Animation {
        let startBeat : Beat
        let duration : Beat
        let repeatsUntil: Beat?
        let onTick: AnimationTickFunction
    }
    
    static func addAnimation(_ animation: Animation) {
        self.animations.append(animation)
    }
    
    static func tick(currentBeat: Beat) {
        
        for (i, animation) in self.animations.enumerated() {
            let animationEndTime = animation.repeatsUntil ?? animation.startBeat + animation.duration
            if currentBeat > animationEndTime {
                let elapsedBeats = currentBeat - animation.startBeat
                if elapsedBeats >= 0 {
                    animation.onTick(elapsedBeats: elapsedBeats, percentage: 1.0)
                }
                
                animationsToRemove.append(i)
            } else {
                let elapsedBeats = currentBeat - animation.startBeat
                if elapsedBeats >= 0 {
                    let percentage = fmod(elapsedBeats, animation.duration) / animation.duration
                    animation.onTick(elapsedBeats: elapsedBeats, percentage: percentage)
                }
            }
        }
        
        for (i, animationIndex) in animationsToRemove.enumerated() {
            self.animations.remove(at: animationIndex - i)
        }
        
        self.animationsToRemove.removeAll(keepingCapacity: true)
    }
}

#endif