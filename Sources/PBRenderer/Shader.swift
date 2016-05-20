//
//  Shader.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 28/04/16.
//
//

import Foundation
import SGLOpenGL
import SGLMath

protocol ShaderProperty {
    var name: String { get }
}

struct StringShaderProperty : ShaderProperty {
    let name: String
    
    init(_ value: String) {
        self.name = value
        print("Warning: using string literal for property \(value)")
    }
}

class Shader {
    
    private var uniformMappings = [String : GLint]()
    
    private let _glProgramRef : GLuint
    
    init(withVertexShader vertexShader: String, fragmentShader: String) {
        let shaders = [Shader.createShader(type: GL_VERTEX_SHADER, text: vertexShader), Shader.createShader(type: GL_FRAGMENT_SHADER, text: fragmentShader)]
        _glProgramRef = Shader.createProgram(shaderList: shaders)
    }
    
    private func useProgram() {

        glUseProgram(_glProgramRef)
    }
    
    private func endUseProgram() {
        glUseProgram(0)
    }
    
    func withProgram(_ function: @noescape (Shader) -> ()) -> () {
        self.useProgram()
        function(self)
        self.endUseProgram()
    }
    
    private func uniformLocation(forProperty property: ShaderProperty) -> GLint? {
        if let location = self.uniformMappings[property.name] {
            return location
        }
        
        var location = glGetUniformLocation(_glProgramRef, property.name)
        if location == -1 {
            let blockIndex = glGetUniformBlockIndex(_glProgramRef, property.name)
            location = unsafeBitCast(blockIndex, to: GLint.self)
        }
        if location == -1 {
            print("Warning: uniform for property \(property) was not found.")
            return nil
        } else {
            self.uniformMappings[property.name] = location
            return location
        }
    }
    
    func setUniformBlockBindingPoints(forProperties properties: [ShaderProperty?]) {
        for (index, property) in properties.enumerated() where property != nil {
            guard let uniformBlockIndex = self.uniformLocation(forProperty: property!) else { continue }
            glUniformBlockBinding(_glProgramRef, GLuint(uniformBlockIndex), GLuint(index))
        }
    }
    
}

extension Shader {
    static func shaderTextByExpandingIncludes(fromFile filePath: String) throws -> String {
        var text = try String(contentsOfFile: filePath, encoding: NSUTF8StringEncoding)
        let directory = filePath.components(separatedBy: "/").dropLast().joined(separator: "/")
        
        let regex = try NSRegularExpression(pattern: "#include \"(.+)\"", options: [])
        
        var includedFiles = Set<String>()
        
        while let match = regex.firstMatch(in: text, options: [], range: NSMakeRange(0, text.characters.count)) {
            let includeFileNameRange = match.range(at: 1)
            
            let startIndex = text.index(text.startIndex, offsetBy: includeFileNameRange.location)
            let endIndex = text.index(startIndex, offsetBy: includeFileNameRange.length)
            
            let includeFileName = text[startIndex..<endIndex]
            let includeFile = try String(contentsOfFile: (directory.isEmpty ? "" : directory + "/") + includeFileName, encoding: NSUTF8StringEncoding)
            
            let matchStartIndex = text.index(text.startIndex, offsetBy: match.range.location)
            let matchEndIndex = text.index(matchStartIndex, offsetBy: match.range.length)
            
            text.replaceSubrange(matchStartIndex..<matchEndIndex, with: includedFiles.contains(includeFileName) ? "" : includeFile)
            
            includedFiles.insert(includeFileName)
        }
        
        return text
    }
}

extension Shader {
    
    /**
    * Creates and links a shader program using the specified OpenGL shader objects.
    */
    private static func createProgram(shaderList: [GLuint]) -> GLuint {
    
        let program = glCreateProgram();
    
        for shader in shaderList {
            glAttachShader(program, shader);
        }
    
        glLinkProgram(program);
        
        var status : GLint = 0
        glGetProgramiv(program, GL_LINK_STATUS, &status)
        
        if (status == GL_FALSE) {
            var infoLogLength : GLint = 0
            glGetProgramiv(program, GL_INFO_LOG_LENGTH, &infoLogLength);
    
            let error = UnsafeMutablePointer<GLchar>(calloc(sizeof(GLchar), Int(infoLogLength)))
            
            glGetProgramInfoLog(program, infoLogLength, nil, error);
            
            let errorString = String(cString: UnsafePointer<CChar>(error!))
            
            free(error)
            
            fatalError("Linker failure: \(errorString)");
        }
    
        for shader in shaderList {
            glDetachShader(program, shader);
        }
    
        return program;
    }
    
    /**
    * Creates and compiles a shader from the given text.
    * @param shaderType The type of the shader. Any of GL_VERTEX_SHADER, GL_GEOMETRY_SHADER, or GL_FRAGMENT_SHADER.
    */
    private static func createShader(type: GLenum, text: String) -> GLuint {
        let shader = glCreateShader(type);
        let cString = text.cString(using: NSUTF8StringEncoding)!
        let baseAddress = cString.withUnsafeBufferPointer { (shaderText) -> UnsafePointer<GLchar>! in
            return shaderText.baseAddress
        }
        let lengths = [GLint(cString.count)]
        let shaderTexts = [baseAddress]
        
        glShaderSource(shader, 1, shaderTexts, lengths);
        
        glCompileShader(shader);
    
        var status : GLint = 0
        glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
        if (status == GL_FALSE) {
            var infoLogLength : GLint = 0
            glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLogLength);
    
            let error = UnsafeMutablePointer<GLchar>(calloc(sizeof(GLchar), Int(infoLogLength)))
            
            glGetShaderInfoLog(shader, infoLogLength, nil, error);
            
            let errorString = String(cString: UnsafePointer<CChar>(error!))
            
            free(error)
    
            let strShaderType : String;
            switch (type) {
                case GL_VERTEX_SHADER: strShaderType = "vertex";
                case GL_GEOMETRY_SHADER: strShaderType = "geometry";
                case GL_FRAGMENT_SHADER: strShaderType = "fragment";
                default: strShaderType = "";
            }
            
            let splitText = text.components(separatedBy: .newlines())
            
            let numberedText = splitText.enumerated().reduce("", combine: { (text, line) -> String in
                return text + String(line.offset) + ":\t" + line.element + "\n"
            })
            
            fatalError("Compile failure in \(strShaderType) shader:\n\(errorString)\nShader is:\n\(numberedText)")
        }
        return shader;
    }
}

/** Matrix setting. */
extension Shader {
    
    func setMatrix(_ matrix : mat4, forProperty property: ShaderProperty) {
        guard let uniformRef = self.uniformLocation(forProperty: property) else {
            return
        }
        
        var matrix = matrix
        withUnsafePointer(&matrix) { (matrixPtr) -> Void in
            glUniformMatrix4fv(uniformRef, 1, false, UnsafePointer(matrixPtr))
        }
    }
    
    func setMatrix(_ matrix : mat3, forProperty property: ShaderProperty) {
        guard let uniformRef = self.uniformLocation(forProperty: property) else {
            return
        }
        

        let matrixArray : [Float] = [matrix[0][0], matrix[0][1], matrix[0][2], matrix[1][0], matrix[1][1], matrix[1][2], matrix[2][0], matrix[2][1], matrix[2][2]]
        
        glUniformMatrix3fv(uniformRef, 1, false, matrixArray)
    }
}

/** Uniform setting. */
extension Shader {
    
    func setUniform(_ values : Float..., forProperty property: ShaderProperty) {
        guard let uniformRef = self.uniformLocation(forProperty: property) else {
            return
        }
        
        switch values.count {
        case 1:
            glUniform1f(uniformRef, values[0])
        case 2:
            glUniform2f(uniformRef, values[0], values[1])
        case 3:
            glUniform3f(uniformRef, values[0], values[1], values[2])
        case 4:
            glUniform4f(uniformRef, values[0], values[1], values[2], values[3])
        default:
            assertionFailure("There is no uniform mapping for the values \(values) of length \(values.count)")
            break;
        }
    }
    
    func setUniform(_ values : GLint..., forProperty property: ShaderProperty) {
        guard let uniformRef = self.uniformLocation(forProperty: property) else {
            return
        }
        
        switch values.count {
        case 1:
            glUniform1i(uniformRef, values[0])
        case 2:
            glUniform2i(uniformRef, values[0], values[1])
        case 3:
            glUniform3i(uniformRef, values[0], values[1], values[2])
        case 4:
            glUniform4i(uniformRef, values[0], values[1], values[2], values[3])
        default:
            assertionFailure("There is no uniform mapping for the values \(values) of length \(values.count)")
            break;
        }
    }
}