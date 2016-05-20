//
//  LightProbe.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 19/05/16.
//
//

import Foundation
import SGLOpenGL

//final class LightProbe {
//    
//    static let ldDiffuseShader : Shader = {
//        let vertexText = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "PassthroughQuad.vert"))
//        let fragmentText = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "LDTextureDiffuse.frag"))
//        return Shader(withVertexShader: vertexText, fragmentShader: fragmentText)
//    }()
//    
//    static let ldSpecularShader : Shader = {
//        let vertexText = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "PassthroughQuad.vert"))
//        let fragmentText = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "LDTextureSpecular.frag"))
//        return Shader(withVertexShader: vertexText, fragmentShader: fragmentText)
//    }()
//    
//    let ldDiffuseTexture : Texture
//    let ldSpecularTexture : Texture
//    let cubeMap : Texture
//    
//    let cubeMapFaces = [ GL_TEXTURE_CUBE_MAP_NEGATIVE_Z, GL_TEXTURE_CUBE_MAP_NEGATIVE_Y, GL_TEXTURE_CUBE_MAP_NEGATIVE_X, GL_TEXTURE_CUBE_MAP_POSITIVE_Z, GL_TEXTURE_CUBE_MAP_POSITIVE_Y, GL_TEXTURE_CUBE_MAP_POSITIVE_X ]
//    
//    func generateLDTextures(cubeMap: Texture, resolution: Int = 256) -> (diffuse: Texture, specular: Texture) {
//        let textureDescriptor = TextureDescriptor(textureCubeWithPixelFormat: GL_RGB16F, width: resolution, height: resolution, mipmapped: true)
//        let diffuseTexture = Texture(textureWithDescriptor: textureDescriptor, type: nil, format: nil, data: nil as [Void]?)
//        
//        //Remember sampler parameters
//        
//        for face in cubeMapFaces {
//            
//            //use face as texture slice
//        }
//    
//    for (GLenum face : cubeMapFaces) {
//    
//    float step = 1.f / (resolution - 2);
//    
//    for (int y = 0; y < resolution; ++y) {
//    for (int x = 0; x < resolution; ++x) {
//    float u = 0.5 * step + x * step;
//    float v = 0.5 * step + y * step;
//    vec3 direction = cubeMapFaceUVToDirection(vec2(u, v), face);
//    
//    textureData[y * resolution + x] = integrateDiffuseCubeLD(direction, image);
//    }
//    }
//    
//    glTexImage2D(face, 0, GL_RGBA16F, resolution, resolution, 0, GL_RGBA, GL_FLOAT, textureData);
//    }
//    
//    free(textureData);
//
//    
//    return glTexture;
//    }
//    
//    void generateLDSpecularTexture(CubeMap& image, int fullResolution, int mipLevel, int mipCount) {
//    
//    int resolution = fullResolution >> mipLevel;
//    float mip = (float)mipLevel/mipCount;
//    float perceptuallyLinearRoughness = mip * mip;
//    float roughness = perceptuallyLinearRoughness * perceptuallyLinearRoughness;
//    
//    vec4 *textureData = (vec4*)calloc(sizeof(vec4), resolution * resolution);
//    
//    for (GLenum face : cubeMapFaces) {
//    
//    float step = 1.f / (resolution - 2);
//    
//    for (int y = 0; y < resolution; ++y) {
//    for (int x = 0; x < resolution; ++x) {
//    float u = 0.5 * step + x * step;
//    float v = 0.5 * step + y * step;
//    vec3 direction = cubeMapFaceUVToDirection(vec2(u, v), face);
//    
//    textureData[y * resolution + x] = integrateSpecularCubeLD(direction, direction, roughness, image);
//    }
//    }
//    
//    glTexImage2D(face, mipLevel, GL_RGBA16F, resolution, resolution, 0, GL_RGBA, GL_FLOAT, textureData);
//    }
//    
//    free(textureData);
//    }
//    
//    GLuint generateLDSpecularTexture(CubeMap& image, int resolution) {
//    
//    const int maxMipLevel = 6;
//    
//    GLuint glTexture = 0;
//    glGenTextures(1, &glTexture);
//    glBindTexture(GL_TEXTURE_CUBE_MAP, glTexture);
//    
//    glTexParameterf(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
//    glTexParameterf(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//    
//    glTexParameterf(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//    glTexParameterf(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//    
//    for (GLenum face : cubeMapFaces) {
//    vec4 *textureData = (vec4*)calloc(sizeof(vec4), resolution * resolution);
//    
//    float step = 1.f / (resolution - 2);
//    
//    for (int y = 0; y < resolution; ++y) {
//    for (int x = 0; x < resolution; ++x) {
//    float u = 0.5 * step + x * step;
//    float v = 0.5 * step + y * step;
//    vec3 direction = cubeMapFaceUVToDirection(vec2(u, v), face);
//    textureData[y * resolution + x] = image.sample(direction);
//    }
//    }
//    
//    glTexImage2D(face, 0, GL_RGBA16F, resolution, resolution, 0, GL_RGBA, GL_FLOAT, textureData);
//    
//    free(textureData);
//    }
//    
//    for (int mipLevel = 1; mipLevel <= maxMipLevel; ++mipLevel) {
//    generateLDSpecularTexture(image, resolution, mipLevel, maxMipLevel);
//    }
//    
//    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_BASE_LEVEL, 0);
//    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAX_LEVEL, maxMipLevel);
//    
//    return glTexture;
//    }
//    
//    func generateLDTextures(cubeMap: Texture) -> (diffuseTexture: Texture, specularTexture: Texture) {
//        let resolution = 512;
//    
//        let diffuseTexture = generateLDDiffuseTexture(cubeMap: cubeMap, resolution: resolution)
//        let specularTexture = generateLDSpecularTexture(cubeMap, resolution)
//        
//        return (diffuseTexture, specularTexture)
//    }
//}