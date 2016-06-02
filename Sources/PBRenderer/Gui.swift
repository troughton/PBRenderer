//
//  Gui.swift
//  PBRenderer
//
//  Created by Joseph Bennett on 2/06/16.
//
//

import Foundation
import CPBRendererLibs

public typealias UIDrawFunction = () -> Void

public class Gui {
    public var drawFunctions : [UIDrawFunction] = []
    
    public init(glfwWindow: OpaquePointer) {
        ImGui_ImplGlfwGL3_Init(window: glfwWindow, install_callbacks: true);
    }
    
    deinit {
        ImGui_ImplGlfwGL3_Shutdown();
    }
    
    public func render() {
        ImGui_ImplGlfwGL3_NewFrame();

        drawFunctions.forEach { (drawFunction) in
            drawFunction();
        }
        
        igRender();
    }
}


public func renderCameraUI(camera: Camera) {
    igBegin(name: "Camera - \(camera.name!)")
    
    igText("Exposure: \(camera.exposure)")
    igSliderFloat(label: "Aperture", value: &camera.aperture, vMin: 0.7, vMax: 200.0);
    igSliderFloat(label: "Shutter Time", value: &camera.shutterTime, vMin: 0, vMax: 10);
    igSliderFloat(label: "ISO", value: &camera.ISO, vMin: 0, vMax: 2000);

    igEnd()
}

public func renderFPSCounter() {
    igSetNextWindowPos(ImVec2(x: 10, y: 10), Int32(ImGuiSetCond_FirstUseEver.rawValue))
    
    igBegin(name: "Stats")
    igText(String(format: "Application average %.3f ms/frame (%.1f FPS)", 1000.0 / igGetIO().pointee.Framerate, igGetIO().pointee.Framerate))
    igEnd()
}

public func renderTestUI() {
    igSetNextWindowPos(ImVec2(x: 650, y: 20), Int32(ImGuiSetCond_FirstUseEver.rawValue));
    var show_test_window = true
    withUnsafeMutablePointer(&show_test_window) { (opened) -> () in
        igShowTestWindow(opened)
    }
}