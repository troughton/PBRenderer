import Foundation
import CGLFW3
import SGLOpenGL
import SGLMath
import ColladaParser

// Window dimensions
let WIDTH:GLsizei = 800, HEIGHT:GLsizei = 600

enum BasicShaderProperty : String, ShaderProperty {
    case mvp
    
    var name : String {
        return self.rawValue
    }
}

// The *main* function; where our program begins running
func main()
{
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
    
    // Create a GLFWwindow object that we can use for GLFW's functions
    let window = glfwCreateWindow(WIDTH, HEIGHT, "PBRenderer", nil, nil)
    glfwMakeContextCurrent(window)
    guard window != nil else
    {
        print("Failed to create GLFW window")
        return
    }
    
    // Set the required callback functions
    glfwSetKeyCallback(window, keyCallback)
    
    var frameBufferWidth : GLint = 0, framebufferHeight : GLint = 0
    glfwGetFramebufferSize(window, &frameBufferWidth, &framebufferHeight)
    
    // Define the viewport dimensions
    glViewport(x: 0, y: 0, width: frameBufferWidth, height: framebufferHeight)
    
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
    
    let collada = Collada.ColladaParser(contentsOfURL: NSURL(fileURLWithPath: "/Users/Thomas/Desktop/ColladaTest.dae"))!
    
    var mesh : GLMesh! = nil
    
    for geometryLibrary in collada.root.children where geometryLibrary is Collada.LibraryGeometriesNode {
        mesh = GLMesh.meshesFromCollada((geometryLibrary as! Collada.LibraryGeometriesNode).geometries.first!.meshes.first!).first!
        break
    }
    
    
    let vertexShader = ["#version 410",
                        "layout(location = 0) in vec4 position;",
                        "layout(location = 1) in vec3 normal;",
                        "uniform mat4 mvp;",
                        "void main() {",
                        "gl_Position = mvp * position;",
                        "}"].joined(separator: "\n")
    
    let fragmentShader = ["#version 410",
                          "out vec4 outputColor;",
                          "void main() {",
                          "outputColor = vec4(1.0, 0.0, 0.0, 1.0);",
                          "}"].joined(separator: "\n")
    
    let shader = Shader(withVertexShader: vertexShader, fragmentShader: fragmentShader)
    shader.useProgram()
    
    let modelToView = SGLMath.rotate(SGLMath.translate(mat4(1), vec3(0, 0, 5.0)), Float(0.6), vec3(1, 1, 0))
    let viewToProj = SGLMath.perspectiveFov(Float(M_PI/4.0), 800, 600, 0.1, 100.0)
    let transform = viewToProj * modelToView
    
    shader.setMatrix(transform, forProperty: BasicShaderProperty.mvp)
    
    
    // Game loop
    while glfwWindowShouldClose(window) == GL_FALSE
    {
        // Check if any events have been activated
        // (key pressed, mouse moved etc.) and call
        // the corresponding response functions
        glfwPollEvents()
        
        // Render
        // Clear the colorbuffer
        glClearColor(red: 0.2, green: 0.3, blue: 0.3, alpha: 1.0)
        glClear(GL_COLOR_BUFFER_BIT)
        
        mesh.render()
        
        // Swap the screen buffers
        glfwSwapBuffers(window)
    }
    shader.endUseProgram()
}

// called whenever a key is pressed/released via GLFW
func keyCallback(window: OpaquePointer!, key: Int32, scancode: Int32, action: Int32, mode: Int32)
{
    if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
        glfwSetWindowShouldClose(window, GL_TRUE)
    }
}


main()








