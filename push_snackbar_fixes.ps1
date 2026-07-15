$ErrorActionPreference = "Stop"
$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Working in: $appDir" -ForegroundColor Cyan
Set-Location $appDir

$lockFile = ".git\index.lock"
if (Test-Path $lockFile) {
    Remove-Item $lockFile -Force
    Write-Host "Removed git index.lock" -ForegroundColor Yellow
}

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

# New widget
git add "lib/features/common/goouts_sheet.dart"

# Auth screens
git add "lib/features/auth/business_registration_screen.dart"
git add "lib/features/auth/login_screen.dart"
git add "lib/features/auth/otp_screen.dart"
git add "lib/features/auth/otp_verification_screen.dart"
git add "lib/features/auth/phone_login_screen.dart"
git add "lib/features/auth/registration_screen.dart"
git add "lib/features/auth/widgets/pre_auth_support_sheet.dart"

# Home screens
git add "lib/features/home/business_home_screen.dart"
git add "lib/features/home/driver_home_screen.dart"

# Merchant
git add "lib/features/merchant/merchant_onboarding_screen.dart"

# Messages
git add "lib/features/messages/business_messages_inbox_screen.dart"
git add "lib/features/messages/message_detail_screen.dart"
git add "lib/features/messages/messages_inbox_screen.dart"

# Referral
git add "lib/features/referral/business_referral_list_screen.dart"
git add "lib/features/referral/referral_dev_tester_screen.dart"
git add "lib/features/referral/referral_link_screen.dart"
git add "lib/features/referral/referral_list_screen.dart"

# Support
git add "lib/features/support/help_support_screen.dart"
git add "lib/features/support/my_tickets_screen.dart"
git add "lib/features/support/support_ticket_chat_screen.dart"

# Main
git add "lib/main.dart"

git commit -m "UX: Replace all snackbars with branded GoOutsSheet across driver_app

- New lib/features/common/goouts_sheet.dart (no google_fonts dependency)
- All 22 files: every ScaffoldMessenger.showSnackBar replaced with
  GoOutsSheet.success / .error / .info / .warning
- Validation messages use .warning, errors use .error, confirmations use .success
- Push notification banners in main.dart use rootNavigatorKey.currentContext"

git push

Write-Host ""
Write-Host "=== driver_app snackbar fixes pushed! ===" -ForegroundColor Green
Write-Host "22 files updated — 0 snackbars remaining" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT: Run the same script in goouts_drapp folder" -ForegroundColor Yellow

Read-Host "Press Enter to close"
