@echo off
set XDG_CONFIG_HOME=%~dp0config
set XDG_DATA_HOME=%~dp0data
%~dp0neovide.exe --neovim-bin %~dp0nvim\bin\nvim.exe

