import Foundation

public protocol ColladaNode {
}

protocol ColladaNodeInternal {
    init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String])
    
    func parseCharacters(_ string : String)
}

extension ColladaNodeInternal {
    func parseCharacters(_ string: String) {
        
    }
}

public protocol ColladaSource { }

public protocol ColladaPrimitive { }

public class Collada  {
    
    public final class ColladaRootNode : ColladaNode, ColladaNodeInternal {
        public var children = [ColladaNode]()
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            
        }
    }
    
    public final class LibraryGeometriesNode: ColladaNode, ColladaNodeInternal  {
        public var geometries = [GeometryNode]()
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            (parent as! ColladaRootNode).children.append(self)
        }
    }
    
    public final class GeometryNode: ColladaNode, ColladaNodeInternal {
        let name : String?
        public var meshes = [MeshNode]()
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            self.name = attributeDict["name"]
            if let id = attributeDict["id"] {
                idsToNodes[id] = self
            }
            
            (parent as! LibraryGeometriesNode).geometries.append(self)
        }
    }
    
    public final class MeshNode: ColladaNode, ColladaNodeInternal {
        public var sources = [SourceNode]()
        var vertices = [VerticesNode]()
        public var primitives = [ColladaPrimitive]()
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            (parent as! GeometryNode).meshes.append(self)
        }
    }
    
    public final class SourceNode: ColladaNode, ColladaNodeInternal, ColladaSource, Hashable {
        public var data : ColladaSource? = nil
        public var techniqueCommon : TechniqueCommonNode? = nil
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            (parent as! MeshNode).sources.append(self)
            
            if let id = attributeDict["id"] {
                idsToNodes[id] = self
            }
        }
        
        public var hashValue: Int {
            return ObjectIdentifier(self).hashValue
        }
    }
    
    public final class FloatArrayNode: ColladaNode, ColladaNodeInternal, ColladaSource {
        public var values = [Float]()
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            (parent as! SourceNode).data = self
            
            if let id = attributeDict["id"] {
                idsToNodes[id] = self
            }
        }
        
        func parseCharacters(_ string: String) {
            values += string.components(separatedBy: .whitespaces()).flatMap { Float($0) }
        }
    }
    
    public final class TechniqueCommonNode: ColladaNode, ColladaNodeInternal {
        public var accessor : AccessorNode! = nil
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            (parent as! SourceNode).techniqueCommon = self
        }
    }
    
    public final class AccessorNode: ColladaNode, ColladaNodeInternal {
        let source : ColladaNode
        let count : Int
        public let stride : Int
        
        public var params  = [ParamNode]()
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            let sourceId = attributeDict["source"]!
            self.source = idsToNodes[sourceId.substring(from: sourceId.startIndex.advanced(by: 1))]!
            
            self.count = Int(attributeDict["count"]!)!
            self.stride = Int(attributeDict["stride"]!)!
            
            (parent as! TechniqueCommonNode).accessor = self
        }
    }
    
    public final class ParamNode: ColladaNode, ColladaNodeInternal {
        let name : String
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            self.name = attributeDict["name"]!
            
            (parent as! AccessorNode).params.append(self)
        }
    }
    
    public final class VerticesNode: ColladaNode, ColladaNodeInternal, ColladaSource {
        public var inputs = [InputNode]()
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            (parent as! MeshNode).vertices.append(self)
            
            if let id = attributeDict["id"] {
                idsToNodes[id] = self
            }
        }
    }
    
    
    public final class InputNode: ColladaNode, ColladaNodeInternal {
        
        public enum Semantic : String {
            case Position = "POSITION"
            case Vertex = "VERTEX"
            case Normal = "NORMAL"
            case TexCoord = "TEXCOORD"
            case TexTangent = "TEXTANGENT"
        }
        
        public let semantic : Semantic
        public let source : ColladaSource
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            self.semantic = Semantic(rawValue: attributeDict["semantic"]!)!
            
            let sourceId = attributeDict["source"]!
            self.source = idsToNodes[sourceId.substring(from: sourceId.startIndex.advanced(by: 1))]! as! ColladaSource
            
            if let parent = parent as? VerticesNode {
                parent.inputs.append(self)
            } else if let parent = parent as? TrianglesNode {
                parent.inputs.append(self)
            }
        }
    }
    
    public final class TrianglesNode: ColladaNode, ColladaNodeInternal, ColladaPrimitive {
        public let count : Int
        public var inputs = [InputNode]()
        public var indices : IndicesNode! = nil
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            self.count = Int(attributeDict["count"]!)!
            
            (parent as! MeshNode).primitives.append(self)
        }
    }
    
    public final class IndicesNode: ColladaNode, ColladaNodeInternal {
        public var values = [UInt32]()
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            if let parent = parent as? TrianglesNode {
                parent.indices = self
            }
        }
        
        func parseCharacters(_ string: String) {
            values += string.components(separatedBy: .whitespaces()).flatMap { UInt32($0) }
        }
    }
    
    public final class LibraryVisualScenesNode: ColladaNode, ColladaNodeInternal {
        var visualScenes = [VisualSceneNode]()
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            (parent as! ColladaRootNode).children.append(self)
        }
    }
    
    public final class VisualSceneNode: ColladaNode, ColladaNodeInternal {
        var nodes = [NodeNode]()
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            (parent as! LibraryVisualScenesNode).visualScenes.append(self)
            
            if let id = attributeDict["id"] {
                idsToNodes[id] = self
            }
        }
    }
    
    public final class NodeNode: ColladaNode, ColladaNodeInternal {
        let name : String?
        var transformation : MatrixNode! = nil
        var instanceGeometries = [InstanceGeometryNode]()
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            self.name = attributeDict["name"]
            
            (parent as! VisualSceneNode).nodes.append(self)
            
            if let id = attributeDict["id"] {
                idsToNodes[id] = self
            }
        }
    }
    
    public final class MatrixNode: ColladaNode, ColladaNodeInternal {
        var values = [Float]()
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            (parent as! NodeNode).transformation = self
        }
        
        func parseCharacters(_ string: String) {
            values += string.components(separatedBy: .whitespaces()).flatMap { Float($0) }
        }
    }
    
    public final class InstanceGeometryNode: ColladaNode, ColladaNodeInternal {
        let geometry : GeometryNode
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            let geometryId = attributeDict["url"]!
            self.geometry = idsToNodes[geometryId.substring(from: geometryId.startIndex.advanced(by: 1))]! as! GeometryNode
            
            (parent as! NodeNode).instanceGeometries.append(self)
        }
    }
    
    public final class SceneNode: ColladaNode, ColladaNodeInternal {
        var instanceVisualScenes = [InstanceVisualSceneNode]()
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            (parent as! ColladaRootNode).children.append(self)
        }
    }
    
    public final class InstanceVisualSceneNode: ColladaNode, ColladaNodeInternal {
        let visualScene : VisualSceneNode
        
        init(parent: ColladaNodeInternal?, idsToNodes: inout [String : ColladaNode], attributes attributeDict: [String : String]) {
            let visualSceneId = attributeDict["url"]!
            self.visualScene = idsToNodes[visualSceneId.substring(from: visualSceneId.startIndex.advanced(by: 1))]! as! VisualSceneNode
            
            (parent as! SceneNode).instanceVisualScenes.append(self)
        }
    }
    
    public final class ColladaParser : NSObject, NSXMLParserDelegate {
        
        public var root : ColladaRootNode! = nil
        var nodeStack = [ColladaNodeInternal]()
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
            
            var type : ColladaNodeInternal.Type {
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
}

public func ==(lhs: Collada.SourceNode, rhs: Collada.SourceNode) -> Bool {
    return lhs === rhs
}