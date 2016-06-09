import Foundation
import CGLFW3
import SGLOpenGL
import SGLMath
import ColladaParser
import PBRenderer
import CPBRendererLibs

let mainWindow : PBWindow


final class CameraControl : WindowInputDelegate {
    let sceneNode : SceneNode
    let movementSpeed = Float(4.0)
    
    let baseRotation : quat
    var yaw = Float(0)
    var pitch = Float(0)
    
    init(node: SceneNode) {
        self.sceneNode = node
        self.baseRotation = self.sceneNode.transform.rotation
    }
    var heldKeys = Set<InputKey>()
    
    var mouseEnabled = false
    
    func keyAction(key: InputKey, action: InputAction, modifiers: InputModifiers) {
        switch action {
        case .Press:
            heldKeys.insert(key)
        case .Release:
            heldKeys.remove(key)
            if key == .Space {
                mouseEnabled = !mouseEnabled
            }
        default: break
        }
    }
    
    func mouseDrag(delta: (x: Double, y: Double)) {
        if (mouseEnabled) {
            self.pitch += Float(delta.y) * 0.01
            self.yaw += Float(delta.x) * 0.01
        }
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
        
        self.sceneNode.transform.translation += (self.sceneNode.transform.nodeToWorldMatrix * movement).xyz
        let pitchQuat = quat(angle: self.pitch, axis: vec3(1, 0, 0))
        let yawQuat = quat(angle: self.yaw, axis: vec3(0, 1, 0))
        
        self.sceneNode.transform.rotation = self.baseRotation * yawQuat * pitchQuat
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
    
    let cameraControl = CameraControl(node: camera.sceneNode)
    mainWindow.inputDelegates.append(cameraControl)

    let environmentMapTexture = TextureLoader.textureFromVerticalCrossHDRCubeMapAtPath(Resources.pathForResource(named: "00261_OpenfootageNET_Beach04_LOW_cross.hdr"))
    let environmentMapProbe = LightProbe(environmentMapWithResolution: 256, texture: environmentMapTexture, exposureMultiplier: 2.0)
    scene.environmentMap = environmentMapProbe

    scene.lightProbesSorted.forEach { $0.render(scene: scene) }
    
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
    
    mainWindow.registerForUpdate { (window, deltaTime) in
        cameraControl.update(delta: deltaTime)
        
//        let lightProbeOutlines = scene.lightProbesSorted.map { (probe) -> (GLMesh, modelToWorld: mat4) in
//            let transform = probe.transform.nodeToWorldMatrix
//            let mesh = GLMesh.unitBox
//            return (mesh, modelToWorld: transform)
//        }
        
//        let lightProbeOutlines = scene.flattenedScene.flatMap { (node) -> (GLMesh, modelToWorld: mat4)? in
//            if node.meshes.0.isEmpty {
//                return nil
//            }
//            
//            let boundingBox = node.meshes.1.axisAlignedBoundingBoxInSpace(nodeToSpaceTransform: node.transform.nodeToWorldMatrix)
//            
//            var transform = SGLMath.translate(mat4(1), boundingBox.centre)
//            transform = SGLMath.scale(transform, boundingBox.size)
//            
//            return (GLMesh.unitBox, modelToWorld: transform)
//        }
        
        
        sceneRenderer.renderScene(scene, camera: camera)
        gui.render()
    }

    scene.lights.first?.type = .SunArea(radius: radians(degrees: 0.263))
    scene.lights.first?.intensity = .Illuminance(94000)
    
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








