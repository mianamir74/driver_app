@echo off
echo === Pushing ALL driver_app fixes ===
cd /d C:\Users\Maz\goouts\driver_app
del /f .git\index.lock 2>nul
del /f .git\index_backup 2>nul

git add -A
git commit -m "Fix: GoOutsSheet import in referral screen, my_tickets_screen action param, address_lookup_service, snackbar replacements, all dart fixes"
git push

echo === Done! ===
pause
