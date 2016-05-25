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
    
    init?(_ eventType: MusicEventType, data: UnsafePointer<Void>?) {
        guard let data = data else { return nil }
        switch eventType {
        case kMusicEventType_ExtendedNote:
            self = .extendedNote(UnsafePointer<ExtendedNoteOnEvent>(data).pointee)
        case MusicEventType(kMusicEventType_ExtendedControl):
            self = .extendedControl(UnsafePointer<ExtendedControlEvent>(data).pointee)
        case kMusicEventType_ExtendedTempo:
            self = .extendedTempo(UnsafePointer<ExtendedTempoEvent>(data).pointee)
        case kMusicEventType_User:
            self = .user(UnsafePointer<MusicEventUserData>(data).pointee)
        case kMusicEventType_Meta:
            self = .meta(UnsafePointer<MIDIMetaEvent>(data).pointee)
        case kMusicEventType_MIDINoteMessage:
            self = .noteMessage(UnsafePointer<MIDINoteMessage>(data).pointee)
        case kMusicEventType_MIDIChannelMessage:
            self = .channelMessage(UnsafePointer<MIDIChannelMessage>(data).pointee)
        case kMusicEventType_MIDIRawData:
            self = .rawData(UnsafePointer<MIDIRawData>(data).pointee)
        case kMusicEventType_Parameter:
            self = .parameter(UnsafePointer<ParameterEvent>(data).pointee)
        case kMusicEventType_AUPreset:
            self = .auPreset(UnsafePointer<AUPresetEvent>(data).pointee)
        default:
            return nil
        }
    }
}

#endif