import Foundation
import CGLFW3
import SGLOpenGL

// Window dimensions
let WIDTH:GLsizei = 800, HEIGHT:GLsizei = 600

// The *main* function; where our program begins running
func main()
{
    // Init GLFW
    glfwInit()
    // Terminate GLFW when this function ends
    defer { glfwTerminate() }
    
    // Set all the required options for GLFW
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3)
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
    
    
    let vertices : [GLfloat] = [0.5, 0.5, 0, 0, 0, 0, 0.5, 0, 0]
    let normals : [GLfloat] = [0, 0, 1, 0, 0, 1, 0, 0, 1]
    let indices : [GLuint] = [0, 1, 2]
    
    let positionAttribute = VertexAttribute(data: vertices, glType: GL_FLOAT, stride: 3, typeSizeInBytes: sizeof(GLfloat), count: 3)
    
    let normalAttribute =  VertexAttribute(data: normals, glType: GL_FLOAT, stride: 3, typeSizeInBytes: sizeof(GLfloat), count: 3)
    
    let indexAttribute =  VertexAttribute(data: indices, glType: GL_UNSIGNED_INT, stride: 1, typeSizeInBytes: sizeof(GLint), count: 3)
    
    let mesh = GLMesh(vertexCount: 3, attributes: [.Index : indexAttribute, .Position : positionAttribute, .Normal : normalAttribute])
    
    
    let vertexShader = ["#version 410",
                        "layout(location = 0) in vec4 position;",
                        "layout(location = 1) in vec3 normal;",
                        "void main() {",
                        "gl_Position = position;",
                        "}"].joined(separator: "\n")
    
    let fragmentShader = ["#version 410",
                          "out vec4 outputColor;",
                          "void main() {",
                          "outputColor = vec4(1.0, 0.0, 0.0, 1.0);",
                          "}"].joined(separator: "\n")
    
    let shader = Shader(withVertexShader: vertexShader, fragmentShader: fragmentShader)
    shader.useProgram()
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








