#!/usr/bin/env python3
"""Validate Hyprveil settings using the checked-in JSON Schema subset."""

import json
import pathlib
import sys


def matches_type(value, expected):
    mapping = {
        "object": lambda item: isinstance(item, dict),
        "array": lambda item: isinstance(item, list),
        "string": lambda item: isinstance(item, str),
        "boolean": lambda item: isinstance(item, bool),
        "null": lambda item: item is None,
        "integer": lambda item: isinstance(item, int) and not isinstance(item, bool),
        "number": lambda item: isinstance(item, (int, float)) and not isinstance(item, bool),
    }
    choices = expected if isinstance(expected, list) else [expected]
    return any(mapping[name](value) for name in choices)


def validate(value, schema, path="$"):
    if "type" in schema and not matches_type(value, schema["type"]):
        raise ValueError(f"{path}: wrong type")
    if "const" in schema and value != schema["const"]:
        raise ValueError(f"{path}: expected {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        raise ValueError(f"{path}: unsupported value")
    if isinstance(value, str) and len(value) < schema.get("minLength", 0):
        raise ValueError(f"{path}: string is too short")
    if isinstance(value, dict):
        properties = schema.get("properties", {})
        for required in schema.get("required", []):
            if required not in value:
                raise ValueError(f"{path}.{required}: required key is missing")
        extra_schema = schema.get("additionalProperties", True)
        for key, child in value.items():
            if key in properties:
                validate(child, properties[key], f"{path}.{key}")
            elif extra_schema is False:
                raise ValueError(f"{path}.{key}: unknown key")
            elif isinstance(extra_schema, dict):
                validate(child, extra_schema, f"{path}.{key}")
    if isinstance(value, list) and "items" in schema:
        for index, child in enumerate(value):
            validate(child, schema["items"], f"{path}[{index}]")


def main():
    allow_v1 = "--allow-v1" in sys.argv[1:]
    args = [arg for arg in sys.argv[1:] if arg != "--allow-v1"]
    if len(args) != 2:
        raise SystemExit("usage: settings-validator.py [--allow-v1] SCHEMA DOCUMENT")
    schema = json.loads(pathlib.Path(args[0]).read_text())
    document = json.loads(pathlib.Path(args[1]).read_text())
    if allow_v1 and isinstance(document, dict) and document.get("version", 1) == 1:
        return
    validate(document, schema)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
