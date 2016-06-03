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
    
//    init(pixelDimensions: Size, lightAccumulationAttachment: RenderPassColourAttachment) {
//        
//    }
//    
//    func resize(newPixelDimensions width: GLint, _ height: GLint, lightAccumulationAttachment: RenderPassColourAttachment) {
//    }
//    
//    func render(camera: Camera, depthTexture: Texture) {
//        let dfg = DFGTexture.defaultTexture //this will generate it the first time, so we need to call it outside of the render pass method.
//        
//        let materialTexture = Texture(buffer: scene.materialBuffer, internalFormat: GL_RGBA32F)
//        
//        self.gBufferPassState.renderPass { (framebuffer, shader) in
//            
//            shader.setUniform(GLint(environmentMap != nil ? 1 : 0), forProperty: GBufferShaderProperty.UseEnvironmentMap)
//            
//            let environmentMap = environmentMap ?? LDTexture.emptyTexture
//            
//            dfg.texture.bindToIndex(0)
//            defer { dfg.texture.unbindFromIndex(0) }
//            GBufferPass.dfgSampler.bindToIndex(0)
//            defer { GBufferPass.dfgSampler.unbindFromIndex(0) }
//            shader.setUniform(GLint(0), forProperty: GBufferShaderProperty.DFGTexture)
//            
//            environmentMap.diffuseTexture.bindToIndex(1)
//            defer { environmentMap.diffuseTexture.unbindFromIndex(1) }
//            GBufferPass.diffuseLDSampler.bindToIndex(1)
//            defer { GBufferPass.diffuseLDSampler.unbindFromIndex(1) }
//            shader.setUniform(GLint(1), forProperty: GBufferShaderProperty.DiffuseLDTexture)
//            
//            environmentMap.specularTexture.bindToIndex(2)
//            defer { environmentMap.specularTexture.unbindFromIndex(2) }
//            GBufferPass.specularLDSampler.bindToIndex(2)
//            defer { GBufferPass.specularLDSampler.unbindFromIndex(2) }
//            shader.setUniform(GLint(2), forProperty: GBufferShaderProperty.SpecularLDTexture)
//            shader.setUniform(GLint(environmentMap.specularTexture.descriptor.mipmapLevelCount - 1), forProperty: GBufferShaderProperty.LDMipMaxLevel)
//            
//            shader.setUniform(camera.exposure, forProperty: GBufferShaderProperty.Exposure)
//            
//            
//            materialTexture.bindToIndex(3)
//            shader.setUniform(GLint(3), forProperty: GBufferShaderProperty.Materials)
//            
//            let cameraPositionWorld = camera.sceneNode.transform.worldSpacePosition.xyz
//            shader.setUniform(cameraPositionWorld.x, cameraPositionWorld.y, cameraPositionWorld.z, forProperty: BasicShaderProperty.CameraPositionWorld)
//            
//            for node in scene.nodes {
//                self.renderNode(node, camera: camera, shader: shader)
//            }
//        }
//        
//        return (colourTextures: self.gBufferPassState.framebuffer.colourAttachments.flatMap { $0?.texture! }, depthTexture: self.gBufferPassState.framebuffer.depthAttachment.texture!)
//    }
//
    
    
}