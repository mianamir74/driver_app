@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "assets/logo/"
git add "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
git add "android/app/src/main/res/"

git commit -m "Update app icon and logo to thick-line version"

git push

echo.
echo === driver_app logo pushed! ===
echo Trigger new Codemagic build at https://codemagic.io/apps
echo.
pause
