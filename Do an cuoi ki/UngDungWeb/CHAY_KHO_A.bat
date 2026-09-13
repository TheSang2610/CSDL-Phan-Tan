@echo off
chcp 65001 >nul
title Phan mem tram KHO_A
cd /d "%~dp0"
set SITE=KHO_A
node server.js
pause
