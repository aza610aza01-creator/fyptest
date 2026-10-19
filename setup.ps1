$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " AI Gym Cloud - Android Project Initialization (setup.ps1)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$backup = Join-Path $env:TEMP "ai_gym_cloud_source_backup"

# 1. Back up source files (lib, test, supabase, pubspec.yaml, analysis_options.yaml, README.md)
Write-Host "[1/10] Backing up project source files to $backup ..." -ForegroundColor Yellow
if (Test-Path $backup) {
    Remove-Item $backup -Recurse -Force
}
New-Item $backup -ItemType Directory | Out-Null
Copy-Item (Join-Path $root "lib") $backup -Recurse -Force
if (Test-Path (Join-Path $root "test")) {
    Copy-Item (Join-Path $root "test") $backup -Recurse -Force
}
if (Test-Path (Join-Path $root "supabase")) {
    Copy-Item (Join-Path $root "supabase") $backup -Recurse -Force
}
Copy-Item (Join-Path $root "pubspec.yaml") $backup -Force
Copy-Item (Join-Path $root "analysis_options.yaml") $backup -Force
if (Test-Path (Join-Path $root "README.md")) {
    Copy-Item (Join-Path $root "README.md") $backup -Force
}

Push-Location $root
try {
    # 2. Run flutter create for Android platform files
    Write-Host "[2/10] Generating Android platform files with flutter create ..." -ForegroundColor Yellow
    flutter create . --platforms=android --project-name=ai_gym_flutter
    if ($LASTEXITCODE -ne 0) {
        throw "flutter create failed with exit code $LASTEXITCODE"
    }

    # 3. Restore project source files
    Write-Host "[3/10] Restoring backed-up project source files ..." -ForegroundColor Yellow
    if (Test-Path (Join-Path $root "lib")) {
        Remove-Item (Join-Path $root "lib\*") -Recurse -Force -ErrorAction SilentlyContinue
    }
    Copy-Item (Join-Path $backup "lib\*") (Join-Path $root "lib") -Recurse -Force
    if (Test-Path (Join-Path $backup "test")) {
        if (-not (Test-Path (Join-Path $root "test"))) {
            New-Item (Join-Path $root "test") -ItemType Directory | Out-Null
        }
        Remove-Item (Join-Path $root "test\*") -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item (Join-Path $backup "test\*") (Join-Path $root "test") -Recurse -Force
    }
    if (Test-Path (Join-Path $backup "supabase")) {
        if (-not (Test-Path (Join-Path $root "supabase"))) {
            New-Item (Join-Path $root "supabase") -ItemType Directory | Out-Null
        }
        Copy-Item (Join-Path $backup "supabase\*") (Join-Path $root "supabase") -Recurse -Force
    }
    Copy-Item (Join-Path $backup "pubspec.yaml") (Join-Path $root "pubspec.yaml") -Force
    Copy-Item (Join-Path $backup "analysis_options.yaml") (Join-Path $root "analysis_options.yaml") -Force
    if (Test-Path (Join-Path $backup "README.md")) {
        Copy-Item (Join-Path $backup "README.md") (Join-Path $root "README.md") -Force
    }

    # 4 & 5. Add Android CAMERA and INTERNET permissions + optional camera feature declaration
    Write-Host "[4/10 & 5/10] Configuring AndroidManifest.xml permissions and camera feature ..." -ForegroundColor Yellow
    $manifest = Join-Path $root "android\app\src\main\AndroidManifest.xml"
    if (Test-Path $manifest) {
        $xml = Get-Content $manifest -Raw
        if ($xml -notmatch 'android.permission.CAMERA') {
            $permissionsBlock = "<manifest xmlns:android=`"http://schemas.android.com/apk/res/android`">`r`n" +
                "    <uses-permission android:name=`"android.permission.CAMERA`" />`r`n" +
                "    <uses-permission android:name=`"android.permission.INTERNET`" />`r`n" +
                "    <uses-feature android:name=`"android.hardware.camera`" android:required=`"false`" />"
            $xml = $xml -replace '<manifest xmlns:android="http://schemas.android.com/apk/res/android">', $permissionsBlock
            Set-Content $manifest $xml -Encoding UTF8
        }
    }

    # 6. Apply Gradle cache settings needed by this project
    Write-Host "[6/10] Applying Gradle properties and cache settings ..." -ForegroundColor Yellow
    $gradleProps = Join-Path $root "android\gradle.properties"
    if (Test-Path $gradleProps) {
        $propsContent = Get-Content $gradleProps -Raw
        if ($propsContent -notmatch 'kotlin.incremental=false') {
            Add-Content $gradleProps "`nkotlin.incremental=false`nkotlin.incremental.android=false`nkotlin.compiler.execution.strategy=in-process`norg.gradle.caching=false"
        }
    }

    # 7. Run flutter clean
    Write-Host "[7/10] Running flutter clean ..." -ForegroundColor Yellow
    flutter clean
    if ($LASTEXITCODE -ne 0) {
        throw "flutter clean failed with exit code $LASTEXITCODE"
    }

    # 8. Run flutter pub get
    Write-Host "[8/10] Running flutter pub get ..." -ForegroundColor Yellow
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get failed with exit code $LASTEXITCODE"
    }

    # 9. Run dart format
    Write-Host "[9/10] Formatting Dart code with dart format ..." -ForegroundColor Yellow
    dart format lib test
    if ($LASTEXITCODE -ne 0) {
        throw "dart format failed with exit code $LASTEXITCODE"
    }

    # 10. Run flutter analyze --no-fatal-infos
    Write-Host "[10/10] Running flutter analyze --no-fatal-infos ..." -ForegroundColor Yellow
    flutter analyze --no-fatal-infos
    if ($LASTEXITCODE -ne 0) {
        throw "flutter analyze failed with exit code $LASTEXITCODE"
    }

    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " Setup completed! Ready to run on your Android device." -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
}
catch {
    Write-Host "ERROR during setup: $_" -ForegroundColor Red
    Write-Host "Restoring source files from backup $backup ..." -ForegroundColor Yellow
    Copy-Item (Join-Path $backup "lib\*") (Join-Path $root "lib") -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path (Join-Path $backup "test")) {
        Copy-Item (Join-Path $backup "test\*") (Join-Path $root "test") -Recurse -Force -ErrorAction SilentlyContinue
    }
    Copy-Item (Join-Path $backup "pubspec.yaml") (Join-Path $root "pubspec.yaml") -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $backup "analysis_options.yaml") (Join-Path $root "analysis_options.yaml") -Force -ErrorAction SilentlyContinue
    throw
}
finally {
    Pop-Location
}
