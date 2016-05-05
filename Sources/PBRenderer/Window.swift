//
//  Window.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 3/05/16.
//
//

import Foundation
import CGLFW3
import SGLOpenGL
import SGLMath
import ColladaParser

class Window {
    // called whenever a key is pressed/released via GLFW
    func keyCallback(window: OpaquePointer!, key: Int32, scancode: Int32, action: Int32, mode: Int32) {
        if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
            glfwSetWindowShouldClose(window, GL_TRUE)
        }
    }
    
    
    private static var glfwWindowsToWindows = [OpaquePointer : Window]()
    
    private let _glfwWindow : OpaquePointer!
    
    typealias Size = (width: GLint, height: GLint)
    
    var dimensions : Size {
        var width : GLint = 0, height : GLint = 0
        glfwGetWindowSize(_glfwWindow, &width, &height)
        return (width, height)
    }
    
    var pixelDimensions : Size {
        var width : GLint = 0, height : GLint = 0
        glfwGetFramebufferSize(_glfwWindow, &width, &height)
        return (width, height)
    }
    
    var shouldClose : Bool {
        return glfwWindowShouldClose(_glfwWindow) != 0
    }
    
    init(name: String, width: Int, height: Int) {
        // Create a GLFWwindow object that we can use for GLFW's functions
        _glfwWindow = glfwCreateWindow(GLint(width), GLint(height), name, nil, nil)
        glfwMakeContextCurrent(_glfwWindow)
        
        guard _glfwWindow != nil else {
            fatalError("Failed to create GLFW window")
        }
        
        Window.glfwWindowsToWindows[_glfwWindow] = self
        
        // Set the required callback functions
        glfwSetKeyCallback(_glfwWindow) { (glfwWindow, key, scanCode, action, modifiers) in
            let window = Window.glfwWindowsToWindows[glfwWindow]!
            window.keyAction(key: key, scanCode: scanCode, action: action, modifiers: modifiers)
        }
    }
    
    deinit {
        glfwSetWindowShouldClose(_glfwWindow, 1)
    }
    
    final func update() {
        self.preRender()
        self.render()
        self.postRender()
        
        glfwSwapBuffers(_glfwWindow)
    }
    
    func preRender() {
        
    }
    
    func postRender() {
        
    }
    
    func render() {
        
    }
    
    func keyAction(key: Int32, scanCode: Int32, action: Int32, modifiers: Int32) {
        
    }
}

class RenderWindow : Window {
    
    var framebuffer : Framebuffer! = nil
    
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
    
    var shader : Shader! = nil
    
    var mesh : GLMesh! = nil
    
    override init(name: String, width: Int, height: Int) {
        super.init(name: name, width: width, height: height)
        
        let (pixelWidth, pixelHeight) = self.pixelDimensions
        self.framebuffer = Framebuffer.defaultFramebuffer(width: pixelWidth, height: pixelHeight)
        self.renderContextState = RenderContextState(viewport: Rectangle(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        self.renderContextState.applyState()
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_LESS
        depthState.isDepthWriteEnabled = true
        self.depthStencilState = depthState
        self.depthStencilState.applyState()
        
        self.framebuffer.colourAttachments[0]?.clearColour = vec4(0, 0, 0, 0)
        self.framebuffer.colourAttachments[0]?.loadAction = .Clear
        self.framebuffer.depthAttachment.clearDepth = 1.0
        self.framebuffer.depthAttachment.loadAction = .Clear
        
        let vertexShader = ["#version 410",
                            "layout(location = 0) in vec4 position;",
                            "layout(location = 1) in vec3 normal;",
                            "uniform mat4 mvp;",
                            "out vec3 vertexNormal;",
                            "void main() {",
                            "vertexNormal = normal;",
                            "gl_Position = mvp * position;",
                            "}"].joined(separator: "\n")
        
        let fragmentShader = ["#version 410",
                              "out vec4 outputColor;",
                              "in vec3 vertexNormal;",
                              "void main() {",
                              "outputColor = vec4((vertexNormal + 1) * 0.5, 1.0);",
                              "}"].joined(separator: "\n")
        
        self.shader = Shader(withVertexShader: vertexShader, fragmentShader: fragmentShader)
        
        let firstColourAttachment = ColourAttachment()
        self.pipelineState = PipelineState(shader: shader, colourAttachments: [firstColourAttachment])
        self.pipelineState.applyState()
        
        let collada = try! Collada(contentsOfURL: NSURL(fileURLWithPath: "/Users/Thomas/Desktop/ColladaTestSphere.dae"))
        
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
    
    override func preRender() {
        super.preRender()
        
        self.shader.useProgram()
        self.framebuffer.beginRenderPass()
    }
    
    override func render() {
        
        let modelToView = SGLMath.rotate(SGLMath.translate(mat4(1), vec3(0, 0, 5.0)), Float(glfwGetTime()), vec3(0, 1, 0))
        let viewToProj = SGLMath.perspectiveFov(Float(M_PI_4), 600, 800, 0.1, 100.0)
        let transform = viewToProj * modelToView
        
        self.pipelineState.shader.setMatrix(transform, forProperty: BasicShaderProperty.mvp)
        
        mesh.render()
    }
    
    override func postRender() {
        super.postRender()
        self.framebuffer.endRenderPass()
        self.shader.endUseProgram()
    }
    
}