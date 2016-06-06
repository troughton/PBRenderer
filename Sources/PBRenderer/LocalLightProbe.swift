//
//  LocalLightProbe.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 2/06/16.
//
//

import Foundation
import SGLMath
import SGLOpenGL


public final class LocalLightProbe {
    
    let localCubeMap : Texture
    public let ldTexture : LDTexture
    public let resolution : Int
    
    private let colourAttachments : [RenderPassColourAttachment]
    private let sceneRenderers : [SceneRenderer]
    
    public init(resolution: Int) {
        let cubeMapDescriptor = TextureDescriptor(textureCubeWithPixelFormat: GL_RGBA16F, width: resolution, height: resolution, mipmapped: true)
        let localCubeMap = Texture(textureWithDescriptor: cubeMapDescriptor)
        self.localCubeMap = localCubeMap
        
        self.resolution = resolution
        self.ldTexture = LDTexture(specularResolution: resolution)
        
        self.colourAttachments = (0..<UInt(6)).map { (slice) -> RenderPassColourAttachment in
            let blendState = BlendState(isBlendingEnabled: true, sourceRGBBlendFactor: GL_ONE, destinationRGBBlendFactor: GL_ONE, rgbBlendOperation: GL_FUNC_ADD, sourceAlphaBlendFactor: GL_ZERO, destinationAlphaBlendFactor: GL_ONE, alphaBlendOperation: GL_FUNC_ADD, writeMask: .All)
            
            var colourAttachment = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
            colourAttachment.texture = localCubeMap
            colourAttachment.loadAction = .Load
            colourAttachment.storeAction = .Store
            colourAttachment.blendState = blendState
            colourAttachment.textureSlice = slice
            return colourAttachment
        }
        
        self.sceneRenderers = self.colourAttachments.map { SceneRenderer(lightProbeRendererWithLightAccumulationAttachment: $0) }
    }
    
    func renderSceneToCubeMap(_ scene: Scene, atPosition worldSpacePosition: vec3, zNear: Float, zFar: Float) -> Float {
        
        let projectionMatrix = SGLMath.perspective(Float(M_PI_2), 1.0, zNear, zFar)
        
        let transform = Transform(parent: nil, translation: worldSpacePosition)
        let camera = Camera(id: nil, name: nil, projectionMatrix: projectionMatrix, zNear: zNear, zFar: zFar, aspectRatio: 1.0)
        
        camera.shutterTime = 1.0
        camera.aperture = 1.0
        
        let _ = SceneNode(id: nil, name: nil, transform: transform, cameras: [camera])
        
        for (i, sceneRenderer) in self.sceneRenderers.enumerated() {
            
            switch (i + GL_TEXTURE_CUBE_MAP_POSITIVE_X) {
            case GL_TEXTURE_CUBE_MAP_POSITIVE_X:
                transform.rotation = quat(angle: Float(-M_PI_2), axis: vec3(0, 1, 0))
                transform.rotation *= quat(angle: Float(M_PI), axis: vec3(0, 0, 1))
            case GL_TEXTURE_CUBE_MAP_NEGATIVE_X:
                transform.rotation = quat(angle: Float(M_PI_2), axis: vec3(0, 1, 0))
                transform.rotation *= quat(angle: Float(M_PI), axis: vec3(0, 0, 1))
                
            case GL_TEXTURE_CUBE_MAP_POSITIVE_Y:
                transform.rotation = quat(angle: Float(M_PI_2), axis: vec3(1, 0, 0))
            case GL_TEXTURE_CUBE_MAP_NEGATIVE_Y:
                transform.rotation = quat(angle: Float(-M_PI_2), axis: vec3(1, 0, 0))
            case GL_TEXTURE_CUBE_MAP_NEGATIVE_Z:
                transform.rotation = quat(angle: 0, axis: vec3(0, 1, 0))
                transform.rotation *= quat(angle: Float(M_PI), axis: vec3(0, 0, 1))
            case GL_TEXTURE_CUBE_MAP_POSITIVE_Z:
                transform.rotation = quat(angle: Float(M_PI), axis: vec3(0, 1, 0))
                transform.rotation *= quat(angle: Float(M_PI), axis: vec3(0, 0, 1))
            default:
                fatalError()
                break
            }
            
            sceneRenderer.renderScene(scene, camera: camera, environmentMap: nil)
        }
        
        self.localCubeMap.generateMipmaps()

        return camera.exposure
    }
    
    public func render(scene: Scene, atPosition position: vec3, zNear: Float, zFar: Float) {
        let exposureUsed = self.renderSceneToCubeMap(scene, atPosition: position, zNear: zNear, zFar: zFar)
        
        LDTexture.fillLDTexturesFromCubeMaps(textures: [self.ldTexture], cubeMaps: [self.localCubeMap], valueMultipliers: [1.0 / exposureUsed])
    }
    
}

struct CubeMapInfluenceVolume {
    let sceneNode : SceneNode
    
    var transform : Transform {
        return self.sceneNode.transform
    }
    
    var boundingBox : BoundingBox
    
    let lightProbe : LocalLightProbe
    
    func NDF(sourcePosition: vec4) -> Float {
        let localPosition = self.transform.worldToNodeMatrix * sourcePosition
        
        var localDirection = abs(localPosition.xyz)
        localDirection = localDirection / boundingBox.size
        
        return max(localDirection.x, max(localDirection.y, localDirection.z))
    }
}
//Sphere::GetInfluenceWeights()
//{
//    Vector SphereCenter            = InfluenceVolume->GetCenter();
//    Vector Direction               = SourcePosition - SphereCenter;
//    const float DistanceSquared    = (Direction).SizeSquared();
//    NDF = (Direction.Size() - InnerRange) / (OuterRange - InnerRange);
//}

//https://seblagarde.wordpress.com/2012/09/29/image-based-lighting-approaches-and-parallax-corrected-cubemap/
func blendMapFactor(sourcePosition: vec4, influenceVolumes: [CubeMapInfluenceVolume], blendFactors: inout [Float]) {
    assert(influenceVolumes.count == blendFactors.count)
    
    // First calc sum of NDF and InvDNF to normalize value
    var SumNDF            = Float(0.0);
    var InvSumNDF         = Float(0.0);
    var SumBlendFactor    = Float(0.0);
    // The algorithm is as follows
    // Primitive have a normalized distance function which is 0 at center and 1 at boundary
    // When blending multiple primitive, we want the following constraint to be respect:
    // A - 100% (full weight) at center of primitive whatever the number of primitive overlapping
    // B - 0% (zero weight) at boundary of primitive whatever the number of primitive overlapping
    // For this we calc two weight and modulate them.
    // Weight0 is calc with NDF and allow to respect constraint B
    // Weight1 is calc with inverse NDF, which is (1 - NDF) and allow to respect constraint A
    // What enforce the constraint is the special case of 0 which once multiply by another value is 0.
    // For Weight 0, the 0 will enforce that boundary is always at 0%, but center will not always be 100%
    // For Weight 1, the 0 will enforce that center is always at 100%, but boundary will not always be 0%
    // Modulate weight0 and weight1 then renormalizing will allow to respects A and B at the same time.
    // The in between is not linear but give a pleasant result.
    // In practice the algorithm fail to avoid popping when leaving inner range of a primitive
    // which is include in at least 2 other primitives.
    // As this is a rare case, we do with it.
    for influenceVolume in influenceVolumes {
        SumNDF       += influenceVolume.NDF(sourcePosition: sourcePosition);
        InvSumNDF    += (1.0 - influenceVolume.NDF(sourcePosition: sourcePosition));
    }
    
    // Weight0 = normalized NDF, inverted to have 1 at center, 0 at boundary.
    // And as we invert, we need to divide by Num-1 to stay normalized (else sum is > 1).
    // respect constraint B.
    // Weight1 = normalized inverted NDF, so we have 1 at center, 0 at boundary
    // and respect constraint A.
    
    
    for i in 0..<blendFactors.count {
        blendFactors[i] = (1.0 - (influenceVolumes[i].NDF(sourcePosition: sourcePosition) / SumNDF))
        blendFactors[i] /= (Float(blendFactors.count) - 1);
        blendFactors[i] *= ((1.0 - influenceVolumes[i].NDF(sourcePosition: sourcePosition)) / InvSumNDF);
        SumBlendFactor += blendFactors[i];
    }
    
    
    // Normalize BlendFactor
    if (SumBlendFactor == 0.0) { // Possible with custom weight
        SumBlendFactor = 1.0;
    }
    
    let ConstVal = Float(1.0) / SumBlendFactor;
    
    for i in 0..<blendFactors.count {
        blendFactors[i] *= ConstVal
    }
}

func computeCubeMapBlend(location: vec4, influenceVolumes: [CubeMapInfluenceVolume]) {
    
}

//// Main code
//for (int i = 0; i < NumPrimitive; ++i)
//{
//    if (In inner range)
//    EarlyOut;
//    
//    if (In outer range)
//    SelectedInfluenceVolumes.Add(InfluenceVolumes.GetInfluenceWeights(LocationPOI));
//}
//
//SelectedInfluenceVolumes.Sort();
//GetBlendMapFactor(SelectedInfluenceVolumes.Num(), SelectedInfluenceVolumes, outBlendFactor)