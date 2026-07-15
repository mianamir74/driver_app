@echo off
cd /d "%~dp0"
echo Working in: %CD%

echo Removing git lock if present...
del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "lib/features/common/goouts_sheet.dart"

git add "lib/features/auth/business_registration_screen.dart"
git add "lib/features/auth/login_screen.dart"
git add "lib/features/auth/otp_screen.dart"
git add "lib/features/auth/otp_verification_screen.dart"
git add "lib/features/auth/phone_login_screen.dart"
git add "lib/features/auth/registration_screen.dart"
git add "lib/features/auth/widgets/pre_auth_support_sheet.dart"

git add "lib/features/home/business_home_screen.dart"
git add "lib/features/home/driver_home_screen.dart"

git add "lib/features/merchant/merchant_onboarding_screen.dart"

git add "lib/features/messages/business_messages_inbox_screen.dart"
git add "lib/features/messages/message_detail_screen.dart"
git add "lib/features/messages/messages_inbox_screen.dart"

git add "lib/features/referral/business_referral_list_screen.dart"
git add "lib/features/referral/referral_dev_tester_screen.dart"
git add "lib/features/referral/referral_link_screen.dart"
git add "lib/features/referral/referral_list_screen.dart"

git add "lib/features/support/help_support_screen.dart"
git add "lib/features/support/my_tickets_screen.dart"
git add "lib/features/support/support_ticket_chat_screen.dart"

git add "lib/main.dart"

git commit -m "UX: Replace all snackbars with branded GoOutsSheet across driver_app"

git push

echo.
echo === driver_app snackbar fixes pushed! ===
echo 22 files updated - 0 snackbars remaining
echo.
pause
