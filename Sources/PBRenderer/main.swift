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
let document = try NSXMLDocument(contentsOf: NSURL(fileURLWithPath: "/Users/Thomas/Desktop/ColladaTest.dae"), options: 0)

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
    
    let mainWindow = Window(name: "PBRenderer", width: 800, height: 600)
    
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
    while !mainWindow.shouldClose {
        // Check if any events have been activated
        // (key pressed, mouse moved etc.) and call
        // the corresponding response functions
        glfwPollEvents()
        
        // Render
        // Clear the colorbuffer
        glClearColor(red: 0.2, green: 0.3, blue: 0.3, alpha: 1.0)
        glClear(GL_COLOR_BUFFER_BIT)
        
        mesh.render()
        
        mainWindow.update()
    }
    shader.endUseProgram()
}

print(document.rootElement()?.elements(forName: "library_geometries").first?.elements(forName: "geometry").first?.attributes)

main()








