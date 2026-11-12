@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\TrienKhai.ps1" %*
if errorlevel 1 (
 echo Cai dat chua hoan tat. Doc loi ben tren; khong xoa hoac seed lai database dang co.
 pause
 exit /b 1
)
echo Xem ket qua ben tren. Khi da trien khai thanh cong, mo demo\Mo_Demo.cmd.
pause
