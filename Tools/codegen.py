#!/usr/bin/env python3
"""
Python code generator: reads Java FreeCol message classes and generates Swift stubs.

Usage:
    python3 Tools/codegen.py <path-to-freecol-src> <output-dir>

Example:
    python3 Tools/codegen.py ../freecol/src Sources/FreeColProtocol/Messages
"""

import os
import re
import sys
from pathlib import Path
from typing import Optional

SWIFT_KEYWORDS = {
    "private", "public", "internal", "fileprivate", "open",
    "class", "struct", "enum", "protocol", "extension",
    "let", "var", "func", "static", "import", "return",
    "if", "else", "for", "while", "switch", "case",
    "default", "break", "continue", "catch", "throw",
    "throws", "try", "async", "await", "actor",
    "associatedtype", "where", "typealias",
    "true", "false", "nil", "self", "Type",
    "rethrows", "inout", "nonisolated", "isolated",
    "repeat", "do", "fallthrough",
}


def escape_swift(name: str) -> str:
    if name in SWIFT_KEYWORDS:
        return f"`{name}`"
    return name


def read_java_file(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_tag(content: str) -> Optional[str]:
    m = re.search(r'public static final String TAG\s*=\s*"([^"]+)"', content)
    return m.group(1) if m else None


def extract_class_name(content: str) -> Optional[str]:
    m = re.search(r'public (?:abstract )?class (\w+Message)\s+extends\s+(\w+)', content)
    return m.group(1) if m else None


def extract_parent(content: str) -> Optional[str]:
    m = re.search(r'public (?:abstract )?class \w+Message\s+extends\s+(\w+)', content)
    return m.group(1) if m else None


def extract_attributes(content: str) -> list[str]:
    """
    Extract attribute key constants from the Java source.
    Looks for: private static final String FOO_TAG = "foo";
    """
    attrs = []
    for m in re.finditer(r'private static final String (\w+_TAG)\s*=\s*"(\w+)"', content):
        attrs.append(m.group(2))
    # Also look for attribute names in super() constructor calls
    for m in re.finditer(r'super\(\s*TAG\s*,\s*xr\s*,', content):
        super_call = content[m.start():m.end()+200]
        attrs_in_super = re.findall(r'"(\w+)"', super_call.split(")")[0])
        for a in attrs_in_super:
            if a not in ("login", "error", "multiple", "question", "reply",
                         "update", "partial", "remove", "addPlayer",
                         "startGame", "endTurn", "newTurn", "setCurrentPlayer",
                         "gameState", "vacantPlayers", "disconnect"):
                if a not in attrs:
                    attrs.append(a)
    return list(set(attrs))


def is_trivial(content: str) -> bool:
    return "extends TrivialMessage" in content


def is_attribute_message(content: str) -> bool:
    return "extends AttributeMessage" in content


def is_object_message(content: str) -> bool:
    return "extends ObjectMessage" in content


def has_children(content: str) -> bool:
    return "appendChild" in content or "getChildren" in content or "readFreeColObject" in content


def is_current_player_message(content: str) -> bool:
    return 'currentPlayerMessage()' in content and 'return true' in content


def get_priority(content: str) -> str:
    m = re.search(r'return\s+Message\.MessagePriority\.(\w+)', content)
    return m.group(1) if m else "NORMAL"


def generate_swift_tag_only(class_name: str, tag: str, priority: str,
                            current_player: bool) -> str:
    """Generate Swift for a TrivialMessage subclass."""
    struct_name = class_name.replace("Message", "")
    lines = [
        "import Foundation",
        "",
        f"public struct {struct_name}Message: FreeColMessage {{",
        f'    public static let tag = "{tag}"',
        "",
        "    public init() {}",
        "",
        "    public init(attributes: Attributes, children: Children) throws {",
        "        // No attributes or children expected",
        "    }",
        "",
        "    public func encode() -> (attributes: Attributes, children: Children) {",
        "        return ([:], [])",
        "    }",
        "}",
        "",
    ]
    return "\n".join(lines)


def generate_swift_attribute(class_name: str, tag: str, attrs: list[str],
                              priority: str, current_player: bool) -> str:
    """Generate Swift for an AttributeMessage subclass."""
    struct_name = class_name.replace("Message", "")
    prop_lines = []
    init_params = []
    init_assignments = []
    encode_lines = []
    for a in attrs:
        prop_name = escape_swift(a.replace("-", "_").replace(" ", "_"))
        prop_lines.append(f"    public let {prop_name}: String?")
        init_params.append(f"        {prop_name}: String? = nil")
        init_assignments.append(f"        self.{prop_name} = {prop_name}")
        encode_lines.append(f'        if let v = {prop_name} {{ attrs["{a}"] = v }}')

    lines = [
        "import Foundation",
        "",
        f"public struct {struct_name}Message: FreeColMessage {{",
        f'    public static let tag = "{tag}"',
        "",
    ]
    lines.extend(prop_lines)
    lines.append("")
    lines.append("    public init(")
    lines.append(",\n".join(init_params))
    lines.append("    ) {")
    lines.extend(init_assignments)
    lines.append("    }")
    lines.append("")
    lines.append("    public init(attributes: Attributes, children: Children) throws {")
    for a in attrs:
        prop_name = escape_swift(a.replace("-", "_").replace(" ", "_"))
        lines.append(f'        self.{prop_name} = attributes["{a}"]')
    lines.append("    }")
    lines.append("")
    lines.append("    public func encode() -> (attributes: Attributes, children: Children) {")
    lines.append("        var attrs: Attributes = [:]")
    lines.extend(encode_lines)
    lines.append("        return (attrs, [])")
    lines.append("    }")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def generate_swift_object(class_name: str, tag: str, attrs: list[str],
                           priority: str, current_player: bool) -> str:
    """Generate Swift for an ObjectMessage subclass (attributes + children)."""
    struct_name = class_name.replace("Message", "")
    prop_lines = []
    init_params = []
    init_assignments = []
    encode_attrs = []
    for a in attrs:
        prop_name = escape_swift(a.replace("-", "_").replace(" ", "_"))
        prop_lines.append(f"    public let {prop_name}: String?")
        init_params.append(f"        {prop_name}: String? = nil")
        init_assignments.append(f"        self.{prop_name} = {prop_name}")
        encode_attrs.append(f'        if let v = {prop_name} {{ attrs["{a}"] = v }}')

    lines = [
        "import Foundation",
        "",
        f"public struct {struct_name}Message: FreeColMessage {{",
        f'    public static let tag = "{tag}"',
        "",
    ]
    lines.extend(prop_lines)
    lines.append("    public let children: [ParsedMessage]")
    lines.append("")
    lines.append("    public init(")
    lines.append(",\n".join(init_params))
    lines.append("    ) {")
    lines.extend(init_assignments)
    lines.append("        self.children = []")
    lines.append("    }")
    lines.append("")
    lines.append("    public init(attributes: Attributes, children: Children) throws {")
    for a in attrs:
        prop_name = escape_swift(a.replace("-", "_").replace(" ", "_"))
        lines.append(f'        self.{prop_name} = attributes["{a}"]')
    lines.append("        self.children = children.compactMap { dict in")
    lines.append("            guard let tag = dict.keys.first else { return nil }")
    lines.append("            return ParsedMessage(tag: tag, attributes: [:], children: [])")
    lines.append("        }")
    lines.append("    }")
    lines.append("")
    lines.append("    public func encode() -> (attributes: Attributes, children: Children) {")
    lines.append("        var attrs: Attributes = [:]")
    lines.extend(encode_attrs)
    lines.append("        return (attrs, [])")
    lines.append("    }")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def generate_message_registry(messages: list[tuple[str, str]]) -> str:
    """Generate the MessageRegistry.swift file."""
    lines = [
        "import Foundation",
        "",
        "/// Maps XML tag names to their corresponding FreeColMessage types.",
        "public let messageRegistry: [String: FreeColMessage.Type] = [",
    ]
    for tag, class_name in sorted(messages, key=lambda x: x[0]):
        lines.append(f'    "{tag}": {class_name}.self,')
    lines.append("]")
    lines.append("")
    return "\n".join(lines)


def process_file(java_path: Path, output_dir: Path) -> Optional[tuple[str, str]]:
    content = read_java_file(java_path)
    class_name = extract_class_name(content)
    tag = extract_tag(content)

    if not class_name or not tag:
        return None

    parent = extract_parent(content)
    priority = get_priority(content)
    is_cpm = is_current_player_message(content)

    if is_trivial(content) and parent == "TrivialMessage":
        swift = generate_swift_tag_only(class_name, tag, priority, is_cpm)
    elif is_attribute_message(content) or parent == "AttributeMessage":
        attrs = extract_attributes(content)
        if has_children(content):
            swift = generate_swift_object(class_name, tag, attrs, priority, is_cpm)
        else:
            swift = generate_swift_attribute(class_name, tag, attrs, priority, is_cpm)
    elif is_object_message(content) or parent == "ObjectMessage":
        attrs = extract_attributes(content)
        swift = generate_swift_object(class_name, tag, attrs, priority, is_cpm)
    else:
        attrs = extract_attributes(content)
        swift = generate_swift_attribute(class_name, tag, attrs, priority, is_cpm)

    output_file = output_dir / f"{class_name}.swift"
    output_file.write_text(swift, encoding="utf-8")
    print(f"  Generated: {output_file.name}")

    struct_name = class_name.replace("Message", "")
    return (tag, f"{struct_name}Message")


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 Tools/codegen.py <freecol-src-dir> <output-dir>")
        sys.exit(1)

    src_dir = Path(sys.argv[1]) / "net" / "sf" / "freecol" / "common" / "networking"
    output_dir = Path(sys.argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)

    if not src_dir.exists():
        print(f"Error: Source directory not found: {src_dir}")
        sys.exit(1)

    print(f"Reading Java messages from: {src_dir}")
    print(f"Writing Swift messages to:   {output_dir}")

    messages = []
    for java_file in sorted(src_dir.glob("*Message.java")):
        result = process_file(java_file, output_dir)
        if result:
            messages.append(result)

    # Generate MessageRegistry
    registry = generate_message_registry(messages)
    registry_file = output_dir / "MessageRegistry.swift"
    registry_file.write_text(registry, encoding="utf-8")
    print(f"\n  Generated: {registry_file.name}")
    print(f"\nTotal: {len(messages)} message types")


if __name__ == "__main__":
    main()
