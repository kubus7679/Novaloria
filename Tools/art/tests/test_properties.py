from novaloria_art.properties import parse_properties


def test_parses_separators_comments_and_continuations():
    text = (
        "# comment\n"
        "! also comment\n"
        "image.a=resources/a.png\n"
        "image.b : resources/b.png\n"
        "image.c resources/c.png\n"
        "image.d=resources/\\\n"
        "    d.png\n"
        "key\\ with\\ space=x\\u00e4\n"
    )
    assert parse_properties(text) == {
        "image.a": "resources/a.png",
        "image.b": "resources/b.png",
        "image.c": "resources/c.png",
        "image.d": "resources/d.png",
        "key with space": "x\u00e4",
    }


def test_later_duplicates_win():
    assert parse_properties("a=1\na=2\n") == {"a": "2"}
