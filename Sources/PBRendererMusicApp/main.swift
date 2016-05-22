import Foundation
import CGLFW3
import SGLOpenGL
import SGLMath
import ColladaParser
import PBRenderer
import AudioToolbox

let mainWindow : Window

let song = try! Song(audioFilePath: Process.arguments[2], midiFilePath: Process.arguments[3])

func randomFloat() -> Float {
    return Float(arc4random())/Float(UInt32.max)
}

final class AudioVisualManager : SongDelegate {
    let scene: Scene
    let camera : Camera
    
    var lastMaterialChangeBeat : Double = 0.0
    
    init() {
        
        guard let collada = Collada(contentsOfFile: Process.arguments[1]) else { fatalError("Couldn't load Collada file") }
        
        self.scene = Scene(fromCollada: collada)
        self.camera = scene.flattenedScene.flatMap { $0.cameras.first }.first!
        
        for node in scene.flattenedScene where !node.lights.isEmpty {
            for light in node.lights {
                light.intensity = 0.0
            }
        }
    }
    
    func processEvent(_ event: MIDIEventType, onTrack track: Int, beatNumber: Double) {
        print("Event \(event) occured on track \(track)")
        
        if case let .noteMessage(noteMessage) = event {
            if let lightNode = self.scene.idsToNodes["_pointLight\(noteMessage.note)"] {
                lightNode.lights.forEach { $0.intensity = 2.0 }
            }
        }
    }
    
    func update() {
        let beatNumber = song.beatNumber
        
        let plane = self.scene.idsToNodes["_pPlane1"]!
        
        if beatNumber - lastMaterialChangeBeat >= 0.25 {
            for material in plane.materials.values {
                material.withElement({ material in
                    material.smoothness = randomFloat()
                })
            }
            lastMaterialChangeBeat = beatNumber
        }
        
        self.camera.sceneNode.transform.translation += vec3(0, 0, 0.01)
        
        if beatNumber >= 16.0 {
            let rotation = quat(angle: 0.001, axis: vec3(0, 0, 1))
            plane.transform.rotation *= rotation
        }
    }
}

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
    
    let mainWindow = RenderWindow(name: "PBRenderer Music", width: 1280, height: 800)
    let avManager = AudioVisualManager()
    song.delegate = avManager
    
    mainWindow.registerForUpdate { (window, deltaTime) in
        if !song.isPlaying {
            song.play()
        }
        song.update()
        avManager.update()
        mainWindow.renderScene(avManager.scene, camera: avManager.camera)
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








