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
        
        self.camera.sceneNode.transform.rotation = /*self.baseRotation * */yawQuat * pitchQuat
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
    
    let mainWindow = PBWindow(name: "PBRenderer", width: 800, height: 600)
    
    guard let collada = Collada(contentsOfFile: Process.arguments[1]) else { fatalError("Couldn't load Collada file") }
    
    let scene = Scene(fromCollada: collada)
    let camera = scene.cameras.first!
    camera.sceneNode.transform.rotation = quat.identity
    
    for light in scene.lights {
        light.intensity *= 5000000
    }
    
    mainWindow.dimensions = Size(Int32(camera.aspectRatio * Float(baseHeight)), baseHeight)
    
    let sceneRenderer = SceneRenderer(window: mainWindow)
    
    let cameraControl = CameraControl(camera: camera)
    mainWindow.inputDelegate = cameraControl
    
    // Setup ImGui binding
    ImGui_ImplGlfwGL3_Init(window: mainWindow.glfwWindow, install_callbacks: true);
    
    var show_test_window = true;
    var show_another_window = false;
    var clear_color = vec3(114, 144, 154);
    
    
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
    
    
    
    mainWindow.registerForUpdate { (window, deltaTime) in
        cameraControl.update(delta: deltaTime)
        sceneRenderer.renderScene(scene, camera: camera, environmentMap: lightProbe.ldTexture)
        
        ImGui_ImplGlfwGL3_NewFrame();
        
        // 1. Show a simple window
        // Tip: if we don't call igBegin()/igEnd() the widgets appears in a window automatically called "Debug"
        {
            var f = Float(0.0);
            igText("Hello, world!");
            igSliderFloat(label: "float", value: &f, vMin: 0.0, vMax: 1.0);
            withUnsafeMutablePointer(&clear_color.x) { igColorEdit3("clear color", $0); }
            if (igButton(label: "Test Window")) { show_test_window = !show_test_window; }
            if (igButton(label: "Another Window")) { show_another_window = !show_another_window; }
            igText(String(format: "Application average %.3f ms/frame (%.1f FPS)", 1000.0 / igGetIO().pointee.Framerate, igGetIO().pointee.Framerate));
        }()
        
        // 2. Show another simple window, this time using an explicit Begin/End pair
        if (show_another_window)
        {
            igSetNextWindowSize(ImVec2(x: 200,y: 100), Int32(ImGuiSetCond_FirstUseEver.rawValue));
            igBegin(name: "Another Window", didOpen: &show_another_window);
            igText("Hello");
            igEnd();
        }
        
        // 3. Show the ImGui test window. Most of the sample code is in igShowTestWindow()
        if (show_test_window)
        {
            igSetNextWindowPos(ImVec2(x: 650, y: 20), Int32(ImGuiSetCond_FirstUseEver.rawValue));
            igShowTestWindow(&show_test_window);
        }
        
        igRender();
        
      
    }
    
    // Cleanup
    ImGui_ImplGlfwGL3_Shutdown();

    
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








