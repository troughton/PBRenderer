import Foundation
import CGLFW3
import SGLOpenGL
import SGLMath
import ColladaParser
import PBRenderer
import CPBRendererLibs

let mainWindow : PBWindow


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
//        self.pitch += Float(delta.y) * 0.01
//        self.yaw += Float(delta.x) * 0.01
        
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
    }}

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
    
    let mainWindow = PBWindow(name: "PBRenderer", width: 800, height: 600)
    
    guard let collada = Collada(contentsOfFile: Process.arguments[1]) else { fatalError("Couldn't load Collada file") }
    
    let scene = Scene(fromCollada: collada)
    let camera = scene.cameras.first!

    mainWindow.dimensions = Size(Int32(camera.aspectRatio * Float(baseHeight)), baseHeight)
    
    let sceneRenderer = SceneRenderer(window: mainWindow)
    
    let cameraControl = CameraControl(camera: camera)
    mainWindow.inputDelegates.append(cameraControl)
    
    let lightProbe = LocalLightProbe(resolution: 256)
    lightProbe.render(scene: scene, atPosition: vec3(0, 2.0, 3.0), zNear: 1.0, zFar: 100.0)
    
    var query : GLuint = 0
    glGenQueries(1, &query)
    let timingQuery = query
    
    glBeginQuery(GLenum(GL_TIME_ELAPSED), timingQuery)
    
    lightProbe.render(scene: scene, atPosition: vec3(0, 2.0, 3.0), zNear: 1.0, zFar: 100.0)
    
    glEndQuery(GLenum(GL_TIME_ELAPSED))
    
    var timeElapsed = GLuint(0)
    
    glGetQueryObjectuiv(query, GL_QUERY_RESULT, &timeElapsed)
    let timeElapsedMillis = Double(timeElapsed) * 1.0e-6
    print(String(format: "Elapsed time to generate light probe: %.2fms", timeElapsedMillis))

    
    let gui = GUI(window: mainWindow)
    gui.drawFunctions.append( { (state : inout GUIDisplayState) in
        renderCameraUI(state: &state, camera: camera)
    })
    
    gui.drawFunctions.append( { (state : inout GUIDisplayState) in
        renderTestUI(state: &state)
    })
    
    gui.drawFunctions.append( { (state : inout GUIDisplayState) in
        renderPropertyEditor(state: &state, scene: scene)
    })
    
    gui.drawFunctions.append( { (state : inout GUIDisplayState) in
        renderSceneHierachy(state: &state, scene: scene)
    })
    
    gui.drawFunctions.append( { (state : inout GUIDisplayState) in
        renderFPSCounter(state: &state);
    })
//      gui.drawFunctions.append({ renderTestUI() })
//    gui.drawFunctions.append({ renderLightEditor(light: spotLight!) })

    
    mainWindow.registerForUpdate { (window, deltaTime) in
        cameraControl.update(delta: deltaTime)
        sceneRenderer.renderScene(scene, camera: camera, environmentMap: lightProbe.ldTexture)
        gui.render()
    }

    
    // Game loop
    while !mainWindow.shouldClose {
        // Check if any events have been activated
        // (key pressed, mouse moved etc.) and call
        // the corresponding response functions
        glfwPollEvents()
        
        mainWindow.update()
    }
    
    GUI.shutdown()
}

main()








