@echo off
echo === Pushing iOS permission fixes for driver_app ===
cd /d C:\Users\Maz\goouts\driver_app
del /f .git\index.lock 2>nul
del /f .git\index_backup 2>nul
git add ios/Runner/Info.plist
git commit -m "Add missing iOS permissions: NSCameraUsage, NSPhotoLibrary, NSLocation, NSFaceID"
git push
echo === Done! ===
pause
