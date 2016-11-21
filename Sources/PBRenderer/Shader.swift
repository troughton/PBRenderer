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

open class Shader {
    
    fileprivate var uniformMappings = [String : GLint]()
    
    open let glProgramRef : GLuint
    fileprivate let _shaderStages : [GLuint]
    
    public init(withVertexShader vertexShader: String, fragmentShader: String) {
        let shaders = [Shader.createShader(type: GL_VERTEX_SHADER, text: vertexShader), Shader.createShader(type: GL_FRAGMENT_SHADER, text: fragmentShader)]
        _shaderStages = shaders
        self.glProgramRef = Shader.createProgram(shaderList: shaders)
    }
    
    fileprivate func useProgram() {

        glUseProgram(self.glProgramRef)
    }
    
    fileprivate func endUseProgram() {
        glUseProgram(0)
    }
    
    open func withProgram(_ function: (Shader) -> ()) -> () {
        self.useProgram()
        function(self)
        self.endUseProgram()
    }
    
    deinit {
        for shader in _shaderStages {
            glDeleteShader(shader)
        }
        
        glDeleteProgram(self.glProgramRef);
    }
    
    fileprivate func uniformLocation(forProperty property: ShaderProperty) -> GLint? {
        if let location = self.uniformMappings[property.name] {
            return location
        }
        
        var location = glGetUniformLocation(self.glProgramRef, property.name)
        if location == -1 {
            let blockIndex = glGetUniformBlockIndex(self.glProgramRef, property.name)
            location = unsafeBitCast(blockIndex, to: GLint.self)
        }
        if location == -1 {
            if _isDebugAssertConfiguration() {
                print("Warning: uniform for property \(property) was not found.")
            }
            return nil
        } else {
            self.uniformMappings[property.name] = location
            return location
        }
    }
    
    func setUniformBlockBindingPoints(forProperties properties: [ShaderProperty?]) {
        for (index, property) in properties.enumerated() where property != nil {
            guard let uniformBlockIndex = self.uniformLocation(forProperty: property!) else { continue }
            glUniformBlockBinding(self.glProgramRef, GLuint(uniformBlockIndex), GLuint(index))
        }
    }
    
}

extension Shader {
    static func shaderTextByExpandingIncludes(fromFile filePath: String) throws -> String {
        var text = try String(contentsOfFile: filePath, encoding: String.Encoding.utf8)
        let directory = filePath.components(separatedBy: "/").dropLast().joined(separator: "/")
        
        let regex = try NSRegularExpression(pattern: "#include \"(.+)\"", options: [])
        
        var includedFiles = Set<String>()
        
        while let match = regex.firstMatch(in: text, options: [], range: NSMakeRange(0, text.characters.count)) {
            let includeFileNameRange = match.rangeAt(1)
            
            let startIndex = text.index(text.startIndex, offsetBy: includeFileNameRange.location)
            let endIndex = text.index(startIndex, offsetBy: includeFileNameRange.length)
            
            let includeFileName = text[startIndex..<endIndex]
            let includeFile = try String(contentsOfFile: (directory.isEmpty ? "" : directory + "/") + includeFileName, encoding: String.Encoding.utf8)
            
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
    fileprivate static func createProgram(shaderList: [GLuint]) -> GLuint {
    
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
    
            let error = UnsafeMutablePointer<GLchar>.allocate(capacity: Int(infoLogLength))
            
            glGetProgramInfoLog(program, infoLogLength, nil, error);
            
            let errorString = String(cString: error)
            
            error.deallocate(capacity: Int(infoLogLength))
            
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
    fileprivate static func createShader(type: GLenum, text: String) -> GLuint {
        let shader = glCreateShader(type);
        let cString = text.cString(using: String.Encoding.utf8)!
        let baseAddress = cString.withUnsafeBufferPointer { (shaderText) -> UnsafePointer<GLchar>! in
            return shaderText.baseAddress
        }
        let lengths = [GLint(cString.count)]
        let shaderTexts = [baseAddress]
        
        glShaderSource(shader, 1, shaderTexts, lengths);
        
        glCompileShader(shader);
    
        var status : GLint = 0
        glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
       // if (status == GL_FALSE) {
            var infoLogLength : GLint = 0
            glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLogLength);
    
            let error = UnsafeMutablePointer<GLchar>.allocate(capacity: Int(infoLogLength))
            
            glGetShaderInfoLog(shader, infoLogLength, nil, error);
            
            let errorString = String(cString: error)
            
            error.deallocate(capacity: Int(infoLogLength))
    
            let strShaderType : String;
            switch (type) {
                case GL_VERTEX_SHADER: strShaderType = "vertex";
                case GL_GEOMETRY_SHADER: strShaderType = "geometry";
                case GL_FRAGMENT_SHADER: strShaderType = "fragment";
                default: strShaderType = "";
            }
            
            let splitText = text.components(separatedBy: .newlines)
            
            let numberedText = splitText.enumerated().reduce("", { (text, line) -> String in
                return text + String(line.offset) + ":\t" + line.element + "\n"
            })
        
        if (status == GL_FALSE) {
            
            fatalError("Compile failure in \(strShaderType) shader:\n\(errorString)\nShader is:\n\(numberedText)")
        } else if !errorString.isEmpty {
            print("Compile status:\n\(errorString)")
        }
       // }
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
        withUnsafePointer(to: &matrix) { (matrixPtr) -> Void in
            matrixPtr.withMemoryRebound(to: Float.self, capacity: 16, { glUniformMatrix4fv(uniformRef, 1, false, $0) })
            
        }
    }

    func setMatrices(_ matrices : [mat4], forProperty property: ShaderProperty) {
        guard let uniformRef = self.uniformLocation(forProperty: property) else {
            return
        }
        
        matrices.withUnsafeBufferPointer { (matrices) -> Void in
            matrices.baseAddress?.withMemoryRebound(to: Float.self, capacity: 16 * matrices.count, { glUniformMatrix4fv(uniformRef, GLsizei(matrices.count), false, $0) })
            
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
    
    func setUniformArray(_ values : [GLint], forProperty property: ShaderProperty) {
        guard let uniformRef = self.uniformLocation(forProperty: property) else {
            return
        }

        glUniform1iv(uniformRef, GLsizei(values.count), values)
    }
}
