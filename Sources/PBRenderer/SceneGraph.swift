//
//  SceneGraph.swift
//  PBRenderer
//
//  Created by Joseph Bennett on 12/05/16.
//
//

import Foundation
import SGLMath
import SGLOpenGL

public typealias quat = Quaternion<Float>

extension Matrix4x4 {
    init(_ array: [T]) {
        self = Matrix4x4<T>()
        for (i, val) in array.enumerated() {
            self[i / 4][i % 4] = val
        }
    }
}

public final class Scene {
    
    public let nodes : [SceneNode]
    let meshes : [([GLMesh], BoundingBox)]
    let materialBuffer : GPUBuffer<Material>
    let materialTexture : Texture
    let lightBuffer : GPUBuffer<GPULight>
    let lightTexture : Texture
    public var idsToNodes : [String : SceneNode]! = nil
    public var environmentMap : LightProbe?
    
    var octree : OctreeNode<SceneNode>! = nil

    init(nodes: [SceneNode], meshes: [([GLMesh], BoundingBox)], materials: GPUBuffer<Material>, lights: GPUBuffer<GPULight>, environmentMap : LightProbe?) {
        self.nodes = nodes
        self.meshes = meshes
        self.materialBuffer = materials
        self.lightBuffer = lights
        
        self.lightTexture = Texture(buffer: self.lightBuffer, internalFormat: GL_RGBA32F)
        self.materialTexture = Texture(buffer: self.materialBuffer, internalFormat: GL_RGBA32F)
        
        self.environmentMap = environmentMap
        
        var dictionary = [String : SceneNode]()
        self.flattenedScene.forEach({ (node) in
            if let id = node.id {
                dictionary[id] = node
            }
        })
        self.idsToNodes = dictionary
        
        let sceneBoundingVolume = self.flattenedScene.reduce(BoundingBox.baseBox) { (boundingBox, node) -> BoundingBox in
            return BoundingBox.combine(boundingBox, node.meshes.1)
        }
        
        let octree = OctreeNode<SceneNode>(boundingVolume: sceneBoundingVolume)
        for node in self.flattenedScene where !node.meshes.0.isEmpty {
            let boundingBox = node.meshes.1.axisAlignedBoundingBoxInSpace(nodeToSpaceTransform: node.transform.nodeToWorldMatrix)
            octree.append(node, boundingBox: boundingBox)
        }
        
        self.octree = octree
    }

    public var flattenedScene : [SceneNode] {
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
    
    public var lights : [Light] {
        var lights = [Light]()
        
        for node in self.flattenedScene {
            lights.append(contentsOf: node.lights)
        }
        return lights
    }
    
    public var cameras : [Camera] {
        var cameras = [Camera]()
        
        for node in self.flattenedScene {
            cameras.append(contentsOf: node.cameras)
        }
        return cameras
    }
    
    public var lightProbesSorted : [LightProbe] {
        var lightProbes = [LightProbe]()
        
        for node in self.flattenedScene {
            lightProbes.append(contentsOf: node.lightProbes)
        }
        return lightProbes.sorted { $0.boundingVolumeSize < $1.boundingVolumeSize }
    }
}

public final class SceneNode {
    public let id : String?
    public let name : String?
    public let transform : Transform
    public let meshes : ([GLMesh], BoundingBox)
    public let children : [SceneNode]
    public let cameras : [Camera]
    public let lights : [Light]
    public let materials : [String : GPUBufferElement<Material>]
    public let lightProbes : [LightProbe]
    
    func initialiseComponents() {
        self.transform.sceneNode = self
        self.cameras.forEach { $0.sceneNode = self }
        self.lights.forEach { $0.sceneNode = self }
        self.lightProbes.forEach { $0.sceneNode = self }
    }
    
    init(id: String?, name: String?, transform: Transform, meshes: ([GLMesh], BoundingBox) = ([], BoundingBox.baseBox), children: [SceneNode] = [], cameras: [Camera] = [], lights: [Light] = [], materials: [String: GPUBufferElement<Material>] = [:], lightProbes : [LightProbe] = []) {
        
        self.id = id.map { $0.characters.first == "_" ? $0.substring(from: $0.index(after: $0.startIndex)) : $0 }
        
        self.name = name;
        self.transform = transform
        self.meshes = meshes
        self.children = children
        self.cameras = cameras
        self.materials = materials
        self.lights = lights
        self.lightProbes = lightProbes
        
        self.initialiseComponents()
    }
    
    func transformDidChange() {
        self.lights.forEach { (light) in
            light.transformDidChange()
        }
        
        self.lightProbes.forEach { $0.transformDidChange() }
    }
}

public final class Camera {
    public var sceneNode : SceneNode! = nil
    
    public var transform : Transform {
        return self.sceneNode.transform
    }
    
    public let id : String?
    public let name: String?
    
    public let projectionMatrix: mat4
    public let zNear: Float
    public let zFar: Float
    public let aspectRatio : Float
    
    public var aperture : Float = 16
    public var shutterTime : Float = 0.1
    public var ISO : Float = 100
    
    init(id: String?, name: String?, projectionMatrix: mat4, zNear: Float, zFar: Float, aspectRatio: Float) {
        self.id = id
        self.name = name
        self.projectionMatrix = projectionMatrix
        self.zNear = zNear
        self.zFar = zFar
        self.aspectRatio = aspectRatio
    }
    
    var EV100 : Float {
//        EV number is defined as: 2^EV_s = N^2 / t and EV_s = EV_100 + log2(S/100)
//      This gives
//        EV_s = log2(N^2 / t)
//        EV_100 + log2(S/100) = log2(N^2 / t)
//        EV_100 = log2(N^2 / t) - log2(S/100)
//        EV_100 = log2(N^2 / t . 100 / S)
        return log2(self.aperture * self.aperture / shutterTime * 100 / self.ISO)
    }
    
    var exposure : Float {
        // Compute the maximum luminance possible with H_sbs sensitivity //maxLum=78/( S*q )*N^2/t
        //  maxLum = 78 / (S * q) * N^2 / t
        //         = 78 / (S * q) * 2^EV_100
        //         = 78 / (100 * 0.65) * 2^EV_100
        //         = 1.2 * 2^EV
        //Reference: http://en.wikipedia.org/wiki/Film_speed
        let maxLuminance = 1.2 * exp2f(self.EV100)
        return 1.0 / maxLuminance
    }
    
    //Calculates the size of a plane positioned at z = -1 (hence the divide by zNear)
    var nearPlaneSize : vec2 {
        let tanHalfFoV = 1/(self.projectionMatrix[0][0] * self.aspectRatio)
        let y = tanHalfFoV * self.zNear
        let x = y * self.aspectRatio
        return vec2(x, y) / self.zNear
    }
}

public final class Transform {
    public var sceneNode : SceneNode! = nil
    
    public var parent : Transform? = nil
    
    public var translation : vec3 {
        didSet {
            self.setNeedsRecalculateTransform()
            self.sceneNode?.transformDidChange()
        }
    }
    public var rotation : quat {
        didSet {
            self.setNeedsRecalculateTransform()
            self.sceneNode?.transformDidChange()
        }
    }
    
    public var scale : vec3 {
        didSet {
            self.setNeedsRecalculateTransform()
            self.sceneNode?.transformDidChange()
        }
    }
    
    private var _nodeToWorldMatrix : mat4? = nil
    private var _worldToNodeMatrix : mat4? = nil
    
    private var _worldSpacePosition : vec4? = nil
    private var _worldSpaceDirection : vec4? = nil

    
    init(parent: Transform?, translation: vec3 = vec3(0), rotation: quat = quat(1, 0, 0, 0), scale: vec3 = vec3(1)) {
        self.translation = translation
        self.rotation = rotation
        self.scale = scale
        
        self.parent = parent
    }
    
    private func setNeedsRecalculateTransform() {
        _nodeToWorldMatrix = nil
        _worldToNodeMatrix = nil
        _worldSpacePosition = nil
        _worldSpaceDirection = nil
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
    
    public var nodeToWorldMatrix : mat4 {
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
    
    public var worldToNodeMatrix : mat4 {
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
    
    public var worldSpacePosition : vec4 {
        get {
            if let position = _worldSpacePosition {
                return position
            } else {
                let position = nodeToWorldMatrix * vec4(0, 0, 0, 1)
                _worldSpacePosition = position
                return position
            }
        }
    }
    
    public var worldSpaceDirection : vec4 {
        get {
            if let direction = _worldSpaceDirection {
                return direction
            } else {
                let direction = normalize(nodeToWorldMatrix * vec4(0, 0, 1, 0))
                _worldSpaceDirection = direction
                return direction
            }
        }
    }

}
