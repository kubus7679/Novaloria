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
    private var nodeCount = 0
    private var decodingError: FreeColProtocolError?

    public static func decode(_ xml: String) throws -> ParsedMessage {
        guard xml.utf8.count <= ProtocolLimits.maximumFrameBytes else {
            throw FreeColProtocolError.resourceLimitExceeded(
                "XML message exceeds \(ProtocolLimits.maximumFrameBytes) bytes"
            )
        }
        let decoder = XMLDecoder()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = decoder
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), let root = decoder.root else {
            if let decodingError = decoder.decodingError {
                throw decodingError
            }
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
        guard stack.count < ProtocolLimits.maximumXMLDepth else {
            decodingError = .resourceLimitExceeded(
                "XML nesting exceeds \(ProtocolLimits.maximumXMLDepth) levels"
            )
            parser.abortParsing()
            return
        }
        guard nodeCount < ProtocolLimits.maximumXMLNodes else {
            decodingError = .resourceLimitExceeded(
                "XML message exceeds \(ProtocolLimits.maximumXMLNodes) elements"
            )
            parser.abortParsing()
            return
        }
        nodeCount += 1
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
