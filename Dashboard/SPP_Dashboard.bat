@echo off
title SPP Dashboard
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dashboard.ps1"
if errorlevel 1 pause
