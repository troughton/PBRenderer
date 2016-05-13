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
    
    struct Size {
        let width: GLint
        let height: GLint
        
        init(_ width: GLint, _ height: GLint) {
            self.width = width
            self.height = height
        }
        
        var aspect : Float {
            return Float(self.width) / Float(self.height)
        }
    }
    
    var dimensions : Size {
        var width : GLint = 0, height : GLint = 0
        glfwGetWindowSize(_glfwWindow, &width, &height)
        return Size(width, height)
    }
    
    var pixelDimensions : Size {
        var width : GLint = 0, height : GLint = 0
        glfwGetFramebufferSize(_glfwWindow, &width, &height)
        return Size(width, height)
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
            let window = Window.glfwWindowsToWindows[glfwWindow!]!
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