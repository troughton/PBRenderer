//
//  SceneGraph.swift
//  PBRenderer
//
//  Created by Joseph Bennett on 12/05/16.
//
//

import Foundation
import SGLMath

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
    let meshes : [[GLMesh]]
    let materialBuffer : GPUBuffer<Material>
    

    init(nodes: [SceneNode], meshes: [[GLMesh]], materials: GPUBuffer<Material>) {
        self.nodes = nodes
        self.meshes = meshes
        self.materialBuffer = materials
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
    let materials : [String : GPUBufferElement<Material>]
    
    func initialiseComponents() {
        self.transform.sceneNode = self
        self.cameras.forEach { $0.sceneNode = self }
    }
    
    init(id: String?, name: String?, transform: Transform, meshes: [GLMesh] = [], children: [SceneNode] = [], cameras: [Camera] = [], materials: [String: GPUBufferElement<Material>] = [:]) {
        self.id = id
        self.name = name;
        self.transform = transform
        self.meshes = meshes
        self.children = children
        self.cameras = cameras
        self.materials = materials
        
        self.initialiseComponents()
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
