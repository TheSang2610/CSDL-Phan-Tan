@echo off
chcp 65001 >nul
title Phan mem tram KHO_C
cd /d "%~dp0"
set SITE=KHO_C
node server.js
pause
