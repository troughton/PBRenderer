import Foundation
import CGLFW3
import SGLOpenGL
import SGLMath
import ColladaParser
import PBRenderer

let mainWindow : Window


final class CameraControl : WindowInputDelegate {
    let camera : Camera
    let movementSpeed = Float(0.4)
    
    let baseRotation : quat
    var yaw = Float(0)
    var pitch = Float(0)
    
    init(camera: Camera) {
        self.camera = camera
        self.baseRotation = self.camera.sceneNode.transform.rotation
    }
    var heldKeys = Set<InputKey>()
    
    func keyAction(key: InputKey, action: InputAction, modifiers: InputModifiers) {
        switch action {
        case .Press:
            heldKeys.insert(key)
        case .Release:
            heldKeys.remove(key)
        default: break
        }
    }
    
    func mouseDrag(delta: (x: Double, y: Double)) {
        self.pitch += Float(delta.y) * 0.01
        self.yaw += Float(delta.x) * 0.01
        
    }
    
    func mouseMove(delta: (x: Double, y: Double)) {
        
    }
    
    func mouseAction(position: (x: Double, y: Double), button: MouseButton, action: InputAction, modifiers: InputModifiers) {
    }
    
    func update(delta: Double) {
        var movement = vec4(0, 0, 0, 0)
        for key in heldKeys {
            switch key {
            case .W:
                movement += vec4(0, 0, -movementSpeed, 0)
            case .S:
                movement += vec4(0, 0, movementSpeed, 0)
            case .A:
                movement += vec4(-movementSpeed, 0, 0, 0)
            case .D:
                movement += vec4(movementSpeed, 0, 0, 0)
            default:
                break
            }
        }
        
        self.camera.sceneNode.transform.translation += (self.camera.sceneNode.transform.nodeToWorldMatrix * movement).xyz
        let pitchQuat = quat(angle: self.pitch, axis: vec3(1, 0, 0))
        let yawQuat = quat(angle: self.yaw, axis: vec3(0, 1, 0))
        
        self.camera.sceneNode.transform.rotation = self.baseRotation * yawQuat * pitchQuat
    }
}

let baseHeight = Int32(800)

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
    glfwWindowHint(GLFW_RESIZABLE, GL_TRUE)
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE)
    glfwWindowHint(GLFW_SRGB_CAPABLE, GL_TRUE)
    
    let mainWindow = Window(name: "PBRenderer", width: 800, height: 600)
    
    guard let collada = Collada(contentsOfFile: Process.arguments[1]) else { fatalError("Couldn't load Collada file") }
    
    let scene = Scene(fromCollada: collada)
    let camera = scene.flattenedScene.flatMap { $0.cameras.first }.first!
    
    mainWindow.dimensions = Window.Size(Int32(camera.aspectRatio * Float(baseHeight)), baseHeight)
    
    let sceneRenderer = SceneRenderer(window: mainWindow)
    
    let cameraControl = CameraControl(camera: camera)
    mainWindow.inputDelegate = cameraControl
    
    mainWindow.registerForUpdate { (window, deltaTime) in
        cameraControl.update(delta: deltaTime)
        sceneRenderer.renderScene(scene, camera: camera)
    }
    
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








