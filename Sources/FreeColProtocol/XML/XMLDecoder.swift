import Foundation

public struct ParsedMessage {
    public let tag: String
    public let attributes: Attributes
    public let children: [ParsedMessage]

    public init(tag: String, attributes: Attributes, children: [ParsedMessage]) {
        self.tag = tag
        self.attributes = attributes
        self.children = children
    }
}

public final class XMLDecoder: NSObject, XMLParserDelegate {
    private var root: ParsedMessage?
    private var stack: [(tag: String, attributes: Attributes, children: [ParsedMessage])] = []

    public static func decode(_ xml: String) throws -> ParsedMessage {
        let decoder = XMLDecoder()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = decoder
        guard parser.parse(), let root = decoder.root else {
            throw FreeColProtocolError.parseError(parser.parserError)
        }
        return root
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        stack.append((elementName, attributeDict, []))
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard let completed = stack.popLast(), completed.tag == elementName else { return }
        let node = ParsedMessage(
            tag: completed.tag,
            attributes: completed.attributes,
            children: completed.children
        )
        if let parent = stack.popLast() {
            var children = parent.children
            children.append(node)
            stack.append((parent.tag, parent.attributes, children))
        } else {
            root = node
        }
    }
}
