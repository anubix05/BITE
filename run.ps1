# ─────────────────────────────────────────────────────────────────────────────
# Bite – Run on Android Emulator
# Usage: .\run.ps1
# ─────────────────────────────────────────────────────────────────────────────

Write-Host "Starting Bite on Android emulator..." -ForegroundColor Cyan

# Launch the first available Android emulator (if none is running)
$runningEmulator = & puro flutter devices 2>&1 | Select-String "emulator"
if (-not $runningEmulator) {
    Write-Host "No emulator detected. Attempting to boot one..." -ForegroundColor Yellow
    $avd = & "$env:ANDROID_HOME\emulator\emulator" -list-avds 2>&1 | Select-Object -First 1
    if ($avd) {
        Start-Process -NoNewWindow -FilePath "$env:ANDROID_HOME\emulator\emulator" -ArgumentList "-avd", $avd
        Write-Host "Waiting for emulator to boot..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    } else {
        Write-Host "ERROR: No AVDs found. Please create one in Android Studio first." -ForegroundColor Red
        exit 1
    }
}

# Run Flutter on the emulator
puro flutter run -d emulator
