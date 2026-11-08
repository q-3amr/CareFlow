# CareFlow Android SDK Setup Script
# Run this script to install Java and Android SDK for building APKs

Write-Host "=== CareFlow Android SDK Setup ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Install Java JDK
Write-Host "Step 1: Installing Java JDK 17..." -ForegroundColor Yellow
winget install EclipseAdoptium.Temurin.17.JDK --accept-source-agreements --accept-package-agreements

# Wait for installation
Start-Sleep -Seconds 5

# Step 2: Set JAVA_HOME
Write-Host ""
Write-Host "Step 2: Setting JAVA_HOME environment variable..." -ForegroundColor Yellow
$javaPath = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Recurse -Filter "java.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($javaPath) {
    $javaHome = Split-Path (Split-Path $javaPath.FullName -Parent) -Parent
    [System.Environment]::SetEnvironmentVariable('JAVA_HOME', $javaHome, 'User')
    $env:JAVA_HOME = $javaHome
    Write-Host "JAVA_HOME set to: $javaHome" -ForegroundColor Green
} else {
    Write-Host "Java installation not found. Please restart and run this script again." -ForegroundColor Red
    exit 1
}

# Step 3: Set ANDROID_HOME (already created)
Write-Host ""
Write-Host "Step 3: Setting ANDROID_HOME..." -ForegroundColor Yellow
$androidHome = "$env:LOCALAPPDATA\Android\Sdk"
[System.Environment]::SetEnvironmentVariable('ANDROID_HOME', $androidHome, 'User')
$env:ANDROID_HOME = $androidHome
Write-Host "ANDROID_HOME set to: $androidHome" -ForegroundColor Green

# Step 4: Accept Android licenses
Write-Host ""
Write-Host "Step 4: Accepting Android SDK licenses..." -ForegroundColor Yellow
$sdkmanager = "$androidHome\cmdline-tools\latest\bin\sdkmanager.bat"
if (Test-Path $sdkmanager) {
    & $sdkmanager --licenses
} else {
    Write-Host "SDK Manager not found at: $sdkmanager" -ForegroundColor Red
}

# Step 5: Install required Android SDK packages
Write-Host ""
Write-Host "Step 5: Installing Android SDK packages..." -ForegroundColor Yellow
& $sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

Write-Host ""
Write-Host "=== Setup Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Close this PowerShell window"
Write-Host "2. Open a NEW PowerShell window (to reload environment variables)"
Write-Host "3. Navigate to: D:\Projects\CareFlow\careflow"
Write-Host "4. Run: C:\Users\qsya3\develop\flutter\bin\flutter.bat build apk --release"
Write-Host ""
Write-Host "Your APK will be created at:" -ForegroundColor Yellow
Write-Host "D:\Projects\CareFlow\careflow\build\app\outputs\flutter-apk\app-release.apk"
Write-Host ""
