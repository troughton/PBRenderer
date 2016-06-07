//
//  ShaderProperties.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 15/05/16.
//
//

import Foundation


enum LightPassShaderProperty: String, ShaderProperty {
    case DepthRange = "depthRange"
    case NearPlane = "nearPlane"
    case MatrixTerms = "matrixTerms"
    
    var name : String {
        return self.rawValue
    }
}

enum CompositionPassShaderProperty: String, ShaderProperty {
    case LightAccumulationBuffer = "lightAccumulationBuffer"
    
    var name : String {
        return self.rawValue
    }
}

enum BasicShaderProperty : String, ShaderProperty {
    case ModelToClipMatrix = "modelToClipMatrix"
    case NormalModelToWorldMatrix = "normalModelToWorldMatrix"
    case CameraPositionWorld = "cameraPositionWorld"
    case ModelToWorldMatrix = "modelToWorldMatrix"
    case ModelToCameraMatrix = "modelToCameraMatrix"
    case Material
    
    var name : String {
        return self.rawValue
    }
}