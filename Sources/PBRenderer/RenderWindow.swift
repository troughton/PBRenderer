//
//  RenderWindow.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 12/05/16.
//
//

import Foundation
import SGLOpenGL
import SGLMath
import CGLFW3
import ColladaParser
import CPBRendererLibs

final class RenderWindow : Window {
    
    var forwardPassState : PipelineState! = nil
    
    var scene : Scene! = nil
    
    var projectionMatrix: mat4 = SGLMath.perspectiveFov(Float(M_PI_4), 600, 800, 0.1, 100.0)
    var cameraNear: Float = 0.1
    
    var envMapTexture : Texture! = nil
    
    override init(name: String, width: Int, height: Int) {
        
        super.init(name: name, width: width, height: height)
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_LESS
        depthState.isDepthWriteEnabled = true
        
        let pixelDimensions = self.pixelDimensions
        
        let lightAccumulationBuffer = Framebuffer.defaultFramebuffer(width: pixelDimensions.width, height: pixelDimensions.height)
        
        lightAccumulationBuffer.colourAttachments[0]?.clearColour = vec4(0, 0, 0, 0)
        lightAccumulationBuffer.colourAttachments[0]?.loadAction = .Clear
        lightAccumulationBuffer.depthAttachment.clearDepth = 1.0
        lightAccumulationBuffer.depthAttachment.loadAction = .Clear
        
        let lightPassVertex = try! Shader.shaderTextByExpandingIncludes(fromFile: "ForwardPass.vert")
        let lightPassFragment = try! Shader.shaderTextByExpandingIncludes(fromFile: "ForwardPass.frag")
        
        let forwardPassShader = Shader(withVertexShader: lightPassVertex, fragmentShader: lightPassFragment)
        
        self.forwardPassState = PipelineState(viewport: Rectangle(x: 0, y: 0, width: pixelDimensions.width, height: pixelDimensions.height), framebuffer: lightAccumulationBuffer, shader: forwardPassShader, depthStencilState: depthState)
        
        guard let collada = Collada(contentsOfFile: Process.arguments[1]) else { fatalError("Couldn't load Collada file") }
        
        self.scene = Scene(fromCollada: collada)
        
        var imageX = Int32(0)
        var imageY = Int32(0)
        var numComponents = Int32(0)
        let hdrEnvMap = stbi_loadf("stpeters_probe.hdr", &imageX, &imageY, &numComponents, 0)
        
        let envMapTextureDescriptor = TextureDescriptor(texture2DWithPixelFormat: numComponents == 3 ? GL_RGB16F : GL_RGBA16F, width: Int(imageX), height: Int(imageY), mipmapped: true)
        self.envMapTexture = Texture(textureWithDescriptor: envMapTextureDescriptor, type: GL_FLOAT, format: numComponents == 3 ? GL_RGB : GL_RGBA, data: hdrEnvMap)
        self.envMapTexture.generateMipmaps()
        
        stbi_image_free(hdrEnvMap)
    }
    
    override func framebufferDidResize(width: Int32, height: Int32) {
        self.forwardPassState.viewport = Rectangle(x: 0, y: 0, width: width, height: height)
    }
    
    override func preRender() {
        super.preRender()
    }
    
    func renderNode(_ node: SceneNode, worldToCameraMatrix: mat4, cameraToClipMatrix: mat4, shader: Shader) {
        let modelToCamera = worldToCameraMatrix * node.transform.nodeToWorldMatrix
        let modelToClip = cameraToClipMatrix * modelToCamera
        let normalTransform = node.transform.worldToNodeMatrix.upperLeft.transpose
        
        shader.setMatrix(modelToCamera, forProperty: BasicShaderProperty.ModelToCameraMatrix)
        shader.setMatrix(modelToClip, forProperty: BasicShaderProperty.mvp)
        shader.setMatrix(normalTransform, forProperty: BasicShaderProperty.NormalModelToCameraMatrix)
        
        let materialBlockIndex = 0
        
        shader.setUniformBlockBindingPoints(forProperties: [BasicShaderProperty.Material])
        
        for mesh in node.meshes {
            if let materialName = mesh.materialName, let material = node.materials[materialName] {
                material.bindToUniformBlockIndex(materialBlockIndex)
            }
            
            mesh.render()
        }
        
        for child in node.children {
            self.renderNode(child, worldToCameraMatrix: worldToCameraMatrix, cameraToClipMatrix: cameraToClipMatrix, shader: shader)
        }
    }
    
    override func render() {
        
        self.forwardPassState.renderPass { (framebuffer, shader) in
            let camera = self.scene.flattenedScene.flatMap { $0.cameras.first }.first!
            
            let worldToCamera = camera.sceneNode.transform.worldToNodeMatrix
            let cameraToClip = camera.projectionMatrix
            
            envMapTexture.bindToIndex(0)
            shader.setUniform(GLint(0), forProperty: StringShaderProperty("dfgTexture"))
            
            for node in scene.nodes {
                self.renderNode(node, worldToCameraMatrix: worldToCamera, cameraToClipMatrix: cameraToClip, shader: shader)
            }
        }
    }
    
    override func postRender() {
        super.postRender()
    }
    
}