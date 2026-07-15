@echo off
echo === Pushing driver_app codemagic.yaml update ===
cd /d C:\Users\Maz\goouts\driver_app
del /f .git\index.lock 2>nul
del /f .git\index_backup 2>nul

git add codemagic.yaml
git commit -m "Update: app name to GoOuts Lead in codemagic.yaml"
git push
echo === Done! ===
pause
