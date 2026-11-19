@echo off
rem Shortcut: build.bat [release] is socletool build.
rem Every other step: odin run tools/socletool -collection:gt=ext/gui_toolkit/src -out:build/socletool -- <command> (help lists them).
cd /d "%~dp0"
if not exist build mkdir build
odin run tools/socletool -collection:gt=ext/gui_toolkit/src -out:build/socletool -keep-executable -- build %*
