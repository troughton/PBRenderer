//
//  ImGui.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 25/05/16.
//
//

import Foundation
import SGLOpenGL
import CGLFW3
import SGLMath


public struct GUIWindowFlags : OptionSet {
    public let rawValue : Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let Default = GUIWindowFlags(rawValue: 0)
    static let NoTitleBar = GUIWindowFlags(rawValue: 1 << 0)  // Disable title-bar
    static let NoResize = GUIWindowFlags(rawValue: 1 << 1) // Disable user resizing with the lower-right grip
    static let NoMove = GUIWindowFlags(rawValue: 1 << 2)   // Disable user moving the window
    static let NoScrollbar = GUIWindowFlags(rawValue: 1 << 3) // Disable scrollbars (window can still scroll with mouse or programatically)
    static let NoScrollWithMouse = GUIWindowFlags(rawValue: 1 << 4)  // Disable user vertically scrolling with mouse wheel
    static let NoCollapse = GUIWindowFlags(rawValue: 1 << 5)     // Disable user collapsing window by double-clicking on it
    static let AlwaysAutoResize = GUIWindowFlags(rawValue: 1 << 6)    // Resize every window to its content every frame
    static let ShowBorders = GUIWindowFlags(rawValue: 1 << 7)  // Show borders around windows and items
    static let NoSavedSettings  = GUIWindowFlags(rawValue: 1 << 8)    // Never load/save settings in .ini file
    static let NoInputs   = GUIWindowFlags(rawValue: 1 << 9)  // Disable catching mouse or keyboard inputs
    static let MenuBar      = GUIWindowFlags(rawValue: 1 << 10)   // Has a menu-bar
    static let HorizontalScrollbar    = GUIWindowFlags(rawValue: 1 << 11)   // Allow horizontal scrollbar to appear (off by default). You may use SetNextWindowContentSize(ImVec2(width,0.0f)); prior to calling Begin() to specify width. Read code in imgui_demo in the "Horizontal Scrolling" section.
    static let NoFocusOnAppearing    = GUIWindowFlags(rawValue: 1 << 12)   // Disable taking focus when transitioning from hidden to visible state
    static let NoBringToFrontOnFocus = GUIWindowFlags(rawValue: 1 << 13)    // Disable bringing window to front when taking focus (e.g. clicking on it or programatically giving it focus)
    static let AlwaysVerticalScrollbar = GUIWindowFlags(rawValue: 1 << 14)   // Always show vertical scrollbar (even if ContentSize.y < Size.y)
    static let AlwaysHorizontalScrollbar = GUIWindowFlags(rawValue: 1 << 15)    // Always show horizontal scrollbar (even if ContentSize.x < Size.x)
    static let AlwaysUseWindowPadding = GUIWindowFlags(rawValue: 1 << 16)   // Ensure child windows without border uses style.WindowPadding (ignored by default for non-
}

public typealias UIDrawFunction = (_ state: inout GUIDisplayState) -> Void

public final class GUI {
    public var drawFunctions : [UIDrawFunction] = []
    
    let window : PBWindow
    
    fileprivate var _displayState = GUIDisplayState()
    fileprivate let _imGui : ImGui
    
    public init(window: PBWindow) {
        self.window = window
        _imGui = ImGui(window: window)
    }
    
    public func render() {
        _imGui.newFrame()
        
        drawFunctions.forEach { (drawFunction) in
            drawFunction(&_displayState);
        }
        
        _imGui.render()
    }
    
    public static func shutdown() {
        ImGui.shutdown()
    }
}


public struct GUIDisplayState {
    var sceneEditorOpen : Bool = true
    var cameraEditorOpen : Bool = true
    
    // the id of node being editied in the editor
    var editorSceneNodeId : String? = nil
}

public func renderTestUI(state: inout GUIDisplayState) {
    igSetNextWindowPos(ImVec2(x: 650, y: 20), Int32(ImGuiSetCond_FirstUseEver.rawValue));
    var show_test_window = true
    withUnsafeMutablePointer(to: &show_test_window) { (opened) -> () in
        igShowTestWindow(opened)
    }
}

public func renderCameraUI(state: inout GUIDisplayState, camera: Camera) {
    _ = igBegin(label: "Camera - \(camera.name!)", didOpen: &state.cameraEditorOpen, flags: GUIWindowFlags.Default)
    
    igText("Exposure: \(camera.exposure)")
    _ = igSliderFloat(label: "Aperture", value: &camera.aperture, vMin: 0.7, vMax: 200.0);
    _ = igSliderFloat(label: "Shutter Time", value: &camera.shutterTime, vMin: 0.01, vMax: 10);
    _ = igSliderFloat(label: "ISO", value: &camera.ISO, vMin: 100, vMax: 2000);
    igEnd()
}

public func renderPropertyEditor(state: inout GUIDisplayState, scene: Scene) {
    if(!igBegin(label: "Scene Node Editor", didOpen: &state.sceneEditorOpen, flags: GUIWindowFlags.Default)) {
        igEnd()
        return
    }
    
    if let editorSceneNodeId = state.editorSceneNodeId {
        if let sceneNode = scene.idsToNodes[editorSceneNodeId] {
            igText(sceneNode.id)
            renderTransformControls(sceneNode.transform)
            
            sceneNode.lights.forEach({ (light) in
                renderLightControls(light)
            })
            
            sceneNode.cameras.forEach({ (camera) in
                renderCameraControls(camera: camera)
            })
            
            renderMaterialControls(sceneNode.materials)
        } else {
            igText("No scene node selected")
        }
    } else {
        igText("No scene node selected")
    }
    
    igEnd()
}

private var currentTransform : Transform? = nil
private var currentEulerRotation : vec3! = nil

private func renderTransformControls(_ transform: Transform) {
    
    if transform !== currentTransform {
        currentTransform = transform
        currentEulerRotation = degrees(transform.rotation.eulerAngles)
    }
    
    if(igCollapsingHeader(label: "Transform")) {
        igText("Translation")
        _ = igDragFloat(label: "x", value: &transform.translation.x, vSpeed: 0.1, vMin: -100.0, vMax: 100.0)
        _ = igDragFloat(label: "y", value: &transform.translation.y, vSpeed: 0.1, vMin: -100.0, vMax: 100.0)
        _ = igDragFloat(label: "z", value: &transform.translation.z, vSpeed: 0.1, vMin: -100.0, vMax: 100.0)
        
        igText("Rotation")
        igText("x:\(currentEulerRotation.x), y:\(currentEulerRotation.y), z:\(currentEulerRotation.z)")
        _ = igDragFloat(label: "x_r", value: &currentEulerRotation.x, vSpeed: 0.1, vMin: -180.0, vMax: 180.0)
        _ = igDragFloat(label: "y_r", value: &currentEulerRotation.y, vSpeed: 0.1, vMin: -180.0, vMax: 180.0)
        _ = igDragFloat(label: "z_r", value: &currentEulerRotation.z, vSpeed: 0.1, vMin: -180.0, vMax: 180.0)
        
        let rotation = quat(eulerAngles: radians(currentEulerRotation))
        transform.rotation = rotation
        
        igText("Scale")
        _ = igDragFloat(label: "x_s", value: &transform.scale.x, vSpeed: 0.1, vMin: 0.01, vMax: 100.0)
        _ = igDragFloat(label: "y_s", value: &transform.scale.y, vSpeed: 0.1, vMin: 0.01, vMax: 100.0)
        _ = igDragFloat(label: "z_s", value: &transform.scale.z, vSpeed: 0.1, vMin: 0.01, vMax: 100.0)
        
    }
}

private let lightTypes : [(String, LightType)] = [("Point", LightType.point),
                                                  ("Spot", LightType.spot(innerCutoff: 0.1, outerCutoff: 1.0)),
                                                  ("Directional", LightType.directional),
                                                  ("Sphere Area", LightType.sphereArea(radius: 1.0)),
                                                  ("Disk Area", LightType.diskArea(radius: 1.0)),
                                                  ("Rectangle Area", LightType.rectangleArea(width: 1.0, height: 1.0, twoSided: false)),
                                                  ("Triangle Area", LightType.triangleArea(base:1.0, height: 1.0, twoSided: false)),
                                                  ("Sun Area", LightType.sunArea(radius: radians(0.263)))]



private let lightUnitText = [("lx", LightIntensity.illuminance(1.0)),
                             ("cd/m²", LightIntensity.luminance(1.0)),
                             ("lm", LightIntensity.luminousPower(1.0)),
                             ("cd", LightIntensity.luminousIntensity(1.0))]

private func renderMaterialControls(_ materials: [String : GPUBufferElement<Material>]) {
    for (name, material) in materials {
        renderMaterialUI(material, name: name)
    }
   
}

private func renderLightControls(_ light: Light) {
    if(igCollapsingHeader(label: "Light")) {
        var currentLightType = lightTypes.index { (tuple) -> Bool in
            return tuple.1.isSameTypeAs(light.type)
        }!
        
        let rgbColour = light.colour.rgbColour
        var rgbColourArray = (rgbColour.x, rgbColour.y, rgbColour.z)
        igColorEdit3("Colour", &rgbColourArray.0)
        light.colour = LightColourMode.colour(vec3(rgbColourArray.0, rgbColourArray.1, rgbColourArray.2))
                
        igCombo(label: "Type", currentItem: &currentLightType, items: lightTypes.lazy.map { $0.0 })
        
        // only change if we switch to another light type
        let newLightType = lightTypes[currentLightType].1
        if !light.type.isSameTypeAs(newLightType) {
            light.type = newLightType
        }
        
        let currentLightUnit = lightUnitText.index { (tuple) -> Bool in
            return tuple.1.isSameTypeAs(light.intensity)
            }!
        
        var intensity = light.intensity.value
        _ = igDragFloat(label: "Intensity (\(lightUnitText[currentLightUnit].0))", value: &intensity, vSpeed: 100, vMin: 0.0, vMax: 100000000.0)
        light.intensity = LightIntensity(unit: light.type.validUnits.first!, value: intensity)
        
        switch(light.type) {
        case .diskArea(var radius):
            _ = igDragFloat(label: "Radius", value: &radius, vSpeed: 0.01, vMin: 0.1, vMax: 100)
            light.type = .diskArea(radius: radius)
            break
        case .sphereArea(var radius):
            _ = igDragFloat(label: "Radius", value: &radius, vSpeed: 0.01, vMin: 0.1, vMax: 100)
            light.type = .sphereArea(radius: radius)
            break
        case .sunArea(var radius):
            _ = igDragFloat(label: "Radius", value: &radius, vSpeed: 0.001, vMin: 0.005, vMax: 5)
            light.type = .sunArea(radius: radius)
            break
        case .rectangleArea(var width, var height, var isTwoSided):
            _ = igDragFloat(label: "Width", value: &width, vSpeed: 0.01, vMin: 0.1, vMax: 100)
            _ = igDragFloat(label: "Height", value: &height, vSpeed: 0.01, vMin: 0.1, vMax: 100)
            _ = igCheckbox("Two-sided", &isTwoSided)
            light.type = .rectangleArea(width: width, height: height, twoSided: isTwoSided)
            break
        case .triangleArea(var base, var height, var isTwoSided):
            _ = igDragFloat(label: "Base", value: &base, vSpeed: 0.01, vMin: 0.1, vMax: 100)
            _ = igDragFloat(label: "Height", value: &height, vSpeed: 0.01, vMin: 0.1, vMax: 100)
            _ = igCheckbox("Two-sided", &isTwoSided)
            light.type = .triangleArea(base: base, height: height, twoSided: isTwoSided)
            break
            
        default:
            break
        }
    }
}

public func renderCameraControls(camera: Camera) {
    if(igCollapsingHeader(label: "Camera")) {
        igText("Exposure: \(camera.exposure)")
        _ = igSliderFloat(label: "Aperture", value: &camera.aperture, vMin: 0.7, vMax: 200.0);
        _ = igSliderFloat(label: "Shutter Time", value: &camera.shutterTime, vMin: 0, vMax: 10);
        _ = igSliderFloat(label: "ISO", value: &camera.ISO, vMin: 0, vMax: 2000);
    }
}

public func renderFPSCounter(state: inout GUIDisplayState) {
    igSetNextWindowPos(ImVec2(x: 10, y: 10), Int32(ImGuiSetCond_FirstUseEver.rawValue))
    
    var opened = true
    igBegin(label: "Stats", didOpen: &opened, flags: [GUIWindowFlags.NoTitleBar, GUIWindowFlags.NoResize, GUIWindowFlags.NoMove, GUIWindowFlags.NoSavedSettings])
    igText("Stats")
    igSeparator()
    igText(String(format: "%.3f ms/frame (%.1f FPS)", 1000.0 / igGetIO().pointee.Framerate, igGetIO().pointee.Framerate))
    igEnd()
}


public func renderSceneHierachy(state: inout GUIDisplayState, scene: Scene) {
    
    if(!igBegin(label: "Scene", didOpen: &state.sceneEditorOpen, flags: GUIWindowFlags.Default)) {
        igEnd()
        return
    }
    
    igPushStyleVarVec(Int32(ImGuiStyleVar_FramePadding.rawValue), ImVec2(x: 2,y: 2))
    igColumns(2, "Test Columns", false)
    igSeparator()
    
    func renderChild(_ sceneNode: SceneNode) {
        
        let sceneNodeID = sceneNode.id ?? "No ID"
        
        igPushIdStr(sceneNodeID)
        igAlignFirstTextHeightToWidgets()
        
        let node_open = igTreeNode("\(sceneNodeID)")
        igNextColumn()
        igAlignFirstTextHeightToWidgets()
        
        
        if state.editorSceneNodeId == sceneNodeID {
            igPushStyleColor(Int32(ImGuiCol_Button.rawValue), ImVec4 (x: 0.8, y: 0.52, z: 0.82, w: 1))
            igPushStyleColor(Int32(ImGuiCol_ButtonHovered.rawValue), ImVec4 (x: 0.9, y: 0.52, z: 0.92, w: 1))
            
            if (igButton(label: "Edit")) {
                state.editorSceneNodeId = sceneNodeID
            }
            igPopStyleColor(2)
        } else {
            if (igButton(label: "Edit")) {
                state.editorSceneNodeId = sceneNodeID
            }
        }
        
        igNextColumn()
        
        if (node_open) {
            igText("\(sceneNodeID)")
            
            sceneNode.children.forEach({ (child) in
                renderChild(child)
            })
            
            igTreePop()
        }
        igPopId()
    }
    
    scene.nodes.forEach { (sceneNode) in
        renderChild(sceneNode)
    }
    
    igColumns(1, nil, false)
    igSeparator()
    igPopStyleVar(1)
    igEnd()
}

private func renderLightUI(_ light: Light) {
    
}

private func renderTransformUI(_ transform: Transform) {
    
}

private func renderMaterialUI(_ material: GPUBufferElement<Material>, name: String) {
    if(igCollapsingHeader(label: name)) {
        
        material.withElement { material in
            let albedo = material.albedo
            igValueColor("Albedo", ImVec4(x: albedo.x, y: albedo.y, z: albedo.z, w: 1))
            
            let f0 = material.f0
            igValueColor("F0", ImVec4(x: f0.x, y: f0.y, z: f0.z, w: 1))
            
            igColorEdit3("Base Colour", &material.baseColour.x)
            igColorEdit3("Emissive", &material.emissive.x)
            
            _ = igSliderFloat(label: "Smoothness", value: &material.smoothness, vMin: 0.0, vMax: 0.999);
            _ = igSliderFloat(label: "Metal Mask", value: &material.metalMask, vMin: 0, vMax: 1);
            if material.metalMask < 1.0 {
                _ = igSliderFloat(label: "Reflectance", value: &material.reflectance, vMin: 0, vMax: 1.0);
                
            }
        }
    }
}


private final class ImGui : WindowInputDelegate {
    fileprivate var _lastTime = 0.0;
    fileprivate static var _fontTexture : GLuint = 0;
    fileprivate static var _shader : Shader! = nil;
    fileprivate static var _attribLocationTex : GLint = 0, _attribLocationProjMtx : GLint = 0;
    fileprivate static var _attribLocationPosition : GLint = 0, _attribLocationUV : GLint = 0, _attribLocationColor : GLint = 0;
    fileprivate static var _VBOHandle : GLuint = 0,_VAOHandle : GLuint = 0, _elementsHandle : GLuint = 0;
    
    fileprivate let window : PBWindow
    
    init(window: PBWindow) {
        self.window = window
        let io = igGetIO()
        
        let onFramebufferResize : PBWindow.OnFramebufferResize = { (width, height) in
            let windowSize = window.dimensions
            
            let displaySize = ImVec2(x: Float(windowSize.width), y: Float(windowSize.height))
            io?.pointee.DisplaySize = displaySize
            io?.pointee.DisplayFramebufferScale = ImVec2(x: Float(width) / Float(windowSize.width), y: Float(height) / Float(windowSize.height));
        }
        
        onFramebufferResize(window.pixelDimensions.width, window.pixelDimensions.height)
        window.registerForFramebufferResize(onFramebufferResize)
        
        window.inputDelegates.append(self)
        
        let keyMap = withUnsafeMutablePointer(to: &io!.pointee.KeyMap) { return $0.withMemoryRebound(to: Int32.self, capacity: 19, { return $0 }) }
        keyMap[Int(ImGuiKey_Tab.rawValue)] = GLFW_KEY_TAB;                         // Keyboard mapping. ImGui will use those indices to peek into the io.KeyDown[] array.
        keyMap[Int(ImGuiKey_LeftArrow.rawValue)] = GLFW_KEY_LEFT;
        keyMap[Int(ImGuiKey_RightArrow.rawValue)] = GLFW_KEY_RIGHT;
        keyMap[Int(ImGuiKey_UpArrow.rawValue)] = GLFW_KEY_UP;
        keyMap[Int(ImGuiKey_DownArrow.rawValue)] = GLFW_KEY_DOWN;
        keyMap[Int(ImGuiKey_PageUp.rawValue)] = GLFW_KEY_PAGE_UP;
        keyMap[Int(ImGuiKey_PageDown.rawValue)] = GLFW_KEY_PAGE_DOWN;
        keyMap[Int(ImGuiKey_Home.rawValue)] = GLFW_KEY_HOME;
        keyMap[Int(ImGuiKey_End.rawValue)] = GLFW_KEY_END;
        keyMap[Int(ImGuiKey_Delete.rawValue)] = GLFW_KEY_DELETE;
        keyMap[Int(ImGuiKey_Backspace.rawValue)] = GLFW_KEY_BACKSPACE;
        keyMap[Int(ImGuiKey_Enter.rawValue)] = GLFW_KEY_ENTER;
        keyMap[Int(ImGuiKey_Escape.rawValue)] = GLFW_KEY_ESCAPE;
        keyMap[Int(ImGuiKey_A.rawValue)] = GLFW_KEY_A;
        keyMap[Int(ImGuiKey_C.rawValue)] = GLFW_KEY_C;
        keyMap[Int(ImGuiKey_V.rawValue)] = GLFW_KEY_V;
        keyMap[Int(ImGuiKey_X.rawValue)] = GLFW_KEY_X;
        keyMap[Int(ImGuiKey_Y.rawValue)] = GLFW_KEY_Y;
        keyMap[Int(ImGuiKey_Z.rawValue)] = GLFW_KEY_Z;
        
        io?.pointee.RenderDrawListsFn = { data in
            ImGui.renderDrawLists(drawData: &data!.pointee)
        };
        
    }
    
    func keyAction(key: InputKey, action: InputAction, modifiers: InputModifiers) {
        let io = igGetIO()
        
        let KeysDown = withUnsafeMutablePointer(to: &io!.pointee.KeysDown) { return $0.withMemoryRebound(to: Int32.self, capacity: 512, { return $0 }) }
        
        if (action == .press) {
            KeysDown[Int(key.rawValue)] = 1;
        }
        if (action == .release) {
            KeysDown[Int(key.rawValue)] = 0;
        }
        
        io?.pointee.KeyCtrl = modifiers.contains(InputModifiers.Control)
        io?.pointee.KeyShift = modifiers.contains(InputModifiers.Shift)
        io?.pointee.KeyAlt = modifiers.contains(InputModifiers.Alt)
        io?.pointee.KeySuper = modifiers.contains(InputModifiers.Super)
    }
    
    func mouseAction(position: (x: Double, y: Double), button: MouseButton, action: InputAction, modifiers: InputModifiers) {
        let io = igGetIO()
        
        if window.hasFocus {
            io?.pointee.MousePos = ImVec2(x: Float(position.x), y: Float(position.y));
        } else {
            io?.pointee.MousePos = ImVec2(x: -1,y: -1);
        }
        
        let MouseDown = withUnsafeMutablePointer(to: &io!.pointee.MouseDown) { return $0.withMemoryRebound(to: Int32.self, capacity: 3, { return $0 }) }
        
        if action == .press {
            MouseDown[Int(button.rawValue)] = 1
        } else if action == .release {
            MouseDown[Int(button.rawValue)] = 0
        }
    }
    
    func mouseMove(position: (x: Double, y: Double), delta: (x: Double, y: Double)) {
        let io = igGetIO()
        
        if window.hasFocus {
            io?.pointee.MousePos = ImVec2(x: Float(position.x), y: Float(position.y));
        } else {
            io?.pointee.MousePos = ImVec2(x: -1,y: -1);
        }
    }
    
    func scroll(offsets: (x: Double, y: Double)) {
        let io = igGetIO()
        io?.pointee.MouseWheel += Float(offsets.y);
    }
    
    func char(character: UnicodeScalar) {
        ImGuiIO_AddInputCharacter(UInt16(character.value))
    }
    
    fileprivate func render() {
        igRender()
    }
    
    fileprivate func newFrame() {
        if (ImGui._fontTexture == 0) {
            _ = ImGui.createDeviceObjects()
        }
        
        let io = igGetIO()
        
        // Setup time step
        let current_time =  window.currentTime
        io?.pointee.DeltaTime = _lastTime > 0.0 ? Float(current_time - _lastTime) : Float(1.0/60.0);
        _lastTime = current_time;
        
        // Hide OS mouse cursor if ImGui is drawing it
        self.window.shouldHideCursor = io?.pointee.MouseDrawCursor ?? false
        
        // Start the frame
        igNewFrame();
    }
    
    
    fileprivate static func createDeviceObjects() -> Bool
    {
        // Backup GL state
        var last_texture = GLint(0), last_array_buffer = GLint(0), last_vertex_array  = GLint(0);
        glGetIntegerv(GL_TEXTURE_BINDING_2D, &last_texture);
        glGetIntegerv(GL_ARRAY_BUFFER_BINDING, &last_array_buffer);
        glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &last_vertex_array);
        
        let vertex_shader =
            "#version 330\n" +
                "uniform mat4 ProjMtx;\n" +
                "in vec2 Position;\n" +
                "in vec2 UV;\n" +
                "in vec4 Color;\n" +
                "out vec2 Frag_UV;\n" +
                "out vec4 Frag_Color;\n" +
                "void main()\n" +
                "{\n" +
                "   Frag_UV = UV;\n" +
                "   Frag_Color = Color;\n" +
                "   gl_Position = ProjMtx * vec4(Position.xy,0,1);\n" +
        "}\n";
        
        let fragment_shader =
            "#version 330\n" +
                "uniform sampler2D Texture;\n" +
                "in vec2 Frag_UV;\n" +
                "in vec4 Frag_Color;\n" +
                "out vec4 Out_Color;\n" +
                "void main()\n" +
                "{\n" +
                "   Out_Color = Frag_Color * texture( Texture, Frag_UV.st);\n" +
        "}\n";
        
        _shader = Shader(withVertexShader: vertex_shader, fragmentShader: fragment_shader)
        
        _attribLocationTex = glGetUniformLocation(_shader.glProgramRef, "Texture");
        _attribLocationProjMtx = glGetUniformLocation(_shader.glProgramRef, "ProjMtx");
        _attribLocationPosition = glGetAttribLocation(_shader.glProgramRef, "Position");
        _attribLocationUV = glGetAttribLocation(_shader.glProgramRef, "UV");
        _attribLocationColor = glGetAttribLocation(_shader.glProgramRef, "Color");
        
        glGenBuffers(1, &_VBOHandle);
        glGenBuffers(1, &_elementsHandle);
        
        glGenVertexArrays(1, &_VAOHandle);
        glBindVertexArray(_VAOHandle);
        glBindBuffer(GL_ARRAY_BUFFER, _VBOHandle);
        glEnableVertexAttribArray(GLuint(_attribLocationPosition));
        glEnableVertexAttribArray(GLuint(_attribLocationUV));
        glEnableVertexAttribArray(GLuint(_attribLocationColor));
        
        var posOffset : UnsafeMutableRawPointer? = nil
        var uvOffset : UnsafeMutableRawPointer? = nil
        var colOffset : UnsafeMutableRawPointer? = nil
        ImDrawVert_Offsets(&posOffset, &uvOffset, &colOffset)
        
        let drawVertSize = GLsizei(MemoryLayout<ImDrawVert>.size)
        glVertexAttribPointer(GLuint(_attribLocationPosition), 2, GL_FLOAT, false, drawVertSize, posOffset);
        glVertexAttribPointer(GLuint(_attribLocationUV), 2, GL_FLOAT, false, drawVertSize, uvOffset);
        glVertexAttribPointer(GLuint(_attribLocationColor), 4, GL_UNSIGNED_BYTE, true, drawVertSize, colOffset);
        
        self.createFontTexture()
        
        // Restore modified GL state
        glBindTexture(GL_TEXTURE_2D, GLuint(last_texture));
        glBindBuffer(GL_ARRAY_BUFFER, GLuint(last_array_buffer));
        glBindVertexArray(GLuint(last_vertex_array));
        
        return true;
    }
    
    static func createFontTexture() {
        // Build texture atlas
        let io = igGetIO();
        var pixels : UnsafeMutablePointer<UInt8>? = nil;
        var width : Int32 = 0, height : Int32 = 0;
        var bytesPerPixel : Int32 = 0
        ImFontAtlas_GetTexDataAsRGBA32(io?.pointee.Fonts, &pixels, &width, &height, &bytesPerPixel) // Load as RGBA 32-bits for OpenGL3 demo because it is more likely to be compatible with user's existing shader.
        
        // Upload texture to graphics system
        var last_texture = GLint(0);
        glGetIntegerv(GL_TEXTURE_BINDING_2D, &last_texture);
        glGenTextures(1, &_fontTexture);
        glBindTexture(GL_TEXTURE_2D, _fontTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
        
        // Store our identifier
        io?.pointee.Fonts.pointee.TexID = UnsafeMutableRawPointer(bitPattern: Int(_fontTexture));
        
        // Restore state
        glBindTexture(GL_TEXTURE_2D, GLuint(last_texture));
    }
    
    static func renderDrawLists(drawData: inout ImDrawData) {
        // Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
        let io = igGetIO()!.pointee;
        let fb_width = GLsizei(io.DisplaySize.x * io.DisplayFramebufferScale.x);
        let fb_height = GLsizei(io.DisplaySize.y * io.DisplayFramebufferScale.y);
        if (fb_width == 0 || fb_height == 0) {
            return;
        }
        
        ImDrawData_ScaleClipRects(&drawData, io.DisplayFramebufferScale);
        
        // Setup render state: alpha-blending enabled, no face culling, no depth testing, scissor enabled
        glEnable(GL_BLEND);
        glBlendEquation(GL_FUNC_ADD);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDisable(GL_CULL_FACE);
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_SCISSOR_TEST);
        glActiveTexture(GL_TEXTURE0);
        
        // Setup viewport, orthographic projection matrix
        glViewport(0, 0, fb_width, fb_height);
        let ortho_projection : [Float] = [
            2.0/Float(io.DisplaySize.x), 0.0,                   0.0, 0.0 ,
            0.0,                  2.0/Float(-io.DisplaySize.y), 0.0, 0.0 ,
            0.0,                  0.0,                  -1.0, 0.0 ,
            -1.0,                  1.0,                   0.0, 1.0 ,
            ];
        glUseProgram(_shader.glProgramRef);
        glUniform1i(_attribLocationTex, 0);
        glUniformMatrix4fv(_attribLocationProjMtx, 1, false, ortho_projection);
        glBindVertexArray(_VAOHandle);
        
        for n in 0..<drawData.CmdListsCount
        {
            let cmd_list = drawData.CmdLists.advanced(by: Int(n)).pointee!
            var idx_buffer_offset = 0;
            
            glBindBuffer(GL_ARRAY_BUFFER, _VBOHandle);
            glBufferData(GL_ARRAY_BUFFER, Int(cmd_list.pointee.VtxBuffer.Size) * MemoryLayout<ImDrawVert>.size, cmd_list.pointee.VtxBuffer.Data, GL_STREAM_DRAW);
            
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _elementsHandle);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, Int(cmd_list.pointee.IdxBuffer.Size) * MemoryLayout<ImDrawIdx>.size, cmd_list.pointee.IdxBuffer.Data, GL_STREAM_DRAW);
            
            for i in 0..<Int(cmd_list.pointee.CmdBuffer.Size) {
                let pcmd = cmd_list.pointee.CmdBuffer.Data.assumingMemoryBound(to: ImDrawCmd.self).advanced(by: i)
                if ((pcmd.pointee.UserCallback) != nil)
                {
                    pcmd.pointee.UserCallback(cmd_list, pcmd);
                }
                else
                {
                    glBindTexture(GL_TEXTURE_2D, GLuint(unsafeBitCast(pcmd.pointee.TextureId, to: intptr_t.self)));
                    glScissor(GLint(pcmd.pointee.ClipRect.x), GLint(Float(fb_height) - pcmd.pointee.ClipRect.w), GLint(pcmd.pointee.ClipRect.z - pcmd.pointee.ClipRect.x), GLint(pcmd.pointee.ClipRect.w - pcmd.pointee.ClipRect.y));
                    glDrawElements(GL_TRIANGLES, GLsizei(pcmd.pointee.ElemCount), MemoryLayout<ImDrawIdx>.size == 2 ? GL_UNSIGNED_SHORT : GL_UNSIGNED_INT, UnsafePointer<ImDrawIdx>(bitPattern:  idx_buffer_offset * MemoryLayout<ImDrawIdx>.size));
                }
                idx_buffer_offset += Int(pcmd.pointee.ElemCount);
            }
        }
        
    }
    
    static func shutdown() {
        invalidateDeviceObjects();
        igShutdown();
    }
    
    static func invalidateDeviceObjects()
    {
        if (_VAOHandle != 0) { glDeleteVertexArrays(1, &_VAOHandle); }
        if (_VBOHandle != 0) { glDeleteBuffers(1, &_VBOHandle); }
        if (_elementsHandle != 0) { glDeleteBuffers(1, &_elementsHandle); }
        _shader = nil
        
        if (_fontTexture != 0)
        {
            glDeleteTextures(1, &_fontTexture);
            igGetIO().pointee.Fonts.pointee.TexID = nil;
            _fontTexture = 0;
        }
    }
    
    
}

//func igTextColoredV(color: ImVec4, format: String, args: [CVarArg] = []) {
//    return withVaList(args) { (pointer: CVaListPointer) -> () in
//        return NSPredicate(format: format, arguments: pointer)
//    }
//}

func igCombo<T: Sequence>(label: String, currentItem: inout Int, items: T, heightInItems: Int32 = -1) where T.Iterator.Element == String {
    let cItems = items.joined(separator: "\0") + "\0"
    
    var cCurrentItem = Int32(currentItem)
    igCombo2(label, &cCurrentItem, cItems, heightInItems)
    currentItem = Int(cCurrentItem)
}

func igDragFloat(label: String, value: inout Float, vSpeed: Float, vMin: Float, vMax: Float, displayFormat: String = "%.3f", power: Float = 1.0) -> Bool {
    return igDragFloat(label, &value, vSpeed, vMin, vMax, displayFormat, power)
}

func igSliderFloat(label: String, value: inout Float, vMin: Float, vMax: Float, displayFormat: String = "%.3f", power: Float = 1.0) -> Bool {
    return igSliderFloat(label, &value, vMin, vMax, displayFormat, power)
}

func igFloat(label: String, value: inout Float, decimalPrecision: Int32 = 3) -> Bool {
    return igInputFloat2(label, &value, decimalPrecision, 0)
}

func igButton(label: String, size: ImVec2 = ImVec2(x: 0, y: 0)) -> Bool {
    return igButton(label, size)
}

func igCollapsingHeader(label: String, displayFrame: Bool = false, defaultOpen: Bool = false) -> Bool{
    return igCollapsingHeader(label, label, displayFrame, defaultOpen)
}

func igBegin(label: String, didOpen: inout Bool, flags: GUIWindowFlags = GUIWindowFlags.Default) -> Bool {
    return igBegin(label, &didOpen, flags.rawValue);
}
