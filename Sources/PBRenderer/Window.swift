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
    case unknown =    -1
    
    /* Printable keys */
    case space =      32
    case apostrophe = 39  /* ' */
    case comma =      44  /* , */
    case minus =      45  /* - */
    case period =     46  /* . */
    case slash =      47  /* / */
    case key0 = 48
    case key1 = 49
    case key2 = 50
    case key3 = 51
    case key4 = 52
    case key5 = 53
    case key6 = 54
    case key7 = 55
    case key8 = 56
    case key9 = 57
    case semicolon =  59  /* ; */
    case equal =      61  /* = */
    case a = 65
    case b = 66
    case c = 67
    case d = 68
    case e = 69
    case f = 70
    case g = 71
    case h = 72
    case i = 73
    case j = 74
    case k = 75
    case l = 76
    case m = 77
    case n = 78
    case o = 79
    case p = 80
    case q = 81
    case r = 82
    case s = 83
    case t = 84
    case u = 85
    case v = 86
    case w = 87
    case x = 88
    case y = 89
    case z = 90
    case leftBracket    =  91  /* [ */
    case backslash =  92  /* \ */
    case rightBracket   =   93  /* ] */
    case graveAccent    =   96  /* ` */
    case world1 =    161 /* non-US #1 */
    case world2 =    162 /* non-US #2 */
    
    /* Function keys */
    case escape =     256
    case enter =      257
    case tab =        258
    case backspace =  259
    case insert =     260
    case delete =     261
    case right =      262
    case left =       263
    case down =       264
    case up =         265
    case pageUp =  267
    case home =       268
    case end =        269
    case capsLock =  280
    case scrollLock   =     281
    case numLock =   282
    case printScreen  =     283
    case pause =      284
    case f1 =         290
    case f2 =         291
    case f3 =         292
    case f4 =         293
    case f5 =         294
    case f6 =         295
    case f7 =         296
    case f8 =         297
    case f9 =         298
    case f10 =        299
    case f11 =        300
    case f12 =        301
    case f13 =        302
    case f14 =        303
    case f15 =        304
    case f16 =        305
    case f17 =        306
    case f18 =        307
    case f19 =        308
    case f20 =        309
    case f21 =        310
    case f22 =        311
    case f23 =        312
    case f24 =        313
    case f25 =        314
    case kp0 =       320
    case kp1 =       321
    case kp2 =       322
    case kp3 =       323
    case kp4 =       324
    case kp5 =       325
    case kp6 =       326
    case kp7 =       327
    case kp8 =       328
    case kp9 =       329
    case kpDecimal = 330
    case kpDivide =  331
    case kpMultiply   =    332
    case kpSubtract    =    333
    case kpAdd =     334
    case kpEnter =   335
    case kpEqual =   336
    case leftShift = 340
    case leftControl  =     341
    case leftAlt =   342
    case leftSuper = 343
    case rightShift     =   344
    case rightControl  =    345
    case rightAlt =  346
    case rightSuper     =   347
    case menu =       348
}

public enum MouseButton : Int32 {
    case mouseButton1 = 0
    case mouseButton2 = 1
    case mouseButton3 = 2
    case mouseButton4 = 3
    case mouseButton5 = 4
    case mouseButton6 = 5
    case mouseButton7 = 6
    case mouseButton8 = 7
    
    static let MouseButtonLeft = MouseButton.mouseButton1
    static let MouseButtonRight = MouseButton.mouseButton2
    static let MouseButtonMiddle = MouseButton.mouseButton3
}

public enum InputAction : Int32 {
    case release = 0
    case press = 1
    case `repeat` = 2
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
    func mouseMove(position: (x: Double, y: Double), delta: (x: Double, y: Double))
    func mouseDrag(delta: (x: Double, y: Double))
    func scroll(offsets: (x: Double, y: Double))
    func char(character: UnicodeScalar)
}

public extension WindowInputDelegate {
    func keyAction(key: InputKey, action: InputAction, modifiers: InputModifiers) {
        
    }

    func mouseAction(position: (x: Double, y: Double), button: MouseButton, action: InputAction, modifiers: InputModifiers) {
        
    }
    
    func mouseMove(position: (x: Double, y: Double), delta: (x: Double, y: Double)) {
        
    }
    func mouseDrag(delta: (x: Double, y: Double)) {
    }
    
    func scroll(offsets: (x: Double, y: Double)) {
    }
    
    func char(character: UnicodeScalar) {
    }
}

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

public final class PBWindow {
    
    // called whenever a key is pressed/released via GLFW
    func keyCallback(_ window: OpaquePointer!, key: Int32, scancode: Int32, action: Int32, mode: Int32) {
        if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
            glfwSetWindowShouldClose(window, GL_TRUE)
        }
    }
    
    fileprivate static var glfwWindowsToWindows = [OpaquePointer : PBWindow]()
    
    public let glfwWindow : OpaquePointer!
    
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
    
    public var hasFocus : Bool {
        return glfwGetWindowAttrib(self.glfwWindow, GLFW_FOCUSED) != 0
    }
    
    public var shouldHideCursor : Bool {
        get {
            return glfwGetInputMode(self.glfwWindow, GLFW_CURSOR) == GLFW_CURSOR_HIDDEN
        }
        
        set(shouldHideCursor) {
            glfwSetInputMode(self.glfwWindow, GLFW_CURSOR, shouldHideCursor ? GLFW_CURSOR_HIDDEN : GLFW_CURSOR_NORMAL);
        }
    }
    
    public var shouldClose : Bool {
        return glfwWindowShouldClose(self.glfwWindow) != 0
    }
    
    public var currentTime : Double {
        return glfwGetTime()
    }
    
    public typealias OnUpdate = (_ window: PBWindow, _ deltaTime: Double) -> ()
    fileprivate var onUpdateClosures = [OnUpdate]()
    
    public typealias OnFramebufferResize = (_ width: Int32, _ height: Int32) -> ()
    fileprivate var onFramebufferResizeClosures = [OnFramebufferResize]()

    
    fileprivate var _timeLastFrame = 0.0
    
    fileprivate var _previousMouseX = 0.0;
    fileprivate var _previousMouseY = 0.0;
    
    public var inputDelegates: [WindowInputDelegate] = []
    
    public init(name: String, width: Int, height: Int) {
        // Create a GLFWwindow object that we can use for GLFW's functions
        self.glfwWindow = glfwCreateWindow(GLint(width), GLint(height), name, nil, nil)
        glfwMakeContextCurrent(self.glfwWindow)
        
        guard self.glfwWindow != nil else {
            fatalError("Failed to create GLFW window")
        }
        
        PBWindow.glfwWindowsToWindows[self.glfwWindow] = self
        
        // Set the required callback functions
        glfwSetKeyCallback(self.glfwWindow) { (glfwWindow, key, scanCode, action, modifiers) in
            let window = PBWindow.glfwWindowsToWindows[glfwWindow!]!
            window.inputDelegates.forEach { $0.keyAction(key: InputKey(rawValue: key)!, action: InputAction(rawValue: action)!, modifiers: InputModifiers(rawValue: modifiers)) }
        }
        
        glfwSetMouseButtonCallback(self.glfwWindow) { (glfwWindow, button, action, modifiers) in
            let window = PBWindow.glfwWindowsToWindows[glfwWindow!]!
            
            var xPosition : Double = 0.0, yPosition : Double = 0.0;
            glfwGetCursorPos(glfwWindow, &xPosition, &yPosition);
            
            window.inputDelegates.forEach { $0.mouseAction(position: (xPosition, yPosition), button: MouseButton(rawValue: button)!, action: InputAction(rawValue: action)!, modifiers: InputModifiers(rawValue: modifiers)) };
        }
        
        glfwSetCursorPosCallback(self.glfwWindow) { (glfwWindow, xPosition, yPosition) in
            let window = PBWindow.glfwWindowsToWindows[glfwWindow!]!
            
            let action = glfwGetMouseButton(glfwWindow, GLFW_MOUSE_BUTTON_LEFT)
            let mouseDeltaX = window._previousMouseX - xPosition;
            let mouseDeltaY = window._previousMouseY - yPosition;
            
            if (action == GLFW_PRESS) {
                window.inputDelegates.forEach { $0.mouseDrag(delta: (mouseDeltaX, mouseDeltaY)) };
            }
            window.inputDelegates.forEach { $0.mouseMove(position: (window._previousMouseX, window._previousMouseY), delta: (mouseDeltaX, mouseDeltaY)) }
            
            window._previousMouseX = xPosition;
            window._previousMouseY = yPosition;
        }
        
        glfwSetScrollCallback(self.glfwWindow) { (glfwWindow, xOffset, yOffset)  in
            let window = PBWindow.glfwWindowsToWindows[glfwWindow!]!

            window.inputDelegates.forEach { $0.scroll(offsets: (xOffset, yOffset)) }
        }
        
        glfwSetCharCallback(self.glfwWindow) { (glfwWindow, codePoint) in
            let window = PBWindow.glfwWindowsToWindows[glfwWindow!]!

            let character = UnicodeScalar(codePoint)
            
            window.inputDelegates.forEach { $0.char(character: character!) }
        }
        
        glfwSetFramebufferSizeCallback(self.glfwWindow) { (glfwWindow, width, height) in
            let window = PBWindow.glfwWindowsToWindows[glfwWindow!]!
            window.onFramebufferResizeClosures.forEach { $0(width, height) }
        }
    }
    
    deinit {
        glfwSetWindowShouldClose(self.glfwWindow, 1)
        PBWindow.glfwWindowsToWindows[self.glfwWindow] = nil
    }
    
    public final func update() {
        let elapsedTime = self.currentTime - _timeLastFrame
        
        for closure in self.onUpdateClosures {
            closure(self, elapsedTime)
        }
        
        _timeLastFrame = currentTime
        
        glfwSwapBuffers(self.glfwWindow)
    }
    
    public func registerForUpdate(_ onUpdate: @escaping OnUpdate) {
        self.onUpdateClosures.append(onUpdate)
    }
    
    public func registerForFramebufferResize(_ onResize: @escaping OnFramebufferResize) {
        self.onFramebufferResizeClosures.append(onResize)
    }
}
