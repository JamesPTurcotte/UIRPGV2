#!/usr/bin/env python3
"""Validate authored content without writing content/data.json."""

from build_content import build

if __name__ == "__main__":
    build(write=False)
