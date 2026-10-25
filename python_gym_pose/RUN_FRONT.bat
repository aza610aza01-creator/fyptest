@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (echo Run SETUP.bat first.&pause&exit /b 1)
".venv\Scripts\python.exe" gym_pose.py --exercise push_up --mode front
pause
