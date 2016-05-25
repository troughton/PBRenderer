//
//  Window.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 3/05/16.
//
//

import Foundation
import CGLFW3
import SGLOpenGL
import SGLMath
import ColladaParser

public enum InputKey : Int32 {
    /* The unknown key */
    case Unknown =    -1
    
    /* Printable keys */
    case Space =      32
    case Apostrophe = 39  /* ' */
    case Comma =      44  /* , */
    case Minus =      45  /* - */
    case Period =     46  /* . */
    case Slash =      47  /* / */
    case Key0 = 48
    case Key1 = 49
    case Key2 = 50
    case Key3 = 51
    case Key4 = 52
    case Key5 = 53
    case Key6 = 54
    case Key7 = 55
    case Key8 = 56
    case Key9 = 57
    case Semicolon =  59  /* ; */
    case Equal =      61  /* = */
    case A = 65
    case B = 66
    case C = 67
    case D = 68
    case E = 69
    case F = 70
    case G = 71
    case H = 72
    case I = 73
    case J = 74
    case K = 75
    case L = 76
    case M = 77
    case N = 78
    case O = 79
    case P = 80
    case Q = 81
    case R = 82
    case S = 83
    case T = 84
    case U = 85
    case V = 86
    case W = 87
    case X = 88
    case Y = 89
    case Z = 90
    case LeftBracket    =  91  /* [ */
    case Backslash =  92  /* \ */
    case RightBracket   =   93  /* ] */
    case GraveAccent    =   96  /* ` */
    case World1 =    161 /* non-US #1 */
    case World2 =    162 /* non-US #2 */
    
    /* Function keys */
    case Escape =     256
    case Enter =      257
    case Tab =        258
    case Backspace =  259
    case Insert =     260
    case Delete =     261
    case Right =      262
    case Left =       263
    case Down =       264
    case Up =         265
    case PageUp =  267
    case Home =       268
    case End =        269
    case CapsLock =  280
    case ScrollLock   =     281
    case NumLock =   282
    case PrintScreen  =     283
    case Pause =      284
    case F1 =         290
    case F2 =         291
    case F3 =         292
    case F4 =         293
    case F5 =         294
    case F6 =         295
    case F7 =         296
    case F8 =         297
    case F9 =         298
    case F10 =        299
    case F11 =        300
    case F12 =        301
    case F13 =        302
    case F14 =        303
    case F15 =        304
    case F16 =        305
    case F17 =        306
    case F18 =        307
    case F19 =        308
    case F20 =        309
    case F21 =        310
    case F22 =        311
    case F23 =        312
    case F24 =        313
    case F25 =        314
    case KP0 =       320
    case KP1 =       321
    case KP2 =       322
    case KP3 =       323
    case KP4 =       324
    case KP5 =       325
    case KP6 =       326
    case KP7 =       327
    case KP8 =       328
    case KP9 =       329
    case KPDecimal = 330
    case KPDivide =  331
    case KPMultiply   =    332
    case KPSubtract    =    333
    case KPAdd =     334
    case KPEnter =   335
    case KPEqual =   336
    case LeftShift = 340
    case LeftControl  =     341
    case LeftAlt =   342
    case LeftSuper = 343
    case RightShift     =   344
    case RightControl  =    345
    case RightAlt =  346
    case RightSuper     =   347
    case Menu =       348
}

public enum MouseButton : Int32 {
    case MouseButton1 = 0
    case MouseButton2 = 1
    case MouseButton3 = 2
    case MouseButton4 = 3
    case MouseButton5 = 4
    case MouseButton6 = 5
    case MouseButton7 = 6
    case MouseButton8 = 7
    
    static let MouseButtonLeft = MouseButton.MouseButton1
    static let MouseButtonRight = MouseButton.MouseButton2
    static let MouseButtonMiddle = MouseButton.MouseButton3
}

public enum InputAction : Int32 {
    case Release = 0
    case Press = 1
    case Repeat = 2
}

public struct InputModifiers : OptionSet {
    public let rawValue : Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    static let Shift = InputModifiers(rawValue: 1)
    static let Control = InputModifiers(rawValue: 2)
    static let Alt = InputModifiers(rawValue: 4)
    static let Super = InputModifiers(rawValue: 8)
}

public protocol WindowInputDelegate {
    func keyAction(key: InputKey, action: InputAction, modifiers: InputModifiers)
    
    func mouseAction(position: (x: Double, y: Double), button: MouseButton, action: InputAction, modifiers: InputModifiers)
    func mouseMove(delta: (x: Double, y: Double))
    func mouseDrag(delta: (x: Double, y: Double))
}

public extension WindowInputDelegate {
    func keyAction(key: InputKey, action: InputAction, modifiers: InputModifiers) {
        
    }

    func mouseAction(position: (x: Double, y: Double), button: MouseButton, action: InputAction, modifiers: InputModifiers) {
        
    }
    
    func mouseMove(delta: (x: Double, y: Double)) {
        
    }
    func mouseDrag(delta: (x: Double, y: Double)) {
    }
}

public class Window {
    
    // called whenever a key is pressed/released via GLFW
    func keyCallback(window: OpaquePointer!, key: Int32, scancode: Int32, action: Int32, mode: Int32) {
        if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
            glfwSetWindowShouldClose(window, GL_TRUE)
        }
    }
    
    private static var glfwWindowsToWindows = [OpaquePointer : Window]()
    
    public let glfwWindow : OpaquePointer!
    
    public struct Size {
        let width: GLint
        let height: GLint
        
        public init(_ width: GLint, _ height: GLint) {
            self.width = width
            self.height = height
        }
        
        public var aspect : Float {
            return Float(self.width) / Float(self.height)
        }
    }
    
    public var dimensions : Size {
        get {
            var width : GLint = 0, height : GLint = 0
            glfwGetWindowSize(self.glfwWindow, &width, &height)
            return Size(width, height)
        }
        set (newDimensions) {
            glfwSetWindowSize(self.glfwWindow, newDimensions.width, newDimensions.height)
        }
    }
    
    public var pixelDimensions : Size {
        var width : GLint = 0, height : GLint = 0
        glfwGetFramebufferSize(self.glfwWindow, &width, &height)
        return Size(width, height)
    }
    
    public var shouldClose : Bool {
        return glfwWindowShouldClose(self.glfwWindow) != 0
    }
    
    public typealias OnUpdate = (window: Window, deltaTime: Double) -> ()
    private var onUpdateClosures = [OnUpdate]()
    
    public typealias OnFramebufferResize = (width: Int32, height: Int32) -> ()
    private var onFramebufferResizeClosures = [OnFramebufferResize]()

    
    private var _timeLastFrame = 0.0
    
    private var _previousMouseX = 0.0;
    private var _previousMouseY = 0.0;
    
    public var inputDelegate: WindowInputDelegate? = nil
    
    public init(name: String, width: Int, height: Int) {
        // Create a GLFWwindow object that we can use for GLFW's functions
        self.glfwWindow = glfwCreateWindow(GLint(width), GLint(height), name, nil, nil)
        glfwMakeContextCurrent(self.glfwWindow)
        
        guard self.glfwWindow != nil else {
            fatalError("Failed to create GLFW window")
        }
        
        Window.glfwWindowsToWindows[self.glfwWindow] = self
        
        // Set the required callback functions
        glfwSetKeyCallback(self.glfwWindow) { (glfwWindow, key, scanCode, action, modifiers) in
            let window = Window.glfwWindowsToWindows[glfwWindow!]!
            window.inputDelegate?.keyAction(key: InputKey(rawValue: key)!, action: InputAction(rawValue: action)!, modifiers: InputModifiers(rawValue: modifiers))
        }
        
        glfwSetMouseButtonCallback(self.glfwWindow) { (glfwWindow, button, action, modifiers) in
            let window = Window.glfwWindowsToWindows[glfwWindow!]!
            
            var xPosition : Double = 0.0, yPosition : Double = 0.0;
            glfwGetCursorPos(glfwWindow, &xPosition, &yPosition);
            
            window.inputDelegate?.mouseAction(position: (xPosition, yPosition), button: MouseButton(rawValue: button)!, action: InputAction(rawValue: action)!, modifiers: InputModifiers(rawValue: modifiers));
        }
        
        glfwSetCursorPosCallback(self.glfwWindow) { (glfwWindow, xPosition, yPosition) in
            let window = Window.glfwWindowsToWindows[glfwWindow!]!
            
            let action = glfwGetMouseButton(glfwWindow, GLFW_MOUSE_BUTTON_LEFT)
            let mouseDeltaX = window._previousMouseX - xPosition;
            let mouseDeltaY = window._previousMouseY - yPosition;
            
            if (action == GLFW_PRESS) {
                window.inputDelegate?.mouseDrag(delta: (mouseDeltaX, mouseDeltaY));
            }
            window.inputDelegate?.mouseMove(delta: (mouseDeltaX, mouseDeltaY))
            
            window._previousMouseX = xPosition;
            window._previousMouseY = yPosition;
        }
        
        glfwSetFramebufferSizeCallback(self.glfwWindow) { (glfwWindow, width, height) in
            let window = Window.glfwWindowsToWindows[glfwWindow!]!
            window.onFramebufferResizeClosures.forEach { $0(width: width, height: height) }
        }
    }
    
    deinit {
        glfwSetWindowShouldClose(self.glfwWindow, 1)
        Window.glfwWindowsToWindows[self.glfwWindow] = nil
    }
    
    public final func update() {
        
        let currentTime = glfwGetTime()
        let elapsedTime = currentTime - _timeLastFrame
        
        for closure in self.onUpdateClosures {
            closure(window: self, deltaTime: elapsedTime)
        }
        
        _timeLastFrame = currentTime
        
        glfwSwapBuffers(self.glfwWindow)
    }
    
    public func registerForUpdate(onUpdate: OnUpdate) {
        self.onUpdateClosures.append(onUpdate)
    }
    
    public func registerForFramebufferResize(onResize: OnFramebufferResize) {
        self.onFramebufferResizeClosures.append(onResize)
    }
}