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

class RenderWindow : Window {
    
    var lightAccumulationBuffer : Framebuffer! = nil
    var gBuffer : Framebuffer! = nil
    
    var renderContextState : RenderContextState! = nil {
        didSet {
            renderContextState?.applyState()
        }
    }
    var pipelineState : PipelineState! = nil {
        didSet {
            pipelineState?.applyState()
        }
    }
    var depthStencilState : DepthStencilState! = nil {
        didSet {
            depthStencilState?.applyState()
        }
    }
    
    var geometryShader : Shader! = nil
    var lightPassShader : Shader! = nil
    
    var mesh : GLMesh! = nil
    
    override init(name: String, width: Int, height: Int) {
        super.init(name: name, width: width, height: height)
        
        let (pixelWidth, pixelHeight) = self.pixelDimensions
        self.lightAccumulationBuffer = Framebuffer.defaultFramebuffer(width: pixelWidth, height: pixelHeight)
        self.renderContextState = RenderContextState(viewport: Rectangle(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        self.renderContextState.applyState()
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_LESS
        depthState.isDepthWriteEnabled = true
        self.depthStencilState = depthState
        self.depthStencilState.applyState()
        
        self.lightAccumulationBuffer.colourAttachments[0]?.clearColour = vec4(0, 0, 0, 0)
        self.lightAccumulationBuffer.colourAttachments[0]?.loadAction = .Clear
        self.lightAccumulationBuffer.depthAttachment.clearDepth = 1.0
        self.lightAccumulationBuffer.depthAttachment.loadAction = .Clear
        
        self.setupGBuffer()
        
        let geometryPassVertex = try! Shader.shaderTextByExpandingIncludes(fromFile: "GeometryPass.vert")
        let geometryPassFragment = try! Shader.shaderTextByExpandingIncludes(fromFile: "GeometryPass.frag")
        
        self.geometryShader = Shader(withVertexShader: geometryPassVertex, fragmentShader: geometryPassFragment)
        
        let lightPassVertex = try! Shader.shaderTextByExpandingIncludes(fromFile: "LightPass.vert")
        let lightPassFragment = try! Shader.shaderTextByExpandingIncludes(fromFile: "LightPass.frag")
        
        self.lightPassShader = Shader(withVertexShader: lightPassVertex, fragmentShader: lightPassFragment)
        
        let firstColourAttachment = ColourAttachment()
        self.pipelineState = PipelineState(colourAttachments: [firstColourAttachment])
        self.pipelineState.applyState()
        
        guard let collada = Collada(contentsOfFile: Process.arguments[1]) else { fatalError("Couldn't load Collada file") }
        
        var mesh : GLMesh! = nil
        
        for geometryLibrary in collada.libraryGeometries {
            switch geometryLibrary.geometry.first!.choice0 {
            case let .mesh(colladaMesh):
                mesh = GLMesh.meshesFromCollada(colladaMesh, root: collada).first!
            default:
                break
            }
        }
        self.mesh = mesh
    }
    
    func setupGBuffer() {
        let (pixelWidth, pixelHeight) = self.pixelDimensions
        
        let descriptor = TextureDescriptor(texture2DWithPixelFormat: GL_RGBA, width: Int(pixelWidth), height: Int(pixelHeight), mipmapped: false)
        
        let colourTexture = Texture(textureWithDescriptor: descriptor, data: nil as [Void]?)
        
        var colourAttachment = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
        colourAttachment.texture = colourTexture
        colourAttachment.loadAction = .Clear
        
        let depthDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH24_STENCIL8, width: Int(pixelWidth), height: Int(pixelHeight), mipmapped: false)
        let depthTexture = Texture(textureWithDescriptor: depthDescriptor, format: GL_DEPTH_STENCIL, type: GL_UNSIGNED_INT_24_8, data: nil as [Void]?)
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.loadAction = .Clear
        depthAttachment.texture = depthTexture
        
        self.gBuffer = Framebuffer(width: pixelWidth, height: pixelHeight, colourAttachments: [colourAttachment], depthAttachment: depthAttachment, stencilAttachment: nil)
    }
    
    override func preRender() {
        super.preRender()
    }
    
    override func render() {
        
        self.gBuffer.renderPass {
            self.geometryShader.withProgram { shader in
                let modelToView = SGLMath.rotate(SGLMath.translate(mat4(1), vec3(0, 0, 5.0)), Float(glfwGetTime()), vec3(0, 1, 0))
                let viewToProj = SGLMath.perspectiveFov(Float(M_PI_4), 600, 800, 0.1, 100.0)
                let transform = viewToProj * modelToView
                
                shader.setMatrix(transform, forProperty: BasicShaderProperty.mvp)
                
                mesh.render()
            }
        }
        
        self.lightAccumulationBuffer.renderPass {
            self.lightPassShader.withProgram { shader in
                GLMesh.fullScreenQuad.render()
            }
            
        }
    }
    
    override func postRender() {
        super.postRender()
    }
    
}