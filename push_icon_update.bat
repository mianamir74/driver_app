@echo off
echo === Pushing driver_app icon update ===
cd /d C:\Users\Maz\goouts\driver_app
git add ios/Runner/Assets.xcassets/AppIcon.appiconset/
git add android/app/src/main/res/mipmap-mdpi/ic_launcher.png
git add android/app/src/main/res/mipmap-hdpi/ic_launcher.png
git add android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
git add android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
git add android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
git commit -m "Update app icon to thicker-line GoOuts logo"
git push
echo === driver_app icon pushed! ===
pause
