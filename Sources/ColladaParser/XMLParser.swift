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


open class XMLDocument {
    fileprivate let _documentPointer : xmlDocPtr!
    open var rootElement : XMLElement? = nil
    
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

open class XMLAttribute : XMLNode {
    fileprivate let _document : XMLDocument
    fileprivate let _attributePointer : xmlAttrPtr!
    open let name: String?
    
    init(document: XMLDocument, attributePointer: xmlAttrPtr) {
        _document = document
        _attributePointer = attributePointer
        
        self.name = String(cString: attributePointer.pointee.name)
    }
    
    open var stringValue: String? {
        if let value = xmlNodeListGetString(_attributePointer.pointee.doc, _attributePointer.pointee.children, 1) {
            defer { xmlFree(value) }
            
            return String(cString: value)
        } else {
            return nil
        }
    }
}

open class XMLElement : XMLNode {
    fileprivate let _document : XMLDocument
    fileprivate let _nodePointer : xmlNodePtr
    let childElements : [XMLElement]
    let attributes : [XMLAttribute]
    open let name : String?
    
    init(document: XMLDocument, nodePointer: xmlNodePtr) {
        _document = document
        _nodePointer = nodePointer
        self.name = String(cString: nodePointer.pointee.name)
        
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
    
    open var stringValue: String? {
        if let content = xmlNodeGetContent(_nodePointer) {
            defer { xmlFree(content) }
            return String(cString: content)
        } else {
            return nil
        }
    }

    open func attribute(forName name: String) -> XMLAttribute? {
        return self.attributes.filter { $0.name == name }.first
    }
    
    open func elements(forName name: String) -> [XMLElement] {
        return self.childElements.filter { $0.name == name }
    }
}
