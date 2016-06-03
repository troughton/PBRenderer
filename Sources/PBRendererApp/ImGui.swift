//
//  ImGui.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 25/05/16.
//
//

import Foundation
import CPBRendererLibs
import SGLOpenGL
import CGLFW3


public struct GuiWindowFlags : OptionSet {
    public let rawValue : Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let Default = GuiWindowFlags(rawValue: 0)
    static let NoTitleBar = GuiWindowFlags(rawValue: 1 << 0)  // Disable title-bar
    static let NoResize = GuiWindowFlags(rawValue: 1 << 1) // Disable user resizing with the lower-right grip
    static let NoMove = GuiWindowFlags(rawValue: 1 << 2)   // Disable user moving the window
    static let NoScrollbar = GuiWindowFlags(rawValue: 1 << 3) // Disable scrollbars (window can still scroll with mouse or programatically)
    static let NoScrollWithMouse = GuiWindowFlags(rawValue: 1 << 4)  // Disable user vertically scrolling with mouse wheel
    static let NoCollapse = GuiWindowFlags(rawValue: 1 << 5)     // Disable user collapsing window by double-clicking on it
    static let AlwaysAutoResize = GuiWindowFlags(rawValue: 1 << 6)    // Resize every window to its content every frame
    static let ShowBorders = GuiWindowFlags(rawValue: 1 << 7)  // Show borders around windows and items
    static let NoSavedSettings  = GuiWindowFlags(rawValue: 1 << 8)    // Never load/save settings in .ini file
    static let NoInputs   = GuiWindowFlags(rawValue: 1 << 9)  // Disable catching mouse or keyboard inputs
    static let MenuBar      = GuiWindowFlags(rawValue: 1 << 10)   // Has a menu-bar
    static let HorizontalScrollbar    = GuiWindowFlags(rawValue: 1 << 11)   // Allow horizontal scrollbar to appear (off by default). You may use SetNextWindowContentSize(ImVec2(width,0.0f)); prior to calling Begin() to specify width. Read code in imgui_demo in the "Horizontal Scrolling" section.
    static let NoFocusOnAppearing    = GuiWindowFlags(rawValue: 1 << 12)   // Disable taking focus when transitioning from hidden to visible state
    static let NoBringToFrontOnFocus = GuiWindowFlags(rawValue: 1 << 13)    // Disable bringing window to front when taking focus (e.g. clicking on it or programatically giving it focus)
    static let AlwaysVerticalScrollbar = GuiWindowFlags(rawValue: 1 << 14)   // Always show vertical scrollbar (even if ContentSize.y < Size.y)
    static let AlwaysHorizontalScrollbar = GuiWindowFlags(rawValue: 1 << 15)    // Always show horizontal scrollbar (even if ContentSize.x < Size.x)
    static let AlwaysUseWindowPadding = GuiWindowFlags(rawValue: 1 << 16)   // Ensure child windows without border uses style.WindowPadding (ignored by default for non-
}

public typealias UIDrawFunction = (state: inout GUIDisplayState) -> Void

public final class GUI {
    public var drawFunctions : [UIDrawFunction] = []

    let window : PBWindow
    
    private var _displayState = GUIDisplayState()
    private let _imGui : IMGUI
    
    public init(window: PBWindow) {
        self.window = window
        _imGui = IMGUI(window: window)
    }
    
    public func render() {
        _imGui.newFrame()
        
        drawFunctions.forEach { (drawFunction) in
            drawFunction(state: &_displayState);
        }
        
        _imGui.render()
    }
    
    public static func shutdown() {
        IMGUI.shutdown()
    }
}


public struct GUIDisplayState {
    
}

public func renderTestUI(state: GUIDisplayState) {
    igSetNextWindowPos(ImVec2(x: 650, y: 20), Int32(ImGuiSetCond_FirstUseEver.rawValue));
    var show_test_window = true
    withUnsafeMutablePointer(&show_test_window) { (opened) -> () in
        igShowTestWindow(opened)
    }
}

public func renderCameraUI(state: inout GUIDisplayState, camera: Camera) {
    _ = igBegin(name: "Camera - \(camera.name!)")

    igText("Exposure: \(camera.exposure)")
    _ = igSliderFloat(label: "Aperture", value: &camera.aperture, vMin: 0.7, vMax: 200.0);
    _ = igSliderFloat(label: "Shutter Time", value: &camera.shutterTime, vMin: 0, vMax: 10);
    _ = igSliderFloat(label: "ISO", value: &camera.ISO, vMin: 0, vMax: 2000);

    igEnd()
}


private final class IMGUI : WindowInputDelegate {
    private var _lastTime = 0.0;
    private static var _fontTexture : GLuint = 0;
    private static var _shader : Shader! = nil;
    private static var _attribLocationTex : GLint = 0, _attribLocationProjMtx : GLint = 0;
    private static var _attribLocationPosition : GLint = 0, _attribLocationUV : GLint = 0, _attribLocationColor : GLint = 0;
    private static var _VBOHandle : GLuint = 0,_VAOHandle : GLuint = 0, _elementsHandle : GLuint = 0;
    
    private let window : PBWindow
    
    init(window: PBWindow) {
        self.window = window
        let io = igGetIO()
        
        let onFramebufferResize : PBWindow.OnFramebufferResize = { (width, height) in
            let windowSize = window.dimensions
            
            let displaySize = ImVec2(x: Float(windowSize.width), y: Float(windowSize.height))
            io?.pointee.DisplaySize = displaySize
            io?.pointee.DisplayFramebufferScale = ImVec2(x: Float(width) / Float(windowSize.width), y: Float(height) / Float(windowSize.height));
        }
        
        onFramebufferResize(width: window.dimensions.width, height: window.dimensions.height)
        window.registerForFramebufferResize(onResize: onFramebufferResize)
        
        window.inputDelegates.append(self)
        
        let keyMap = withUnsafeMutablePointer(&io!.pointee.KeyMap) { return UnsafeMutableBufferPointer<Int32>(start: UnsafeMutablePointer<Int32>($0), count: 19) }
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
            IMGUI.renderDrawLists(drawData: &data!.pointee)
        };

    }
    
    func keyAction(key: InputKey, action: InputAction, modifiers: InputModifiers) {
        let io = igGetIO()
        
        let KeysDown = withUnsafeMutablePointer(&io!.pointee.KeysDown) { return UnsafeMutableBufferPointer<Int32>(start: UnsafeMutablePointer<Int32>($0), count: 512) }
        
        if (action == .Press) {
            KeysDown[Int(key.rawValue)] = 1;
        }
        if (action == .Release) {
            KeysDown[Int(key.rawValue)] = 0;
        }
    
        io?.pointee.KeyCtrl = modifiers.contains(InputModifiers.Control) ? 1 : 0
        io?.pointee.KeyShift = modifiers.contains(InputModifiers.Shift) ? 1 : 0
        io?.pointee.KeyAlt = modifiers.contains(InputModifiers.Alt) ? 1 : 0
        io?.pointee.KeySuper = modifiers.contains(InputModifiers.Super) ? 1 : 0
    }
    
    func mouseAction(position: (x: Double, y: Double), button: MouseButton, action: InputAction, modifiers: InputModifiers) {
        let io = igGetIO()
        
        if window.hasFocus {
            io?.pointee.MousePos = ImVec2(x: Float(position.x), y: Float(position.y));
        } else {
            io?.pointee.MousePos = ImVec2(x: -1,y: -1);
        }
        
        let MouseDown = withUnsafeMutablePointer(&io!.pointee.MouseDown) { return UnsafeMutableBufferPointer<Int32>(start: UnsafeMutablePointer<Int32>($0), count: 3) }
        
        if action == .Press {
            MouseDown[Int(button.rawValue)] = 1
        } else if action == .Release {
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
    
    public func render() {
        igRender()
    }
    
    private func newFrame() {
        if (IMGUI._fontTexture == 0) {
            IMGUI.createDeviceObjects()
        }
       
        let io = igGetIO()
        
        // Setup time step
        let current_time =  window.currentTime
        io?.pointee.DeltaTime = _lastTime > 0.0 ? Float(current_time - _lastTime) : Float(1.0/60.0);
        _lastTime = current_time;
        
        // Hide OS mouse cursor if ImGui is drawing it
        self.window.shouldHideCursor = io?.pointee.MouseDrawCursor != 0
        
        // Start the frame
        igNewFrame();
    }
    
    
    private static func createDeviceObjects() -> Bool
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
        
        var posOffset : UnsafeMutablePointer<Void>? = nil
        var uvOffset : UnsafeMutablePointer<Void>? = nil
        var colOffset : UnsafeMutablePointer<Void>? = nil
        ImDrawVert_Offsets(&posOffset, &uvOffset, &colOffset)
        
        let drawVertSize = GLsizei(sizeof(ImDrawVert))
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
        io?.pointee.Fonts.pointee.TexID = UnsafeMutablePointer<Void>(bitPattern: Int(_fontTexture));
        
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
            glBufferData(GL_ARRAY_BUFFER, Int(cmd_list.pointee.VtxBuffer.Size) * sizeof(ImDrawVert), cmd_list.pointee.VtxBuffer.Data, GL_STREAM_DRAW);
            
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _elementsHandle);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, Int(cmd_list.pointee.IdxBuffer.Size) * sizeof(ImDrawIdx), cmd_list.pointee.IdxBuffer.Data, GL_STREAM_DRAW);
            
            for i in 0..<Int(cmd_list.pointee.CmdBuffer.Size) {
                let pcmd = UnsafePointer<ImDrawCmd>(cmd_list.pointee.CmdBuffer.Data).advanced(by: i)
                if ((pcmd.pointee.UserCallback) != nil)
                {
                    pcmd.pointee.UserCallback(cmd_list, pcmd);
                }
                else
                {
                    glBindTexture(GL_TEXTURE_2D, GLuint(unsafeBitCast(pcmd.pointee.TextureId, to: intptr_t.self)));
                    glScissor(GLint(pcmd.pointee.ClipRect.x), GLint(Float(fb_height) - pcmd.pointee.ClipRect.w), GLint(pcmd.pointee.ClipRect.z - pcmd.pointee.ClipRect.x), GLint(pcmd.pointee.ClipRect.w - pcmd.pointee.ClipRect.y));
                    glDrawElements(GL_TRIANGLES, GLsizei(pcmd.pointee.ElemCount), sizeof(ImDrawIdx) == 2 ? GL_UNSIGNED_SHORT : GL_UNSIGNED_INT, UnsafePointer<ImDrawIdx>(bitPattern:  idx_buffer_offset * sizeof(ImDrawIdx)));
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



func igCombo<T: Sequence where T.Iterator.Element == String>(label: String, currentItem: inout Int, items: T, heightInItems: Int32 = -1) {
    let cItems = items.joined(separator: "\0") + "\0"
    
    var cCurrentItem = Int32(currentItem)
    igCombo2(label, &cCurrentItem, cItems, heightInItems)
    currentItem = Int(cCurrentItem)
}

func igSliderFloat(label: String, value: inout Float, vMin: Float, vMax: Float, displayFormat: String = "%.3f", power: Float = 1.0) -> Bool {
    return igSliderFloat(label, &value, vMin, vMax, displayFormat, power)
}

//func igFloat(label: String, value: inout Float, vMin: Float, vMax: Float) -> Bool {
//    return igInputFloat(<#T##label: UnsafePointer<Int8>!##UnsafePointer<Int8>!#>, <#T##v: UnsafeMutablePointer<Float>!##UnsafeMutablePointer<Float>!#>, <#T##step: Float##Float#>, <#T##step_fast: Float##Float#>, <#T##decimal_precision: Int32##Int32#>, <#T##extra_flags: ImGuiInputTextFlags##ImGuiInputTextFlags#>)
//}

func igButton(label: String, size: ImVec2 = ImVec2(x: 0, y: 0)) -> Bool {
    return igButton(label, size)
}

func igCollapsingHeader(label: String, displayFrame: Bool = false, defaultOpen: Bool = false) -> Bool{
    return igCollapsingHeader(label, label, displayFrame, defaultOpen)
}

func igBegin(name: String, didOpen: Bool = false, flags: GuiWindowFlags = GuiWindowFlags.Default) -> Bool {
    var didOpenPointer = didOpen
    return igBegin(name, &didOpenPointer, flags.rawValue);
}

func ImGui_ImplGlfwGL3_Shutdown()
    {
      
}

