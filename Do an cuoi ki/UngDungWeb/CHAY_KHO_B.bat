@echo off
chcp 65001 >nul
title Phan mem tram KHO_B
cd /d "%~dp0"
set SITE=KHO_B
node server.js
pause
