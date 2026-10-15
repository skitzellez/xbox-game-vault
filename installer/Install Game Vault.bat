@echo off
rem Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
rem PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
rem Game Vault all-in-one setup: run on a Windows PC on the same network as the Xbox (Dev Mode).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0GameVault-Setup.ps1" %*
echo.
pause
