//
//  ShaderProperties.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 15/05/16.
//
//

import Foundation

enum GBufferShaderProperty : String, ShaderProperty {
    case GBuffer0 = "gBuffer0Texture"
    case GBuffer1 = "gBuffer1Texture"
    case GBuffer2 = "gBuffer2Texture"
    case GBuffer3 = "gBuffer3Texture"
    case GBufferDepth = "gBufferDepthTexture"
    
    var name : String {
        return self.rawValue
    }
}

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
    case NormalModelToCameraMatrix = "normalModelToCameraMatrix"
    case ModelToCameraMatrix = "modelToCameraMatrix"
    case Material
    
    var name : String {
        return self.rawValue
    }
}