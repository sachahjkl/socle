#!/usr/bin/env bash
# Shortcut: ./build.sh [release] is socletool build.
# Every other step: odin run tools/socletool -collection:gt=ext/gui_toolkit/src -out:build/socletool -- <command> (help lists them).
cd "$(dirname "$0")" && mkdir -p build && exec odin run tools/socletool -collection:gt=ext/gui_toolkit/src -out:build/socletool -keep-executable -- build "$@"
