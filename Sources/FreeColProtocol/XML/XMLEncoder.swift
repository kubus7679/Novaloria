import Foundation

public enum XMLEncoder {
    public static func encode(tag: String, attributes: Attributes, children: [ParsedMessage] = []) -> String {
        let attrString = attributes.isEmpty ? "" : " " + attributes
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\"\(xmlEscape($0.value))\"" }
            .joined(separator: " ")

        if children.isEmpty {
            return "<\(tag)\(attrString)/>"
        }

        let body = children.map { child in
            encode(tag: child.tag, attributes: child.attributes, children: child.children)
        }.joined()

        return "<\(tag)\(attrString)>\(body)</\(tag)>"
    }

    private static func xmlEscape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
