#!/usr/bin/env python3
"""Tiny, intentionally strict Gogo -> Estragon IR compiler (stage 0).

No runtime dependency on Godot, no Godot scene/Control generation.
Only gogo:View and gogo:Rect are currently implemented.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET
from typing import Any

GOGO_NAMESPACE = "urn:estragon:gogo:1"
IR_FORMAT = "estragon.gogo.ir"
IR_VERSION = 1
COLOR_RE = re.compile(r"#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?\Z")


class GogoError(ValueError):
    """A source file violates the supported Gogo language subset."""


def _tag_name(element: ET.Element) -> str:
    tag = element.tag
    prefix = "{" + GOGO_NAMESPACE + "}"
    if not isinstance(tag, str) or not tag.startswith(prefix):
        raise GogoError(
            "Every component must be in the Gogo namespace "
            f"({GOGO_NAMESPACE}); found {tag!r}"
        )
    return tag[len(prefix) :]


def _validate_attributes(element: ET.Element, allowed: set[str]) -> None:
    unexpected = set(element.attrib) - allowed
    if unexpected:
        raise GogoError(
            f"<{_tag_name(element)}> has unsupported attributes: "
            + ", ".join(sorted(unexpected))
        )


def _required(element: ET.Element, name: str) -> str:
    value = element.get(name)
    if value is None:
        raise GogoError(f"<{_tag_name(element)}> requires '{name}'")
    return value


def _number(element: ET.Element, name: str, default: float | None = None,
            *, strictly_positive: bool = False) -> int | float:
    raw = element.get(name)
    if raw is None:
        if default is None:
            raise GogoError(f"<{_tag_name(element)}> requires '{name}'")
        value = float(default)
    else:
        try:
            value = float(raw)
        except ValueError as exc:
            raise GogoError(
                f"<{_tag_name(element)}> '{name}' must be a number, got {raw!r}"
            ) from exc

    if not math.isfinite(value):
        raise GogoError(f"<{_tag_name(element)}> '{name}' must be finite")
    if strictly_positive and value <= 0:
        raise GogoError(f"<{_tag_name(element)}> '{name}' must be positive")
    return int(value) if value.is_integer() else value


def _fill_color(element: ET.Element) -> str:
    raw = _required(element, "fill")
    if COLOR_RE.fullmatch(raw) is None:
        raise GogoError(
            f"<{_tag_name(element)}> 'fill' must be #RRGGBB or #RRGGBBAA"
        )
    value = raw.lower()
    if len(value) == 7:
        value += "ff"
    return value


def _no_text(element: ET.Element) -> None:
    if element.text and element.text.strip():
        raise GogoError(f"<{_tag_name(element)}> does not support text content")
    for child in element:
        if child.tail and child.tail.strip():
            raise GogoError(
                f"<{_tag_name(element)}> does not support mixed text content"
            )


def _compile_element(
    element: ET.Element, known_ids: set[str], *, root: bool
) -> dict[str, Any]:
    name = _tag_name(element)
    _no_text(element)
    element_id = element.get("id")
    if element_id is not None:
        if not element_id.strip():
            raise GogoError(f"<{name}> 'id' cannot be blank")
        if element_id in known_ids:
            raise GogoError(f"Duplicate component id: {element_id!r}")
        known_ids.add(element_id)

    if name == "View" and root:
        _validate_attributes(element, {"id", "width", "height"})
        node = {
            "type": "View",
            "props": {
                "width": _number(element, "width", strictly_positive=True),
                "height": _number(element, "height", strictly_positive=True),
            },
            "children": [
                _compile_element(child, known_ids, root=False) for child in element
            ],
        }
    elif name == "Rect" and not root:
        _validate_attributes(element, {"id", "x", "y", "width", "height", "fill"})
        if len(element):
            raise GogoError("<Rect> cannot have child components")
        node = {
            "type": "Rect",
            "props": {
                "x": _number(element, "x", default=0),
                "y": _number(element, "y", default=0),
                "width": _number(element, "width", strictly_positive=True),
                "height": _number(element, "height", strictly_positive=True),
                "fill": _fill_color(element),
            },
        }
    else:
        raise GogoError(
            f"Unsupported Gogo component <{name}> at "
            + ("document root" if root else "child level")
        )

    if element_id is not None:
        node["id"] = element_id
    return node


def compile_source(xml_source: str) -> dict[str, Any]:
    """Compile the supported Gogo subset to a UI IR, without Godot nodes."""
    try:
        element = ET.fromstring(xml_source)
    except ET.ParseError as exc:
        raise GogoError(f"Malformed Gogo XML: {exc}") from exc

    return {
        "format": IR_FORMAT,
        "version": IR_VERSION,
        "root": _compile_element(element, set(), root=True),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Compile an experimental .gogo file to Estragon UI IR."
    )
    parser.add_argument("source", type=Path, help="Input .gogo source")
    parser.add_argument(
        "-o", "--output", required=True, type=Path,
        help="Output versioned JSON IR"
    )
    args = parser.parse_args(argv)

    try:
        source = args.source.read_text(encoding="utf-8")
        compiled = compile_source(source)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps(compiled, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    except (OSError, GogoError) as exc:
        print(f"gogo: {exc}", file=sys.stderr)
        return 1

    print(f"Generated {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
