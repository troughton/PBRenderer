//
//  Resources.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 19/05/16.
//
//

import Foundation

public final class Resources {
    public static func pathForResource(named name: String) -> String {
        if let pathExtension = name.components(separatedBy: ".").last {
            switch pathExtension {
            case "cl":
                return "Resources/Shaders/OpenCL/" + name
            case "glsl":
                fallthrough
            case "vert":
                fallthrough
            case "frag":
                return "Resources/Shaders/OpenGL/" + name
            default:
                break;
            }
        }
        
        return "Resources/" + name
    }
}