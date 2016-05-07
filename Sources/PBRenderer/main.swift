import Foundation
import CGLFW3
import SGLOpenGL
import SGLMath
import ColladaParser

enum BasicShaderProperty : String, ShaderProperty {
    case mvp
    
    var name : String {
        return self.rawValue
    }
}

let mainWindow : Window

// The *main* function; where our program begins running
func main() {

    // Init GLFW
    glfwInit()
    // Terminate GLFW when this function ends
    defer { glfwTerminate() }
    
    // Set all the required options for GLFW
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1)
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)
    glfwWindowHint(GLFW_RESIZABLE, GL_FALSE)
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE)
    
    let mainWindow = RenderWindow(name: "PBRenderer", width: 800, height: 600)
    
//    
//    let vertices = GPUBuffer<GLfloat>(capacity: 18, data: [0.5, 0.5, 0, 0, 0, 0, 0.5, 0, 0,        0, 0, 1, 0, 0, 1, 0, 0, 1], accessFrequency: .Static, accessType: .Draw)
//    let indices = GPUBuffer<GLuint>(capacity: 3, data: [0, 1, 2], accessFrequency: .Static, accessType: .Draw)
//    
//    let positionAttribute = VertexAttribute(data: GPUBuffer<Void>(vertices), glTypeName: GL_FLOAT, componentsPerAttribute: 3, isNormalised: false, stride: 0, bufferOffsetInBytes: 0)
//    let normalAttribute = VertexAttribute(data: GPUBuffer<Void>(vertices), glTypeName: GL_FLOAT, componentsPerAttribute: 3, isNormalised: false, stride: 0, bufferOffsetInBytes: 9 * sizeof(GLfloat))
//    
//    let drawCommand = DrawCommand(data: GPUBuffer<Void>(indices), glPrimitiveType: GL_TRIANGLES, elementCount: 3, glElementType: GL_UNSIGNED_INT, bufferOffsetInBytes: 0)
//    
//    let mesh = GLMesh(drawCommand: drawCommand, attributes: [.Position: positionAttribute, .Normal: normalAttribute])
    
    
    // Game loop
    while !mainWindow.shouldClose {
        // Check if any events have been activated
        // (key pressed, mouse moved etc.) and call
        // the corresponding response functions
        glfwPollEvents()
        
        mainWindow.update()
    }
}

main()








