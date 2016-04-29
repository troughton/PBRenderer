import Foundation


protocol ColladaNode {
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String])
    
    func parseCharacters(_ string : String)
}

extension ColladaNode {
    func parseCharacters(_ string: String) {
        
    }
}

public final class ColladaRootNode : ColladaNode {
    var children = [ColladaNode]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        
    }
}

public final class LibraryGeometriesNode: ColladaNode {
    var geometries = [GeometryNode]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        (parent as! ColladaRootNode).children.append(self)
    }
}

public final class GeometryNode: ColladaNode {
    let name : String?
    var meshes = [MeshNode]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        self.name = attributeDict["name"]
        if let id = attributeDict["id"] {
            idsToNodes[id] = self
        }
        
        (parent as! LibraryGeometriesNode).geometries.append(self)
    }
}

public final class MeshNode: ColladaNode {
    var sources = [SourceNode]()
    var vertices = [VerticesNode]()
    var drawCommands = [ColladaNode]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        (parent as! GeometryNode).meshes.append(self)
    }
}

public final class SourceNode: ColladaNode {
    var data : ColladaNode? = nil
    var techniqueCommon : TechniqueCommonNode? = nil
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        (parent as! MeshNode).sources.append(self)
        
        if let id = attributeDict["id"] {
            idsToNodes[id] = self
        }
    }
}

public final class FloatArrayNode: ColladaNode {
    var values = [Float]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        (parent as! SourceNode).data = self
        
        if let id = attributeDict["id"] {
            idsToNodes[id] = self
        }
    }
    
    func parseCharacters(_ string: String) {
        values += string.components(separatedBy: .whitespaces()).flatMap { Float($0) }
    }
}

public final class TechniqueCommonNode: ColladaNode {
    var accessors = [AccessorNode]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        (parent as! SourceNode).techniqueCommon = self
    }
}

public final class AccessorNode: ColladaNode {
    let source : ColladaNode
    let count : Int
    let stride : Int
    
    var params  = [ParamNode]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        let sourceId = attributeDict["source"]!
        self.source = idsToNodes[sourceId.substring(from: sourceId.startIndex.advanced(by: 1))]!
        
        self.count = Int(attributeDict["count"]!)!
        self.stride = Int(attributeDict["stride"]!)!
        
        (parent as! TechniqueCommonNode).accessors.append(self)
    }
}

public final class ParamNode: ColladaNode {
    let name : String
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        self.name = attributeDict["name"]!
        
        (parent as! AccessorNode).params.append(self)
    }
}

public final class VerticesNode: ColladaNode {
    var inputs = [InputNode]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        (parent as! MeshNode).vertices.append(self)

        if let id = attributeDict["id"] {
            idsToNodes[id] = self
        }
    }
}


public final class InputNode: ColladaNode {
    
    public enum Semantic : String {
        case Position = "POSITION"
        case Vertex = "VERTEX"
        case Normal = "NORMAL"
        case TexCoord = "TEXCOORD"
        case TexTangent = "TEXTANGENT"
    }
    
    let semantic : Semantic
    let source : ColladaNode
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        self.semantic = Semantic(rawValue: attributeDict["semantic"]!)!
        
        let sourceId = attributeDict["source"]!
        self.source = idsToNodes[sourceId.substring(from: sourceId.startIndex.advanced(by: 1))]!
        
        if let parent = parent as? VerticesNode {
            parent.inputs.append(self)
        } else if let parent = parent as? TrianglesNode {
            parent.inputs.append(self)
        }
    }
}

public final class TrianglesNode: ColladaNode {
    let count : Int
    var inputs = [InputNode]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        self.count = Int(attributeDict["count"]!)!
        
        (parent as! MeshNode).drawCommands.append(self)
    }
}

public final class IndicesNode: ColladaNode {
    var values = [Int]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        
    }
    
    func parseCharacters(_ string: String) {
        values += string.components(separatedBy: .whitespaces()).flatMap { Int($0) }
    }
}

public final class LibraryVisualScenesNode: ColladaNode {
    var visualScenes = [VisualSceneNode]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        (parent as! ColladaRootNode).children.append(self)
    }
}

public final class VisualSceneNode: ColladaNode {
    var nodes = [NodeNode]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        (parent as! LibraryVisualScenesNode).visualScenes.append(self)
        
        if let id = attributeDict["id"] {
            idsToNodes[id] = self
        }
    }
}

public final class NodeNode: ColladaNode {
    let name : String?
    var transformation : MatrixNode! = nil
    var instanceGeometries = [InstanceGeometryNode]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        self.name = attributeDict["name"]
        
        (parent as! VisualSceneNode).nodes.append(self)
        
        if let id = attributeDict["id"] {
            idsToNodes[id] = self
        }
    }
}

public final class MatrixNode: ColladaNode {
    var values = [Float]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        (parent as! NodeNode).transformation = self
    }
    
    func parseCharacters(_ string: String) {
        values += string.components(separatedBy: .whitespaces()).flatMap { Float($0) }
    }
}

public final class InstanceGeometryNode: ColladaNode {
    let geometry : GeometryNode
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        let geometryId = attributeDict["url"]!
        self.geometry = idsToNodes[geometryId.substring(from: geometryId.startIndex.advanced(by: 1))]! as! GeometryNode
        
        (parent as! NodeNode).instanceGeometries.append(self)
    }
}

public final class SceneNode: ColladaNode {
    var instanceVisualScenes = [InstanceVisualSceneNode]()
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        (parent as! ColladaRootNode).children.append(self)
    }
}

public final class InstanceVisualSceneNode: ColladaNode {
    let visualScene : VisualSceneNode
    
    init(parent: ColladaNode?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
        let visualSceneId = attributeDict["url"]!
        self.visualScene = idsToNodes[visualSceneId.substring(from: visualSceneId.startIndex.advanced(by: 1))]! as! VisualSceneNode
        
        (parent as! SceneNode).instanceVisualScenes.append(self)
    }
}

public final class ColladaParser : NSObject, NSXMLParserDelegate {
    
    var root : ColladaRootNode! = nil
    var nodeStack = [ColladaNode]()
    var idsToNodes = [String : ColladaNode]()
    var waitStack = [String]()
    
    enum NodeType : String {
        case Collada = "COLLADA"
        case LibraryGeometries = "library_geometries"
        case Geometry = "geometry"
        case Mesh = "mesh"
        case Source = "source"
        case FloatArray = "float_array"
        case TechniqueCommon = "technique_common"
        case Accessor = "accessor"
        case Param = "param"
        case Vertices = "vertices"
        case Input = "input"
        case Triangles = "triangles"
        case Indices = "p"
        case LibraryVisualScenes = "library_visual_scenes"
        case VisualScene = "visual_scene"
        case Node = "node"
        case Matrix = "matrix"
        case InstanceGeometry = "instance_geometry"
        case Scene = "scene"
        case InstanceVisualScene = "instance_visual_scene"
        
        var type : ColladaNode.Type {
            switch self {
            case .Collada:
                return ColladaRootNode.self
            case .LibraryGeometries:
                return LibraryGeometriesNode.self
            case .Geometry:
                return GeometryNode.self
            case .Mesh:
                return MeshNode.self
            case .Source:
                return SourceNode.self
            case .FloatArray:
                return FloatArrayNode.self
            case .TechniqueCommon:
                return TechniqueCommonNode.self
            case .Accessor:
                return AccessorNode.self
            case .Param:
                return ParamNode.self
            case .Vertices:
                return VerticesNode.self
            case Input:
                return InputNode.self
            case .Triangles:
                return TrianglesNode.self
            case Indices:
                return IndicesNode.self
            case .LibraryVisualScenes:
                return LibraryVisualScenesNode.self
            case .VisualScene:
                return VisualSceneNode.self
            case .Node:
                return NodeNode.self
            case .Matrix:
                return MatrixNode.self
            case .InstanceGeometry:
                return InstanceGeometryNode.self
            case .Scene:
                return SceneNode.self
            case .InstanceVisualScene:
                return InstanceVisualSceneNode.self
            }
        }
    }
    
    public init?(contentsOfURL url: NSURL) {
        super.init()
        
        guard let xmlParser = NSXMLParser(contentsOf: url) else { return nil }
        
        xmlParser.delegate = self
        xmlParser.parse()
    }
    
    public func parser(_ parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if waitStack.isEmpty, let nodeType = NodeType(rawValue: elementName) {
                let node = nodeType.type.init(parent: nodeStack.last, idsToNodes: &self.idsToNodes, attributes: attributeDict)
                
                if self.root == nil {
                    self.root = node as! ColladaRootNode
                }
                
                nodeStack.append(node)
            
        } else {
            waitStack.append(elementName)
        }
    }
    
    public func parser(_ parser: NSXMLParser, foundCharacters string: String) {
        self.nodeStack.last?.parseCharacters(string)
    }
    
    public func parser(_ parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        if waitStack.isEmpty, let _ = NodeType(rawValue: elementName) {
            nodeStack.removeLast()
        } else {
            waitStack.removeLast()
        }
    }
}