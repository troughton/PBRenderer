//
//  MIDIEventType.swift
//  Project2Visuals
//
//  Created by Thomas Roughton on 18/05/16.
//  Copyright © 2016 Thomas Roughton. All rights reserved.
//

#if os(OSX)

import Foundation
import AudioToolbox

enum MIDIEventType {
    case extendedNote(ExtendedNoteOnEvent)
    case extendedTempo(ExtendedTempoEvent)
    case extendedControl(ExtendedControlEvent)
    case user(MusicEventUserData)
    case meta(MIDIMetaEvent)
    case noteMessage(MIDINoteMessage)
    case channelMessage(MIDIChannelMessage)
    case rawData(MIDIRawData)
    case parameter(ParameterEvent)
    case auPreset(AUPresetEvent)
    
    init?(_ eventType: MusicEventType, data: UnsafeRawPointer?) {
        guard let data = data else { return nil }
        switch eventType {
        case kMusicEventType_ExtendedNote:
            self = .extendedNote(data.assumingMemoryBound(to: ExtendedNoteOnEvent.self).pointee)
        case MusicEventType(kMusicEventType_ExtendedControl):
            self = .extendedControl(data.assumingMemoryBound(to: ExtendedControlEvent.self).pointee)
        case kMusicEventType_ExtendedTempo:
            self = .extendedTempo(data.assumingMemoryBound(to: ExtendedTempoEvent.self).pointee)
        case kMusicEventType_User:
            self = .user(data.assumingMemoryBound(to: MusicEventUserData.self).pointee)
        case kMusicEventType_Meta:
            self = .meta(data.assumingMemoryBound(to: MIDIMetaEvent.self).pointee)
        case kMusicEventType_MIDINoteMessage:
            self = .noteMessage(data.assumingMemoryBound(to: MIDINoteMessage.self).pointee)
        case kMusicEventType_MIDIChannelMessage:
            self = .channelMessage(data.assumingMemoryBound(to: MIDIChannelMessage.self).pointee)
        case kMusicEventType_MIDIRawData:
            self = .rawData(data.assumingMemoryBound(to: MIDIRawData.self).pointee)
        case kMusicEventType_Parameter:
            self = .parameter(data.assumingMemoryBound(to: ParameterEvent.self).pointee)
        case kMusicEventType_AUPreset:
            self = .auPreset(data.assumingMemoryBound(to: AUPresetEvent.self).pointee)
        default:
            return nil
        }
    }
}

#endif
