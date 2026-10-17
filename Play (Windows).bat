@echo off
rem Last Night at Camp launcher for Windows. Imports the project on first run.
rem Needs Godot 4.7.2 (standard, not .NET). Put the Godot .exe in this folder,
rem in Downloads or Desktop, or set GODOT_BIN to its full path.
cd /d "%~dp0"
where py >nul 2>nul && (py -3 tools\run_game.py %* & goto :eof)
where python >nul 2>nul && (python tools\run_game.py %* & goto :eof)
set "GODOT=%GODOT_BIN%"
if "%GODOT%"=="" for %%F in ("%~dp0Godot_v4*.exe" "%USERPROFILE%\Downloads\Godot_v4*.exe" "%USERPROFILE%\Desktop\Godot_v4*.exe") do if exist "%%~F" set "GODOT=%%~F"
if "%GODOT%"=="" (
  echo Could not find Godot 4.7.2. Put the Godot .exe in this folder or set GODOT_BIN.
  pause
  goto :eof
)
rem Always import first: only new or changed files are processed (about 2 s
rem when up to date, about a minute the first time), so a partial import heals.
echo Checking imported assets...
"%GODOT%" --headless --path "%~dp0." --import
"%GODOT%" --path "%~dp0." %*
