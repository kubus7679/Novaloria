import Foundation

public struct ParsedMessage: Sendable {
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
    /// Reference-type builder so children can be appended in place. Copying the
    /// parent's `children` array on every completed element would make decoding
    /// quadratic in the number of elements.
    private final class NodeBuilder {
        let tag: String
        let attributes: Attributes
        var children: [ParsedMessage] = []

        init(tag: String, attributes: Attributes) {
            self.tag = tag
            self.attributes = attributes
        }
    }

    private var root: ParsedMessage?
    private var stack: [NodeBuilder] = []
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
        stack.append(NodeBuilder(tag: elementName, attributes: attributeDict))
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
        if let parent = stack.last {
            parent.children.append(node)
        } else {
            root = node
        }
    }
}
