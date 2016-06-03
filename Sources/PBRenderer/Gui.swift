////
////  Gui.swift
////  PBRenderer
////
////  Created by Joseph Bennett on 2/06/16.
////
////
//
//import Foundation
//import CPBRendererLibs
//
//public typealias UIDrawFunction = () -> Void
//
//public final class Gui {
//    public var drawFunctions : [UIDrawFunction] = []
//    
//    public init(glfwWindow: OpaquePointer) {
//        ImGui_ImplGlfwGL3_Init(window: glfwWindow, install_callbacks: true);
//    }
//    
//    deinit {
//        ImGui_ImplGlfwGL3_Shutdown();
//    }
//    
//    public func render() {
//        ImGui_ImplGlfwGL3_NewFrame();
//
//        drawFunctions.forEach { (drawFunction) in
//            drawFunction();
//        }
//        
//        igRender();
//    }
//}
//
//public func renderCameraUI(camera: Camera) {
//    _ = igBegin(name: "Camera - \(camera.name!)")
//    
//    igText("Exposure: \(camera.exposure)")
//    _ = igSliderFloat(label: "Aperture", value: &camera.aperture, vMin: 0.7, vMax: 200.0);
//    _ = igSliderFloat(label: "Shutter Time", value: &camera.shutterTime, vMin: 0, vMax: 10);
//    _ = igSliderFloat(label: "ISO", value: &camera.ISO, vMin: 0, vMax: 2000);
//
//    igEnd()
//}
//
//private let lightTypes : [(String, LightType)] = [("Point", LightType.Point),
//                                                 ("Spot", LightType.Spot(innerCutoff: 0.1, outerCutoff: 1.0)),
//                                                 ("Directional", LightType.Directional),
//                                                 ("Sphere Area", LightType.SphereArea(radius: 1.0)),
//                                                 ("Disk Area", LightType.DiskArea(radius: 1.0))]
//var currentItem = 0
//
//public func renderLightEditor(light: Light) {
//    _ = igBegin(name: "Light - \(light.sceneNode.name!)")
//    
//    igCombo(label: "Type", currentItem: &currentItem, items: lightTypes.lazy.map { $0.0 })
//    
//    light.type = lightTypes[currentItem].1
//    
//    renderTransformPropertyEditor(transform: light.sceneNode.transform)
//    igEnd()
//}
//
//private func renderTransformPropertyEditor(transform: Transform) {
//    _ = igSliderFloat(label: "x", value: &transform.translation.x, vMin: -100, vMax: 100);
//    _ = igSliderFloat(label: "y", value: &transform.translation.y, vMin: -100, vMax: 100);
//    _ = igSliderFloat(label: "z", value: &transform.translation.z, vMin: -100, vMax: 100);
//}
//
//public func renderFPSCounter() {
//    igSetNextWindowPos(ImVec2(x: 10, y: 10), Int32(ImGuiSetCond_FirstUseEver.rawValue))
//
//    igBegin(name: "Stats", didOpen: true, flags: [GUIWindowFlags.NoTitleBar, GUIWindowFlags.NoResize, GUIWindowFlags.NoMove, GUIWindowFlags.NoSavedSettings])
//    igText("Stats")
//    igSeparator()
//    igText(String(format: "%.3f ms/frame (%.1f FPS)", 1000.0 / igGetIO().pointee.Framerate, igGetIO().pointee.Framerate))
//    igEnd()
//}
//
//public func renderTestUI() {
//    igSetNextWindowPos(ImVec2(x: 650, y: 20), Int32(ImGuiSetCond_FirstUseEver.rawValue));
//    var show_test_window = true
//    withUnsafeMutablePointer(&show_test_window) { (opened) -> () in
//        igShowTestWindow(opened)
//    }
//}