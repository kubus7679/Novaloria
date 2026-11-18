"""Reader for Java ``.properties`` files as used by FreeCol resource mappings."""

from __future__ import annotations

from collections.abc import Iterator
from pathlib import Path

_ESCAPES = {"t": "\t", "n": "\n", "r": "\r", "f": "\f"}
_SEPARATORS = "=: \t\f"


def _logical_lines(text: str) -> Iterator[str]:
    pending = ""
    for raw in text.splitlines():
        line = raw.lstrip()
        if not pending and (not line or line[0] in "#!"):
            continue
        trailing = len(line) - len(line.rstrip("\\"))
        if trailing % 2 == 1:
            pending += line[:-1]
            continue
        yield pending + line
        pending = ""
    if pending:
        yield pending


def _unescape(value: str) -> str:
    out: list[str] = []
    index = 0
    while index < len(value):
        char = value[index]
        if char == "\\" and index + 1 < len(value):
            following = value[index + 1]
            if following == "u" and index + 6 <= len(value):
                out.append(chr(int(value[index + 2 : index + 6], 16)))
                index += 6
                continue
            out.append(_ESCAPES.get(following, following))
            index += 2
            continue
        out.append(char)
        index += 1
    return "".join(out)


def _split(line: str) -> tuple[str, str]:
    index = 0
    while index < len(line):
        char = line[index]
        if char == "\\":
            index += 2
            continue
        if char in _SEPARATORS:
            break
        index += 1
    key = line[:index]
    rest = line[index:].lstrip(" \t\f")
    if rest[:1] in ("=", ":"):
        rest = rest[1:].lstrip(" \t\f")
    return _unescape(key), _unescape(rest)


def parse_properties(text: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in _logical_lines(text):
        key, value = _split(line)
        if key:
            result[key] = value
    return result


def read_properties(path: Path) -> dict[str, str]:
    return parse_properties(path.read_text(encoding="latin-1"))
