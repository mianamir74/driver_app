@echo off
echo === Pushing driver_app postcode fix ===
cd /d C:\Users\Maz\goouts\driver_app
git add lib/services/address_lookup_service.dart
git commit -m "Fix postcode lookup: switch Mapbox v6 to v5 API"
git push
echo === driver_app postcode fix pushed! ===
pause
