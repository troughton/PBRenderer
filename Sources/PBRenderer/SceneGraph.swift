//
//  SceneGraph.swift
//  PBRenderer
//
//  Created by Joseph Bennett on 12/05/16.
//
//

import Foundation
import SGLMath
import ColladaParser

typealias quat = Quaternion<Float>

extension Matrix4x4 {
    init(_ array: [T]) {
        self = Matrix4x4<T>()
        for (i, val) in array.enumerated() {
            self[i / 4][i % 4] = val
        }
    }
}

final class Scene {
    
    let nodes : [SceneNode]
    
    init(fromCollada root: Collada) {
        guard let scene = root.scene?.instanceVisualScene else { fatalError("Why is there no scene in your scene graph?") }
        
        guard let visualScene = root[scene.url] as? VisualSceneType else { fatalError() }
        
        var nodes = [SceneNode]()
        for node in visualScene.nodes {
            nodes.append(SceneNode(colladaNode: node, root: root, parentTransform: nil))
        }
        self.nodes = nodes
    }

    var flattenedScene : [SceneNode] {
        var nodes = [SceneNode]()
        var stack = [SceneNode]()
        
        for node in self.nodes {
            stack.append(node)
        }
        
        while let node = stack.popLast() {
            stack.append(contentsOf: node.children)
            nodes.append(node)
        }
        return nodes
    }
}

final class SceneNode {
    let id : String?
    let name : String?
    let transform : Transform
    let meshes : [GLMesh]
    let children : [SceneNode]
    let cameras : [Camera]
    
    func initialiseComponents() {
        self.transform.sceneNode = self
        self.cameras.forEach { $0.sceneNode = self }
    }
    
    init(id: String?, name: String?, transform: Transform, meshes: [GLMesh] = [], children: [SceneNode] = [], cameras: [Camera] = []) {
        self.id = id
        self.name = name;
        self.transform = transform
        self.meshes = meshes
        self.children = children
        self.cameras = cameras
        
        self.initialiseComponents()
    }
    
    convenience init(colladaNode node: NodeType, root: Collada, parentTransform: Transform? = nil) {
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
        node.instanceGeometry.flatMap { instance in
            if let geometry = root[instance.url] as? GeometryType {
                if case let .mesh(mesh) = geometry.geometry {
                    return mesh
                }
            }
            return nil
        }.map {
            GLMesh.meshesFromCollada($0, root: root)
        }.forEach {
            meshes.append(contentsOf: $0)
        }
        
        let children = node.nodes.map { SceneNode(colladaNode: $0, root: root, parentTransform: transform) }
        
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
                return Camera(id: camera.id, name: camera.name, projectionMatrix: projectionMatrix, zNear: zNear, zFar: zFar)
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
                return Camera(id: camera.id, name: camera.name, projectionMatrix: projectionMatrix, zNear: zNear, zFar: zFar)
            }
        }
        
        self.init(id: node.id, name: node.name, transform: transform, meshes: meshes, children: children, cameras: cameras)
    }
    
}

final class Camera {
    var sceneNode : SceneNode! = nil
    
    let id : String?
    let name: String?
    
    let projectionMatrix: mat4
    let zNear: Float
    let zFar: Float
    
    init(id: String?, name: String?, projectionMatrix: mat4, zNear: Float, zFar: Float) {
        self.id = id
        self.name = name
        self.projectionMatrix = projectionMatrix
        self.zNear = zNear
        self.zFar = zFar
    }
}

final class Transform {
    var sceneNode : SceneNode! = nil
    
    var parent : Transform? = nil
    
    var translation : vec3
    var rotation : quat
    var scale : vec3
    
    private var _nodeToWorldMatrix : mat4? = nil
    private var _worldToNodeMatrix : mat4? = nil
    
    init(parent: Transform?, translation: vec3 = vec3(0), rotation: quat = quat(1, 0, 0, 0), scale: vec3 = vec3(1)) {
        self.translation = translation
        self.rotation = rotation
        self.scale = scale
        
        self.parent = parent
    }
    
    private func calculateNodeToWorldMatrix() -> mat4 {
        var transform = self.parent?.nodeToWorldMatrix ?? mat4(1)
        
        transform = SGLMath.translate(transform, self.translation)
        transform = transform * self.rotation
        transform = SGLMath.scale(transform, self.scale)
        
        return transform;
    }
    
    private func calculateWorldToNodeMatrix() -> mat4 {
        let parentTransform = self.parent?.worldToNodeMatrix ?? mat4(1)
        
        var transform = SGLMath.scale(mat4(1), vec3(1/self.scale.x, 1/self.scale.y, 1/self.scale.z))
        transform = transform * conjugate(self.rotation)
        transform = SGLMath.translate(transform, -self.translation)
        
        return transform * parentTransform;
    }
    
    var nodeToWorldMatrix : mat4 {
        get {
            if let transform = _nodeToWorldMatrix {
                return transform
            } else {
                let transform = self.calculateNodeToWorldMatrix()
                _nodeToWorldMatrix = transform
                return transform
            }
        }
    }
    
    var worldToNodeMatrix : mat4 {
        get {
            if let transform = _worldToNodeMatrix {
                return transform
            } else {
                let transform = self.calculateWorldToNodeMatrix()
                _worldToNodeMatrix = transform
                return transform
            }
        }
    }

}
