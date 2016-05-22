//
//  Song.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 22/05/16.
//
//

import Foundation
import AudioToolbox
import AVFoundation

protocol CGetterObject {
    func get<T>(_ function: (inSequence: Self, out: UnsafeMutablePointer<T>) -> OSStatus) -> T
    func get<T, U>(_ u: U, _ function: (inSequence: Self, arg: U, out: UnsafeMutablePointer<T>) -> OSStatus) -> T
}

extension CGetterObject {
    func get<T>(_ function: (inSequence: Self, out: UnsafeMutablePointer<T>) -> OSStatus) -> T {
        var result = UnsafeMutablePointer<T>(allocatingCapacity: 1)
        defer {
            result.deinitialize()
            result.deallocateCapacity(1)
        }
        let _ = function(inSequence: self, out: result)
        return result.pointee
    }
    
    func get<T, U>(_ u: U, _ function: (inSequence: Self, arg: U, out: UnsafeMutablePointer<T>) -> OSStatus) -> T {
        var result = UnsafeMutablePointer<T>(allocatingCapacity: 1)
        defer {
            result.deinitialize()
            result.deallocateCapacity(1)
        }
        let _ = function(inSequence: self, arg: u, out: result)
        return result.pointee
    }
    
}

extension MusicSequence : CGetterObject {}


protocol SongDelegate : class {
    func processEvent(_ event: MIDIEventType, onTrack track: Int, beatNumber: Double)
}

enum SongError : ErrorProtocol {
    case SequenceCreationError
}

final class Song : NSObject, AVAudioPlayerDelegate {
    let audioPlayer : AVAudioPlayer
    let musicSequence : MusicSequence
    weak var delegate : SongDelegate? = nil
    private(set) var isPlaying = false
    
    let iterators : [MusicEventIterator]
    
    init(audioFilePath: String, midiFilePath: String) throws {
        
        var musicSequenceOpt : MusicSequence? = nil
        NewMusicSequence(&musicSequenceOpt)
        guard let sequence = musicSequenceOpt else {
            throw SongError.SequenceCreationError
        }
        self.musicSequence = sequence
        MusicSequenceFileLoad(self.musicSequence, NSURL(fileURLWithPath: midiFilePath), .midiType, [])
        
        let trackCount = musicSequence.get(MusicSequenceGetTrackCount)
        self.iterators = (0..<trackCount).flatMap { sequence.get($0, MusicSequenceGetIndTrack) }.map { track in
            return track.get(NewMusicEventIterator)!
        }
        
        self.audioPlayer = try AVAudioPlayer(contentsOf: NSURL(fileURLWithPath: audioFilePath))
        
        self.audioPlayer.prepareToPlay()
        
        super.init()
        self.audioPlayer.delegate = self

    }
    
    var beatNumber : Double {
        let currentTime = self.audioPlayer.currentTime
        return currentTime * 128.0/60.0  // self.musicSequence.get(currentTime, MusicSequenceGetBeatsForSeconds)
    }
    
    func update() {
        let currentBeat = self.beatNumber
        
        for (i, iterator) in iterators.enumerated() {
            while iterator.get(MusicEventIteratorHasCurrentEvent) {
                var timestamp = MusicTimeStamp(0)
                var eventType = MusicEventType(0)
                var eventData : UnsafePointer<Void>? = nil
                var eventDataSize = UInt32(0)
                
                MusicEventIteratorGetEventInfo(iterator, &timestamp, &eventType, &eventData, &eventDataSize)
                
                guard let event = MIDIEventType(eventType, data: eventData) else { MusicEventIteratorNextEvent(iterator); continue }
                
                if currentBeat >= timestamp {
                    self.delegate?.processEvent(event, onTrack: i, beatNumber: timestamp)
                    MusicEventIteratorNextEvent(iterator)
                } else {
                    break
                }
            }
        }
        
       
    }
    
    func play() {
        self.isPlaying = true
        self.audioPlayer.play()
    }
    
}