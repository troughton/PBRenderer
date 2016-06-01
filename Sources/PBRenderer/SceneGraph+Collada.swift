//
//  SceneGraph+Collada.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 15/05/16.
//
//

import Foundation
import ColladaParser
import SGLMath
import SGLOpenGL

extension Scene {
    static func parseMeshesFromCollada(_ root: Collada) -> [String: [GLMesh]] {
        var meshes = [String : [GLMesh]]()
        
        for libraryGeometry in root.libraryGeometries {
            for geometry in libraryGeometry.geometry {
                if let id = geometry.id, case let .mesh(mesh) = geometry.geometry {
                    meshes[id] = GLMesh.meshesFromCollada(mesh, root: root)
                }
            }
        }
        return meshes
    }
    
    static func parseLightsFromCollada(_ root: Collada) -> (elementsInBuffer: [String : Light], buffer: GPUBuffer<GPULight>) {
        var elementsInBuffer = [String : Light]()
        
        let lightCount = root.libraryLights.reduce(0) { (count, lightLibrary) -> Int in
            return count + lightLibrary.light.count
        }
        
        let lightBuffer = GPUBuffer<GPULight>(capacity: lightCount, bufferBinding: GL_ARRAY_BUFFER, accessFrequency: .Dynamic, accessType: .Draw)
        
        var i = 0
        for lightLibrary in root.libraryLights {
            for light in lightLibrary.light {
                let colourAndIntensity : vec3
                let type : LightType
                
                let openColladaMayaTechnique = light.extra.first?.technique.first
                
                switch light.techniqueCommon.lightType {
                case let .Directional(colour):
                    colourAndIntensity = vec3(colour)
                    type = .Directional
                case let .Point(colour):
                    type = .Point
                    colourAndIntensity = vec3(colour)
                case let .Spot(colour, falloffDegrees, _):
                    
                    var outerCutoff = falloffDegrees * 0.5
                    if let penumbra = openColladaMayaTechnique?.attributes["penumbra_angle"] {
                        outerCutoff += max(0, Float(penumbra)!) * 0.5
                    }
                    
                    type = .Spot(innerCutoff: radians(degrees: falloffDegrees * 0.5),
                                 outerCutoff: radians(degrees: outerCutoff))
                    colourAndIntensity = vec3(colour)
                case .Ambient(_):
                    continue
                }
                
                var intensity = length(colourAndIntensity)
                let colour = colourAndIntensity / intensity
                
                if let mayaIntensity = openColladaMayaTechnique?.attributes["intensity"] {
                    intensity *= Float(mayaIntensity)!
                }
                
                let warningFalloffIsHardCoded = true
                let pbLight = Light(type: type, colour: .Colour(colour), intensity: intensity, falloffRadius: 15.0, backingGPULight: lightBuffer[viewForIndex: i])
                elementsInBuffer[light.id!] = pbLight
                    i += 1
                }
            }
        
        lightBuffer.didModifyRange(0..<i)
        return (elementsInBuffer, lightBuffer)
        
    }
    
    
    static func parseMaterialsFromCollada(_ root: Collada) -> (elementsInBuffer: [String : GPUBufferElement<Material>], buffer: GPUBuffer<Material>) {
        var elementsInBuffer = [String : GPUBufferElement<Material>]()
        
        let materialCount = root.libraryMaterials.reduce(0) { (count, materialLibrary) -> Int in
            return count + materialLibrary.material.count
        }
        
        let materialBuffer = GPUBuffer<Material>(capacity: materialCount, bufferBinding: GL_UNIFORM_BUFFER, accessFrequency: .Dynamic, accessType: .Draw)
        
        var i = 0
        for materialLibrary in root.libraryMaterials {
            for mat in materialLibrary.material {
                let effect = root[mat.instanceEffect.url] as! EffectType
                if let technique = effect.profileCommon?.technique {
                    var material = Material()
                    
                    let materialParams : MaterialDetailType
                    switch technique.choice0 {
                    case .blinn(let blinn):
                        materialParams = blinn
                    case .lambert(let lambert):
                        materialParams = lambert
                    case .constant(let constant):
                        materialParams = constant
                    case .phong(let phong):
                        materialParams = phong
                    }
                    
                    if let diffuse = materialParams.diffuse {
                        if case let .color(_, colour) = diffuse {
                            material.baseColour = vec4(colour)
                            
                            if _isDebugAssertConfiguration() && clamp(material.baseColour, 0, 1) != material.baseColour {
                                print("Warning: material colour should be in the range [0, 1]")
                                material.baseColour = clamp(material.baseColour, vec4(0), vec4(1))
                            }
                        }
                    }
                    if let reflectivity = materialParams.reflectivity {
                        if case let .float(_, value) = reflectivity {
                            material.reflectance = value
                        }
                        if _isDebugAssertConfiguration() && (material.reflectance < 0 && material.reflectance > 1) {
                            print("Warning: material reflectance should be in the range [0, 1]")
                            material.reflectance = clamp(material.reflectance, min: 0, max: 1)
                        }
                        
                    }
                    
                    if let shininess = materialParams.shininess {
                        if case let .float(_, value) = shininess {
                            material.smoothness = value
                        }
                        
                        if _isDebugAssertConfiguration() && !(material.smoothness >= 0 && material.smoothness <= 1) {
                            print("Warning: material smoothness should be in the range [0, 1]")
                            material.smoothness = clamp(material.smoothness, min: 0, max: 1)
                        }
                    }
                    
                    if let specular = materialParams.specular {
                        if case let .color(_, colour) = specular {
                            material.metalMask = vec4(colour).r
                        }
                        
                        if _isDebugAssertConfiguration() && !(material.metalMask >= 0 && material.metalMask <= 1) {
                            print("Warning: material MetalMask should be in the range [0, 1]")
                            material.metalMask = clamp(material.metalMask, min: 0, max: 1)
                        }
                    }
                    
                    materialBuffer[i] = material
                    
                    elementsInBuffer[mat.id ?? effect.id] = materialBuffer[viewForIndex: i]
                    i += 1
                }
            }
        }
        
        materialBuffer.didModifyRange(0..<i)
        return (elementsInBuffer, materialBuffer)
        
    }
    
    public convenience init(fromCollada root: Collada) {
        guard let scene = root.scene?.instanceVisualScene else { fatalError("Why is there no scene in your scene graph?") }
        
        guard let visualScene = root[scene.url] as? VisualSceneType else { fatalError() }
        
        let (materialIdsToElements, materialBuffer) = Scene.parseMaterialsFromCollada(root)
        
        let (lightIdsToLights, lightBuffer) = Scene.parseLightsFromCollada(root)
        
        let sourcesToMeshes = Scene.parseMeshesFromCollada(root)
        
        var nodes = [SceneNode]()
        for node in visualScene.nodes {
            nodes.append(SceneNode(colladaNode: node, root: root, sourcesToMeshes: sourcesToMeshes, materials: materialIdsToElements, lights: lightIdsToLights, parentTransform: nil))
        }
        
        self.init(nodes: nodes, meshes: [[GLMesh]](sourcesToMeshes.values), materials: materialBuffer, lights: lightBuffer)
    }
}

extension SceneNode {
    convenience init(colladaNode node: NodeType, root: Collada, sourcesToMeshes: [String : [GLMesh]], materials: [String: GPUBufferElement<Material>], lights: [String: Light], parentTransform: Transform? = nil) {
        var currentTransform = mat4(1)
        
        for transform in node.transforms {
            switch transform {
            case .matrix(let matrix):
                let data = matrix.data
                currentTransform *= mat4(data)
            case .translate(let translation):
                currentTransform = SGLMath.translate(currentTransform, vec3(translation.data))
            case .scale(let scale):
                currentTransform = SGLMath.scale(currentTransform, vec3(scale.data))
            case .rotate(let rotation):
                currentTransform = currentTransform * quat(angle: radians(degrees: rotation.data.last!), axis: vec4(rotation.data).xyz)
            case .lookat(let lookat):
                currentTransform = currentTransform *
                    SGLMath.lookAt(vec3(lookat.data[0], lookat.data[1], lookat.data[2]),
                                   vec3(lookat.data[3], lookat.data[4], lookat.data[5]),
                                   vec3(lookat.data[6], lookat.data[7], lookat.data[8]))
            case .skew(_):
                print("Warning: skews are unsupported")
            }
        }
        
        let translation = currentTransform[3].xyz
        
        currentTransform[3] = vec4(0, 0, 0, 1)
        let scale = vec3(length(currentTransform[0].xyz), length(currentTransform[1].xyz), length(currentTransform[2].xyz))
        currentTransform[0] /= scale.x
        currentTransform[1] /= scale.y
        currentTransform[2] /= scale.z
        
        let rotation = quat(currentTransform)
        
        //    self.transform = Transform(parent: nil, translation: translation, rotation: rotation, scale: scale)
        let transform = Transform(parent: parentTransform, translation: translation, rotation: rotation, scale: scale)
        
        var meshes = [GLMesh]()
        var instanceMaterialNamesToMaterials = [String : GPUBufferElement<Material>]()
        node.instanceGeometry.forEach { instance in
            instance.bindMaterial?.techniqueCommon.instanceMaterial.forEach { material in
                let name = material.symbol
                let target = materials[material.target.substring(from: material.target.index(after: material.target.startIndex))]!
                instanceMaterialNamesToMaterials[name] = target
            }
            
            if let m = sourcesToMeshes[instance.url.substring(from: instance.url.index(after: instance.url.startIndex))] {
                meshes.append(contentsOf: m)
            }
        }
        
        let children = node.nodes.map { SceneNode(colladaNode: $0, root: root, sourcesToMeshes: sourcesToMeshes, materials: materials, lights: lights, parentTransform: transform) }
        
        let cameras : [Camera] = node.instanceCamera.map { root[$0.url] as! CameraType }.map { camera in
            let projectionMatrix : mat4
            switch camera.optics.techniqueCommon.projection {
            case let .Perspective(xFov, yFov, aspectRatio, zNear, zFar):
                if let yFov = yFov, let aspectRatio = aspectRatio {
                    projectionMatrix = SGLMath.perspective(radians(degrees: yFov), aspectRatio, zNear, zFar)
                } else if let xFov = xFov, let aspectRatio = aspectRatio {
                    projectionMatrix = SGLMath.perspective(radians(degrees: xFov * aspectRatio), aspectRatio, zNear, zFar)
                } else if let xFov = xFov, let yFov = yFov {
                    projectionMatrix = SGLMath.perspective(radians(degrees: yFov), xFov / yFov, zNear, zFar)
                } else {
                    fatalError("Unsupported field of view combination.")
                }
                return Camera(id: camera.id, name: camera.name, projectionMatrix: projectionMatrix, zNear: zNear, zFar: zFar, aspectRatio: aspectRatio ?? (xFov! / yFov!))
            case let .Orthographic(xMag, yMag, aspectRatio, zNear, zFar):
                if let xMag = xMag, yMag = yMag {
                    projectionMatrix = SGLMath.ortho(0, xMag, 0, yMag, zNear, zFar)
                } else if let xMag = xMag, aspectRatio = aspectRatio {
                    projectionMatrix = SGLMath.ortho(0, xMag, 0, xMag / aspectRatio, zNear, zFar)
                } else if let yMag = yMag, aspectRatio = aspectRatio {
                    projectionMatrix = SGLMath.ortho(0, yMag * aspectRatio, 0, yMag, zNear, zFar)
                } else {
                    fatalError("Invalid orthographic matrix terms.")
                }
                return Camera(id: camera.id, name: camera.name, projectionMatrix: projectionMatrix, zNear: zNear, zFar: zFar, aspectRatio: aspectRatio ?? (xMag! / yMag!))
            }
        }
        
        let lightObjects : [Light] = node.instanceLight.map { lights[$0.url.substring(from: $0.url.index(after: $0.url.startIndex))]! }
        
        self.init(id: node.id, name: node.name, transform: transform, meshes: meshes, children: children, cameras: cameras, lights: lightObjects, materials: instanceMaterialNamesToMaterials)
    }

}