# DEN Deployment & Update Synchronization Script
# Usage: .\scripts\deploy.ps1

Write-Host "Starting DEN Build & Sync Process..." -ForegroundColor Cyan

# 1. Run Flutter Build
Write-Host "Building APK..." -ForegroundColor Yellow
flutter build apk
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed!"
    exit 1
}

# 2. Extract Version from pubspec.yaml
Write-Host "Extracting version from pubspec.yaml..." -ForegroundColor Yellow
$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match "version:\s*([0-9\.\+a-zA-Z]+)") {
    $fullVersion = $Matches[1].Trim()
    if ($fullVersion -match "([0-9\.]+)") {
        $versionName = $Matches[1]
    } else {
        $versionName = $fullVersion
    }
} else {
    Write-Error "Could not find version in pubspec.yaml"
    exit 1
}
Write-Host "Version detected: $versionName" -ForegroundColor Green

# 3. Calculate APK Size
Write-Host "Calculating APK size..." -ForegroundColor Yellow
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    $sizeBytes = (Get-Item $apkPath).Length
    $sizeMB = [Math]::Round($sizeBytes / 1MB, 1)
    $sizeString = "$sizeMB MB"
} else {
    Write-Error "APK not found!"
    exit 1
}
Write-Host "APK Size: $sizeString" -ForegroundColor Green

# 4. Update website/update.json
Write-Host "Updating website metadata..." -ForegroundColor Yellow
$updateJsonPath = "den_website/update.json"
if (Test-Path $updateJsonPath) {
    # Load JSON and handle as a hashtable for robustness
    $jsonObj = Get-Content $updateJsonPath | ConvertFrom-Json
    $data = @{}
    foreach ($prop in $jsonObj.psobject.Properties) {
        $data[$prop.Name] = $prop.Value
    }
    
    # Update/Add fields
    $data["latest_version"] = $versionName
    $data["apk_size"] = $sizeString
    $data["apk_direct_url"] = "https://github.com/mrsastaproo/website-apk/releases/latest/download/DEN.apk"

    # Convert back to JSON and Save
    $data | ConvertTo-Json | Set-Content $updateJsonPath
    Write-Host "website/update.json updated successfully!" -ForegroundColor Green
} else {
    Write-Warning "update.json not found in website folder."
}

Write-Host "Build and Sync Complete! You can now upload the APK to GitHub." -ForegroundColor Cyan
