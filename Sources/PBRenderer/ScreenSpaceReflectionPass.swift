//
//  ScreenSpaceReflectionPass.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 3/06/16.
//
//

import Foundation
import SGLOpenGL

final class ScreenSpaceReflectionPass {
    
    static let vertexShaderPassthrough = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "PassthroughShader.vert"))
    static let fragmentShaderHorizontalBlur = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "LinearBlurHorizontal.frag"))
    static let fragmentShaderVerticalBlur = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "LinearBlurVertical.frag"))
    
    static let horizontalBlurShader = Shader(withVertexShader: vertexShaderPassthrough, fragmentShader: fragmentShaderHorizontalBlur)
    static let verticalBlurShader = Shader(withVertexShader: vertexShaderPassthrough, fragmentShader: fragmentShaderVerticalBlur)
    
    init(pixelDimensions: Size, lightAccumulationAttachment: RenderPassColourAttachment) {
        
    }
    
    func resize(newPixelDimensions width: GLint, _ height: GLint, lightAccumulationAttachment: RenderPassColourAttachment) {
    }
    
    func renderBlur() {
        
    }
    
    func renderReflections() {
        
    }
    
    func render(camera: Camera, depthTexture: Texture) {
    
    }

    
    
}