@echo off
setlocal

REM Safe pub get for networks that MITM HTTPS with a custom root CA.
REM Preserves any existing DART_VM_OPTIONS and adds a Windows root cert bundle.

set "CERT_DIR=C:\certs"
set "CERT_FILE=%CERT_DIR%\windows-roots.pem"

if not exist "%CERT_DIR%" mkdir "%CERT_DIR%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0export_windows_roots.ps1" >nul
if errorlevel 1 (
  echo Failed to export Windows root certificates.
  exit /b 1
)

if defined DART_VM_OPTIONS (
  set "DART_VM_OPTIONS=%DART_VM_OPTIONS% --root-certs-file=%CERT_FILE%"
) else (
  set "DART_VM_OPTIONS=--root-certs-file=%CERT_FILE%"
)

echo Using DART_VM_OPTIONS=%DART_VM_OPTIONS%
flutter pub get %*
exit /b %ERRORLEVEL%
