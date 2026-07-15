@echo off
echo === Pushing ALL driver_app fixes ===
cd /d C:\Users\Maz\goouts\driver_app
del /f .git\index.lock 2>nul
del /f .git\index_backup 2>nul

git add -A
git commit -m "Fix: iOS app icon regenerated (correct logo), GoOutsSheet snackbar params, home screen ScaffoldMessenger orphan"
git push

echo === Done! ===
pause
