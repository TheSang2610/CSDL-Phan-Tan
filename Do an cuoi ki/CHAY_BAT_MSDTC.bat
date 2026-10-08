@echo off
REM ===========================================================================
REM  Bam dup file nay. No se TU XIN quyen Administrator roi chay script MSDTC.
REM  Do an CSDL phan tan - Nhom 2
REM ===========================================================================
setlocal

set "PS1=%~dp0BatMSDTC_ChoGiaoTacPhanTan.ps1"

if not exist "%PS1%" (
    echo.
    echo   KHONG THAY FILE: %PS1%
    echo   Hai file .bat va .ps1 phai nam CHUNG MOT THU MUC.
    echo.
    pause
    exit /b 1
)

REM Da la admin chua?
net session >nul 2>&1
if %errorlevel%==0 goto :chay

echo.
echo   Dang xin quyen Administrator... bam YES o hop thoai hien ra.
echo.
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b

:chay
echo.
echo   Dang chay bang quyen Administrator.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
exit /b
