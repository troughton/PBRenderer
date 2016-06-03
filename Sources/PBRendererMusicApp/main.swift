#if os(OSX)

import Foundation
import CGLFW3
import SGLOpenGL
import SGLMath
import ColladaParser
import PBRenderer
import AudioToolbox

let mainWindow : PBWindow

let song = try! Song(audioFilePath: Process.arguments[2], midiFilePath: Process.arguments[3])

func randomFloat() -> Float {
    return Float(arc4random())/Float(UInt32.max)
}
    
    enum Instrument {
        case DrivingChords
        case SoftChordsElectricPiano
        case HighMotif
        case Drums
        case Kick
        case Snare
        case MainMelody
        case SecondMelody
        case LowBass
        
        static func instrumentForTrackNumber(_ trackNumber: Int) -> Instrument {
            if trackNumber < 15 {
                return .DrivingChords
            } else if trackNumber < 21 {
                return .SoftChordsElectricPiano
            } else if trackNumber < 25 {
                return .Drums
            } else if trackNumber < 42 {
                return .Kick
            } else if trackNumber < 50 {
                return .Snare
            } else if trackNumber < 61 {
                return .MainMelody
            } else if trackNumber < 79 {
                return .HighMotif
            } else if trackNumber < 85 {
                return .SecondMelody
            } else {
                return .LowBass
            }
        }
    }

    let highMotifNotes = [81, 83, 86, 88]
    
final class AudioVisualManager : SongDelegate {
    let scene: Scene
    let camera : Camera
    
    var lastMaterialChangeBeat : Double = 0.0
    
    init() {
        
        guard let collada = Collada(contentsOfFile: Process.arguments[1]) else { fatalError("Couldn't load Collada file") }
        
        self.scene = Scene(fromCollada: collada)
        self.camera = scene.namesToNodes["MainCamera"]!.cameras.first!
        
        
        let startCamera = scene.namesToNodes["camera1"]!.cameras.first!
        self.camera.transform.translation = startCamera.transform.translation
        self.camera.transform.rotation = startCamera.transform.rotation
        
        self.camera.shutterTime = 1.0
        self.camera.aperture = 1.0
        
        self.scene.lights.forEach { $0.intensity.value = 0 }
        
        for i in 1...6 {
            let backgroundAreaLightPlane = scene.namesToNodes["BackgroundAreaLightPlane\(i)"]!
            let materialElement = backgroundAreaLightPlane.materials.values.first!
            
            materialElement.withElement({ material in
                material.baseColour = vec4(0, 0, 0, 1)
                material.emissive = vec4(0)
                material.smoothness = 0
                material.metalMask = 0
            })
            
        }
        
        let endCamera = scene.namesToNodes["camera2"]!.cameras.first!
        
        let cameraAnimation = AnimationSystem.Animation(startBeat: 4 * 13, duration: 4 * 4, repeatsUntil: nil, onTick: { (elapsedBeats, percentage) in
            
            let translation = lerp(from: startCamera.transform.translation, to: endCamera.transform.translation, t: Float(percentage))
            
            self.camera.transform.translation = translation
            self.camera.transform.rotation = slerp(from: startCamera.transform.rotation, to: endCamera.transform.rotation, t: Float(percentage))
        })
        AnimationSystem.addAnimation(cameraAnimation)
        
    }
    
    func processEvent(_ event: MIDIEventType, onTrack track: Int, beatNumber: Double) {
        
        if case let .noteMessage(noteMessage) = event {
            let instrument = Instrument.instrumentForTrackNumber(track)
            print("Note \(noteMessage.note) playing for \(noteMessage.duration) beats on instrument \(instrument)")
            
            switch instrument {
            case .HighMotif:
                processHighMotifEvent(event, scene: self.scene, beatNumber: beatNumber)
            case .DrivingChords:
                processDrivingChordsEvent(event, scene: self.scene, beatNumber: beatNumber)
            case .Kick:
                processKickEvent(event, scene: self.scene, beatNumber: beatNumber)
            case .Snare:
                processSnareEvent(event, scene: self.scene, beatNumber: beatNumber)
            case .Drums:
                processDrumEvent(event, scene: self.scene, beatNumber: beatNumber)
            case .MainMelody:
                processMainMelodyEvent(event, scene: self.scene, beatNumber: beatNumber)
            case .LowBass:
                processLowBassEvent(event, scene: self.scene, beatNumber: beatNumber)
            default:
                break;
            }
            
       }
    }
    
    func update() {
        let beatNumber = song.beatNumber
        AnimationSystem.tick(currentBeat: beatNumber)
        
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
    
    let mainWindow = PBWindow(name: "PBRenderer Music", width: 1280, height: 800)
    let avManager = AudioVisualManager()
    song.delegate = avManager
    
    let sceneRenderer = SceneRenderer(window: mainWindow)
    
    song.update()
    avManager.update()
    
    mainWindow.registerForUpdate { (window, deltaTime) in
        
        if !song.isPlaying {
            song.play()
        }
        
        song.update()
        avManager.update()
        
        sceneRenderer.renderScene(avManager.scene, camera: avManager.camera)
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

#endif