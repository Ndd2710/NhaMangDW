@echo off
chcp 65001 >nul
cd /d "%~dp0"
python -B -X utf8 server.py
if errorlevel 1 pause
