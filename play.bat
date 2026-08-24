@echo off
rem Launches the game with the engine that lives in this folder, on this folder's project.
rem
rem ONE ENGINE, ON PURPOSE. There is a second Godot in the user's ~/bin (4.6.1) and the nets have
rem always run on the 4.7.1 sitting here; running the game on a different build from the one the
rem checks run on is how "it works for me" gets written down as a green round.
cd /d "%~dp0"
start "" "%~dp0Godot_v4.7.1-stable_win64.exe" --path "%~dp0"
