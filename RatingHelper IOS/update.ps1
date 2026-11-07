# ==============================================================================
# PowerShell-скрипт обновления RatingHelper для Windows
# ==============================================================================

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "🚀 Rating Helper 2.0.0 — Обновление приложения на iPhone" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Проверка usbipd и подключенного iPhone
$appleDevice = Get-PnpDevice -FriendlyName "*Apple Mobile Device*" -Status OK -ErrorAction SilentlyContinue
if ($null -ne $appleDevice) {
    Write-Host "✅ iPhone обнаружен в Windows: $($appleDevice.FriendlyName)" -ForegroundColor Green
} else {
    Write-Host "ℹ️ Подключите iPhone к компьютеру кабелем USB и разблокируйте экран." -ForegroundColor Yellow
}

# 2. Запуск сборки и обновления в WSL Ubuntu-24.04
Write-Host "`n🔨 Запуск сборки и обновления в WSL Ubuntu-24.04..." -ForegroundColor Cyan

$wslDistro = "Ubuntu-24.04"
$command = "cd /mnt/c/Users/Иван/Downloads/RatingHelper && chmod +x ./update.sh && ./update.sh"

wsl -d $wslDistro bash -c $command
