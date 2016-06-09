//
//  ShadowMapPass.swift
//  PBRenderer
//
//  Created by Joseph Bennett on 8/06/16.
//
//

import Foundation
import SGLOpenGL
import SGLMath

final class ShadowMapPass {
    static let defaultShadowMapSize = Size(4096, 4096)
    
    static let vertexShader = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "PassthroughPosition.vert"))
    static let fragmentShader = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "PassthroughPosition.frag"))
    
    static let shadowMapShader = Shader(withVertexShader: vertexShader, fragmentShader: fragmentShader)

    var pipelineState : PipelineState
    
    init(shadowMapSize: Size = ShadowMapPass.defaultShadowMapSize) {
        let framebuffer = ShadowMapPass.shadowMapFramebuffer(width: shadowMapSize.width, height: shadowMapSize.height)
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_LESS
        depthState.isDepthWriteEnabled = true
        
        self.pipelineState = PipelineState(viewport: Rectangle(x: 0, y: 0, width: shadowMapSize.width, height: shadowMapSize.height),
                                           framebuffer: framebuffer,
                                           shader: ShadowMapPass.shadowMapShader,
                                           depthStencilState: depthState)
    }
    
    class func shadowMapFramebuffer(width: GLint, height: GLint) -> Framebuffer {
        let shadowMapArrayTextureDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH_COMPONENT32F, width: Int(width), height: Int(height), mipmapped: false)
        let shadowMapTexture = Texture(textureWithDescriptor: shadowMapArrayTextureDescriptor)
        
        let depthAttachment : RenderPassDepthAttachment = {
            var attachment = RenderPassDepthAttachment(clearDepth: 1.0)
            attachment.texture = shadowMapTexture
            attachment.loadAction = .Clear
            
            return attachment
        }()
        
        let framebuffer = Framebuffer(width: width, height: height, colourAttachments: [], depthAttachment: depthAttachment, stencilAttachment: nil)
        
        return framebuffer
    }
    
    static let lightToClip = SGLMath.ortho(Float(-80), 80, -80, 80, 0.1, 100.0);
    
    func performPass(scene: Scene) -> (Texture, mat4) {
        var worldToLightClipMatrix : mat4? = nil
        
        let lights = scene.lights
        
        lights.enumerated().forEach { (index, light) in            
            pipelineState.renderPass { (framebuffer, shader) in
                    light.shadowMapArrayIndex = index

                    let worldToLight = light.sceneNode.transform.worldToNodeMatrix
                    
                    let frustum = Frustum(worldToCameraMatrix: worldToLight, projectionMatrix: ShadowMapPass.lightToClip)
                    let worldToLightClip = ShadowMapPass.lightToClip * worldToLight
                    worldToLightClipMatrix = worldToLightClip
                
                    recurseTree(node: scene.octree, frustum: frustum, worldToLightClip: worldToLightClip, light: light, shader: shader)
                }
        }
        
        let shadowMapDepthTexture = pipelineState.framebuffer.depthAttachment.texture
        
        return (shadowMapDepthTexture!, worldToLightClipMatrix!)
    }
    
    func renderNode(_ node: SceneNode, worldToLightClip : mat4, shader: Shader) {
        let modelToClip = worldToLightClip * node.transform.nodeToWorldMatrix
        
        shader.setMatrix(modelToClip, forProperty: BasicShaderProperty.ModelToClipMatrix)
        
        node.meshes.0.forEach { mesh in
            mesh.render()
        }
    }
    
    private func recurseTree(node: OctreeNode<SceneNode>, frustum: Frustum, worldToLightClip: mat4, light: Light, shader: Shader) {
        if !frustum.containsBox(node.boundingVolume) {
            return
        }
        
        
        for node in node.values where !node.meshes.0.isEmpty {
            self.renderNode(node, worldToLightClip: worldToLightClip, shader: shader)
        }
        
        for i in 0..<Extent.LastElement.rawValue {
            if let child = node[Extent(rawValue: i)!] {
                recurseTree(node: child, frustum: frustum, worldToLightClip: worldToLightClip, light: light, shader: shader)
            }
        }
    }
}