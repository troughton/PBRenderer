//
//  XMLParser.swift
//  PBRenderer
//
//  Created by Joseph Bennett on 7/05/16.
//
//
import CLibXML2


public protocol XMLNode {
    var name: String? { get }
    var stringValue : String? { get }
}


public class XMLDocument {
    private let _documentPointer : xmlDocPtr!
    public var rootElement : XMLElement? = nil
    
    public init?(contentsOfFile filePath: String) {
        _documentPointer = xmlReadFile(filePath, nil, Int32(XML_PARSE_HUGE.rawValue))
        
        if _documentPointer == nil {
            return nil
        }
        
        let rootElementPointer = xmlDocGetRootElement(_documentPointer)
        self.rootElement = XMLElement(document: self, nodePointer: rootElementPointer!)
    }
    
    deinit {
        xmlFreeDoc(_documentPointer)
        xmlCleanupParser()
    }
    
}

public class XMLAttribute : XMLNode {
    private let _document : XMLDocument
    private let _attributePointer : xmlAttrPtr!
    public let name: String?
    
    init(document: XMLDocument, attributePointer: xmlAttrPtr) {
        _document = document
        _attributePointer = attributePointer
        
        self.name = String(cString: UnsafePointer<CChar>(attributePointer.pointee.name))
    }
    
    public var stringValue: String? {
        if let value = xmlNodeListGetString(_attributePointer.pointee.doc, _attributePointer.pointee.children, 1) {
            defer { xmlFree(value) }
            
            return String(cString: UnsafePointer<CChar>(value))
        } else {
            return nil
        }
    }
}

public class XMLElement : XMLNode {
    private let _document : XMLDocument
    private let _nodePointer : xmlNodePtr
    let childElements : [XMLElement]
    let attributes : [XMLAttribute]
    public let name : String?
    
    init(document: XMLDocument, nodePointer: xmlNodePtr) {
        _document = document
        _nodePointer = nodePointer
        self.name = String(cString: UnsafePointer<CChar>(nodePointer.pointee.name))
        
        var childElements = [XMLElement]()
        
        var currentNode : xmlNodePtr! =  _nodePointer.pointee.children
        while currentNode != nil {
            if currentNode.pointee.type == XML_ELEMENT_NODE {
                childElements.append(XMLElement(document: document, nodePointer: currentNode))
            }
            
            currentNode = currentNode.pointee.next
        }
        self.childElements = childElements
        
        var attributes = [XMLAttribute]()
        
        var currentAttribute : xmlAttrPtr! =  _nodePointer.pointee.properties
        while currentAttribute != nil {
            attributes.append(XMLAttribute(document: document, attributePointer: currentAttribute))
            currentAttribute = currentAttribute.pointee.next
        }
        self.attributes = attributes
    }
    
    public var stringValue: String? {
        if let content = xmlNodeGetContent(_nodePointer) {
            defer { xmlFree(content) }
            return String(cString: UnsafePointer<CChar>(content))
        } else {
            return nil
        }
    }

    public func attribute(forName name: String) -> XMLAttribute? {
        return self.attributes.filter { $0.name == name }.first
    }
    
    public func elements(forName name: String) -> [XMLElement] {
        return self.childElements.filter { $0.name == name }
    }
}