//
//  ImGui.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 25/05/16.
//
//

import Foundation
import PBRenderer
import CPBRendererLibs
import SGLOpenGL
import CGLFW3

// Data
private var  g_Window : OpaquePointer! = nil;
private var       g_Time = 0.0;
private var         g_MousePressed = [ false, false, false ];
private var        g_MouseWheel : Float = 0.0;
private var       g_FontTexture : GLuint = 0;
private var          _shader : Shader! = nil;
private var          g_AttribLocationTex : GLint = 0, g_AttribLocationProjMtx : GLint = 0;
private var          g_AttribLocationPosition : GLint = 0, g_AttribLocationUV : GLint = 0, g_AttribLocationColor : GLint = 0;
private var g_VboHandle : GLuint = 0, g_VaoHandle : GLuint = 0, g_ElementsHandle : GLuint = 0;

// This is the main rendering function that you have to implement and provide to ImGui (via setting up 'RenderDrawListsFn' in the ImGuiIO structure)
// If text or lines are blurry when integrating ImGui in your engine:
// - in your Render function, try translating your projection matrix by (0.50.5f) or (0.3750.375f)
func ImGui_ImplGlfw_RenderDrawLists(draw_data: inout ImDrawData) {
    // Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
    let io = igGetIO()!.pointee;
    let fb_width = GLsizei(io.DisplaySize.x * io.DisplayFramebufferScale.x);
    let fb_height = GLsizei(io.DisplaySize.y * io.DisplayFramebufferScale.y);
    if (fb_width == 0 || fb_height == 0) {
        return;
    }
    
    ImDrawData_ScaleClipRects(&draw_data, io.DisplayFramebufferScale);
    
    // Backup GL state
    var last_program = GLint(0); glGetIntegerv(GL_CURRENT_PROGRAM, &last_program);
    var last_texture = GLint(0); glGetIntegerv(GL_TEXTURE_BINDING_2D, &last_texture);
    var last_array_buffer = GLint(0); glGetIntegerv(GL_ARRAY_BUFFER_BINDING, &last_array_buffer);
    var last_element_array_buffer = GLint(0); glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, &last_element_array_buffer);
    var last_vertex_array = GLint(0); glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &last_vertex_array);
    var last_blend_src = GLint(0); glGetIntegerv(GL_BLEND_SRC, &last_blend_src);
    var last_blend_dst = GLint(0); glGetIntegerv(GL_BLEND_DST, &last_blend_dst);
    var last_blend_equation_rgb = GLint(0); glGetIntegerv(GL_BLEND_EQUATION_RGB, &last_blend_equation_rgb);
    var last_blend_equation_alpha = GLint(0); glGetIntegerv(GL_BLEND_EQUATION_ALPHA, &last_blend_equation_alpha);
    var last_viewport = [GLint](repeating: 0, count: 4); glGetIntegerv(GL_VIEWPORT, &last_viewport);
    let last_enable_blend = glIsEnabled(GL_BLEND);
    let last_enable_cull_face = glIsEnabled(GL_CULL_FACE);
    let last_enable_depth_test = glIsEnabled(GL_DEPTH_TEST);
    let last_enable_scissor_test = glIsEnabled(GL_SCISSOR_TEST);
    
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
    glUniform1i(g_AttribLocationTex, 0);
    glUniformMatrix4fv(g_AttribLocationProjMtx, 1, false, ortho_projection);
    glBindVertexArray(g_VaoHandle);
    
    for n in 0..<draw_data.CmdListsCount
    {
        let cmd_list = draw_data.CmdLists.advanced(by: Int(n)).pointee!
        var idx_buffer_offset : UnsafePointer<ImDrawIdx>? = nil;
        
        glBindBuffer(GL_ARRAY_BUFFER, g_VboHandle);
        glBufferData(GL_ARRAY_BUFFER, Int(cmd_list.pointee.VtxBuffer.Size) * sizeof(ImDrawVert), cmd_list.pointee.VtxBuffer.Data, GL_STREAM_DRAW);
        
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_ElementsHandle);
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
                glDrawElements(GL_TRIANGLES, GLsizei(pcmd.pointee.ElemCount), sizeof(ImDrawIdx) == 2 ? GL_UNSIGNED_SHORT : GL_UNSIGNED_INT, idx_buffer_offset);
            }
            idx_buffer_offset = idx_buffer_offset?.advanced(by: Int(pcmd.pointee.ElemCount));
        }
    }
    
    // Restore modified GL state
    glUseProgram(GLuint(last_program));
    glBindTexture(GL_TEXTURE_2D, GLuint(last_texture));
    glBindVertexArray(GLuint(last_vertex_array));
    glBindBuffer(GL_ARRAY_BUFFER, GLuint(last_array_buffer));
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, GLuint(last_element_array_buffer));
    glBlendEquationSeparate(last_blend_equation_rgb, last_blend_equation_alpha);
    glBlendFunc(last_blend_src, last_blend_dst);
    if (last_enable_blend) {  glEnable(GL_BLEND); } else { glDisable(GL_BLEND); }
    if (last_enable_cull_face) { glEnable(GL_CULL_FACE); } else { glDisable(GL_CULL_FACE); }
    if (last_enable_depth_test) {glEnable(GL_DEPTH_TEST); } else { glDisable(GL_DEPTH_TEST); }
    if (last_enable_scissor_test) { glEnable(GL_SCISSOR_TEST); } else { glDisable(GL_SCISSOR_TEST); }
    glViewport(last_viewport[0], last_viewport[1], last_viewport[2], last_viewport[3]);
}
//
//func ImGui_ImplGlfwGL3_GetClipboardText() ->
//{
//    return glfwGetClipboardString(g_Window);
//}
//
//static void ImGui_ImplGlfwGL3_SetClipboardText(const char* text)
//{
//    glfwSetClipboardString(g_Window, text);
//}
//
//void ImGui_ImplGlfwGL3_MouseButtonCallback(GLFWwindow*, int button, int action, int /*mods*/)
//{
//    if (action == GLFW_PRESS && button >= 0 && button < 3)
//    g_MousePressed[button] = true;
//}
//
//void ImGui_ImplGlfwGL3_ScrollCallback(GLFWwindow*, double /*xoffset*/, double yoffset)
//{
//    g_MouseWheel += (float)yoffset; // Use fractional mouse wheel, 1.0 unit 5 lines.
//}
//
//void ImGui_ImplGlfwGL3_KeyCallback(GLFWwindow*, int key, int, int action, int mods)
//{
//    ImGuiIO& io = ImGui::GetIO();
//    if (action == GLFW_PRESS)
//    io.KeysDown[key] = true;
//    if (action == GLFW_RELEASE)
//    io.KeysDown[key] = false;
//    
//    (void)mods; // Modifiers are not reliable across systems
//    io.KeyCtrl = io.KeysDown[GLFW_KEY_LEFT_CONTROL] || io.KeysDown[GLFW_KEY_RIGHT_CONTROL];
//    io.KeyShift = io.KeysDown[GLFW_KEY_LEFT_SHIFT] || io.KeysDown[GLFW_KEY_RIGHT_SHIFT];
//    io.KeyAlt = io.KeysDown[GLFW_KEY_LEFT_ALT] || io.KeysDown[GLFW_KEY_RIGHT_ALT];
//    io.KeySuper = io.KeysDown[GLFW_KEY_LEFT_SUPER] || io.KeysDown[GLFW_KEY_RIGHT_SUPER];
//}
//
//void ImGui_ImplGlfwGL3_CharCallback(GLFWwindow*, unsigned int c)
//{
//    ImGuiIO& io = ImGui::GetIO();
//    if (c > 0 && c < 0x10000)
//    io.AddInputCharacter((unsigned short)c);
//}

func ImGui_ImplGlfwGL3_CreateFontsTexture() -> Bool
    {
        // Build texture atlas
        let io = igGetIO();
        var pixels : UnsafeMutablePointer<UInt8>? = nil;
        var width : Int32 = 0, height : Int32 = 0;
        var bytesPerPixel : Int32 = 0
        ImFontAtlas_GetTexDataAsRGBA32(io?.pointee.Fonts, &pixels, &width, &height, &bytesPerPixel) // Load as RGBA 32-bits for OpenGL3 demo because it is more likely to be compatible with user's existing shader.
        
        // Upload texture to graphics system
        var last_texture = GLint(0);
        glGetIntegerv(GL_TEXTURE_BINDING_2D, &last_texture);
        glGenTextures(1, &g_FontTexture);
        glBindTexture(GL_TEXTURE_2D, g_FontTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
        
        // Store our identifier
        io?.pointee.Fonts.pointee.TexID = UnsafeMutablePointer<Void>(bitPattern: Int(g_FontTexture));
        
        // Restore state
        glBindTexture(GL_TEXTURE_2D, GLuint(last_texture));
        
        return true;
}

func ImGui_ImplGlfwGL3_CreateDeviceObjects() -> Bool
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
        
        g_AttribLocationTex = glGetUniformLocation(_shader.glProgramRef, "Texture");
        g_AttribLocationProjMtx = glGetUniformLocation(_shader.glProgramRef, "ProjMtx");
        g_AttribLocationPosition = glGetAttribLocation(_shader.glProgramRef, "Position");
        g_AttribLocationUV = glGetAttribLocation(_shader.glProgramRef, "UV");
        g_AttribLocationColor = glGetAttribLocation(_shader.glProgramRef, "Color");
        
        glGenBuffers(1, &g_VboHandle);
        glGenBuffers(1, &g_ElementsHandle);
        
        glGenVertexArrays(1, &g_VaoHandle);
        glBindVertexArray(g_VaoHandle);
        glBindBuffer(GL_ARRAY_BUFFER, g_VboHandle);
        glEnableVertexAttribArray(GLuint(g_AttribLocationPosition));
        glEnableVertexAttribArray(GLuint(g_AttribLocationUV));
        glEnableVertexAttribArray(GLuint(g_AttribLocationColor));
        
        var posOffset : UnsafeMutablePointer<Void>? = nil
        var uvOffset : UnsafeMutablePointer<Void>? = nil
        var colOffset : UnsafeMutablePointer<Void>? = nil
        ImDrawVert_Offsets(&posOffset, &uvOffset, &colOffset)
        
        let drawVertSize = GLsizei(sizeof(ImDrawVert))
        glVertexAttribPointer(GLuint(g_AttribLocationPosition), 2, GL_FLOAT, false, drawVertSize, posOffset);
        glVertexAttribPointer(GLuint(g_AttribLocationUV), 2, GL_FLOAT, false, drawVertSize, uvOffset);
        glVertexAttribPointer(GLuint(g_AttribLocationColor), 4, GL_UNSIGNED_BYTE, true, drawVertSize, colOffset);
        
        ImGui_ImplGlfwGL3_CreateFontsTexture();
        
        // Restore modified GL state
        glBindTexture(GL_TEXTURE_2D, GLuint(last_texture));
        glBindBuffer(GL_ARRAY_BUFFER, GLuint(last_array_buffer));
        glBindVertexArray(GLuint(last_vertex_array));
        
        return true;
}

func ImGui_ImplGlfwGL3_InvalidateDeviceObjects()
    {
        if (g_VaoHandle != 0) { glDeleteVertexArrays(1, &g_VaoHandle); }
        if (g_VboHandle != 0) { glDeleteBuffers(1, &g_VboHandle); }
        if (g_ElementsHandle != 0) { glDeleteBuffers(1, &g_ElementsHandle); }
        _shader = nil
        
        if (g_FontTexture != 0)
        {
            glDeleteTextures(1, &g_FontTexture);
            igGetIO().pointee.Fonts.pointee.TexID = nil;
            g_FontTexture = 0;
        }
}

func    ImGui_ImplGlfwGL3_Init(window: OpaquePointer, install_callbacks: Bool) -> Bool {
    g_Window = window;
    
    let io = igGetIO()
    let keyMap = withUnsafeMutablePointer(&io!.pointee.KeyMap) { return UnsafeMutableBufferPointer<Int32>(start: UnsafeMutablePointer<Int32>($0), count: 18) }
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
        ImGui_ImplGlfw_RenderDrawLists(draw_data: &data!.pointee)
    };       // Alternatively you can set this to NULL and call ImGui::GetDrawData() after ImGui::Render() to get the same ImDrawData pointer.
//    io.SetClipboardTextFn = ImGui_ImplGlfwGL3_SetClipboardText;
//    io.GetClipboardTextFn = ImGui_ImplGlfwGL3_GetClipboardText;
//
//if (install_callbacks)
//{
//    glfwSetMouseButtonCallback(window, ImGui_ImplGlfwGL3_MouseButtonCallback);
//    glfwSetScrollCallback(window, ImGui_ImplGlfwGL3_ScrollCallback);
//    glfwSetKeyCallback(window, ImGui_ImplGlfwGL3_KeyCallback);
//    glfwSetCharCallback(window, ImGui_ImplGlfwGL3_CharCallback);
//}
    return true;
}

func ImGui_ImplGlfwGL3_Shutdown()
    {
        ImGui_ImplGlfwGL3_InvalidateDeviceObjects();
        igShutdown();
}

func ImGui_ImplGlfwGL3_NewFrame()
    {
        if (g_FontTexture == 0) {
            ImGui_ImplGlfwGL3_CreateDeviceObjects();
        }
        
        let io = igGetIO()
        
        // Setup display size (every frame to accommodate for window resizing)
        var w = GLint(0), h = GLint(0);
        var display_w = GLint(0), display_h = GLint(0);
        glfwGetWindowSize(g_Window, &w, &h);
        glfwGetFramebufferSize(g_Window, &display_w, &display_h);
        let displaySize = ImVec2(x: Float(w), y: Float(h))
        io?.pointee.DisplaySize = displaySize
        io?.pointee.DisplayFramebufferScale = ImVec2(x: w > 0 ? (Float(display_w) / Float(w)) : 0, y: h > 0 ? (Float(display_h) / Float(h)) : 0);
        
        // Setup time step
        let current_time =  glfwGetTime();
        io?.pointee.DeltaTime = g_Time > 0.0 ? Float(current_time - g_Time) : Float(1.0/60.0);
        g_Time = current_time;
        
        // Setup inputs
        // (we already got mouse wheel, keyboard keys & characters from glfw callbacks polled in glfwPollEvents())
        if (glfwGetWindowAttrib(g_Window, GLFW_FOCUSED) != 0) {
            var mouse_x = 0.0, mouse_y = 0.0;
            glfwGetCursorPos(g_Window, &mouse_x, &mouse_y);
            io?.pointee.MousePos = ImVec2(x: Float(mouse_x), y: Float(mouse_y));   // Mouse position in screen coordinates (set to -1,-1 if no mouse / on another screen, etc.)
        }
        else
        {
            io?.pointee.MousePos = ImVec2(x: -1,y: -1);
        }
        
        let MouseDown = withUnsafeMutablePointer(&io!.pointee.MouseDown) { return UnsafeMutableBufferPointer<Int32>(start: UnsafeMutablePointer<Int32>($0), count: 3) }
        
        for i in 0..<3
        {
            MouseDown[i] = (g_MousePressed[i] || glfwGetMouseButton(g_Window, Int32(i)) != 0) ? 1 : 0;    // If a mouse press event came, always pass it as "mouse held this frame", so we don't miss click-release events that are shorter than 1 frame.
            g_MousePressed[i] = false;
        }
        
        io?.pointee.MouseWheel = g_MouseWheel;
        g_MouseWheel = 0.0;
        
        // Hide OS mouse cursor if ImGui is drawing it
        glfwSetInputMode(g_Window, GLFW_CURSOR, io?.pointee.MouseDrawCursor != 0 ? GLFW_CURSOR_HIDDEN : GLFW_CURSOR_NORMAL);
        
        // Start the frame
        igNewFrame();
}
