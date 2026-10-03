$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Read-Host "Press Enter"
    exit 1
}

function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Is-Admin)) {
    $arg = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arg
    exit
}

Clear-Host
Write-Host "VOICE NOTES V15 - GITHUB INTERNET UPDATE" -ForegroundColor Cyan
Write-Host ""

$candidates = @(
    "C:\VOICE-NOTES-ANDROID-V13\VOICE_NOTES_V13_FIREBASE",
    "C:\VOICE-NOTES-ANDROID-V12\VOICE_NOTES_V12_FIREBASE"
)

$project = $null
foreach ($c in $candidates) {
    if (Test-Path (Join-Path $c "app\build.gradle")) {
        $project = $c
        break
    }
}
if (-not $project) { Fail "Android project V13/V12 not found." }

$main = Join-Path $project "app\src\main\java\com\voicenotes\kb\MainActivity.java"
$gradleFile = Join-Path $project "app\build.gradle"
$keyPath = "C:\VOICE-NOTES-KEYS\voice-notes-release.jks"
$keyInfo = "C:\VOICE-NOTES-KEYS\voice-notes-key.properties"
$gradle = "C:\Gradle\gradle-8.9\bin\gradle.bat"
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$outApk = Join-Path $env:USERPROFILE "Downloads\VOICE_NOTES_LATEST.apk"
$outJson = Join-Path $env:USERPROFILE "Downloads\update.json"
$githubBase = "https://raw.githubusercontent.com/kostaselectroexpert-ux/voice-notes-updates/main"

if (!(Test-Path $main)) { Fail "MainActivity.java not found." }
if (!(Test-Path $gradleFile)) { Fail "app\build.gradle not found." }
if (!(Test-Path $keyPath)) { Fail "Release keystore not found." }
if (!(Test-Path $keyInfo)) { Fail "Key properties not found." }
if (!(Test-Path $gradle)) { Fail "Gradle 8.9 not found." }

Write-Host "[1/4] Backup..." -ForegroundColor Yellow
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backup = $project + "-BACKUP-GITHUB-" + $stamp
Copy-Item -Recurse -Force $project $backup

Write-Host "[2/4] Switching updater to GitHub Internet..." -ForegroundColor Yellow
$src = [IO.File]::ReadAllText($main)

$oldBlock = @'
        updateBaseUrl = prefs.getString(KEY_LAN_BASE_URL, null);
        startUpdateCenterDiscovery(); // only for APK updates on the local Wi-Fi
'@

$newBlock = @'
        updateBaseUrl = "https://raw.githubusercontent.com/kostaselectroexpert-ux/voice-notes-updates/main";
        prefs.edit().putString(KEY_LAN_BASE_URL, updateBaseUrl).apply();
'@

if ($src.Contains($oldBlock)) {
    $src = $src.Replace($oldBlock, $newBlock)
}

$firebaseLine = 'updateBaseUrl = "https://voice-notes-kb.web.app";'
$githubLine = 'updateBaseUrl = "https://raw.githubusercontent.com/kostaselectroexpert-ux/voice-notes-updates/main";'
$src = $src.Replace($firebaseLine, $githubLine)

$methodMarker = "// GITHUB_UPDATE_BASE"
if (-not $src.Contains($methodMarker)) {
    $methodOld = '    private void checkForAppUpdate() {'
    $methodNew = '    private void checkForAppUpdate() {' + [Environment]::NewLine +
                 '        updateBaseUrl = "https://raw.githubusercontent.com/kostaselectroexpert-ux/voice-notes-updates/main"; // GITHUB_UPDATE_BASE'
    $src = $src.Replace($methodOld, $methodNew)
}

$src = $src.Replace('base + "/voice-notes/update.json?ts="', 'base + "/update.json?ts="')
$src = $src.Replace('o.optString("apkPath", "/voice-notes/latest.apk")', 'o.optString("apkPath", "/VOICE_NOTES_LATEST.apk")')
$src = $src.Replace('Ενημέρωση εφαρμογής μέσω Wi‑Fi', 'Ενημέρωση εφαρμογής μέσω Internet')
$src = $src.Replace('Update Center δεν βρέθηκε ακόμη στο ίδιο Wi‑Fi', 'Internet Update Center')
$src = $src.Replace('Update Center Online • πάτησε για έλεγχο', 'Internet • Wi‑Fi ή 4G/5G • πάτησε για έλεγχο')
$src = $src.Replace('Το APK θα κατέβει από το laptop μέσω του ίδιου Wi‑Fi.', 'Το APK θα κατέβει μέσω Internet από το GitHub.')
$src = $src.Replace('μέσω Wi‑Fi...', 'μέσω Internet...')
$src = $src.Replace('Δεν μπόρεσα να επικοινωνήσω με το Update Center.', 'Δεν μπόρεσα να ελέγξω για ενημέρωση μέσω Internet.')
$src = $src.Replace('"VOICE NOTES V13 • Φωτογραφίες • LAN • Στατιστικά"', '"VOICE NOTES V15 • GitHub Internet Update"')
$src = $src.Replace('"VOICE NOTES V14 • Internet Update"', '"VOICE NOTES V15 • GitHub Internet Update"')
$src = $src.Replace('.setTitle("VOICE NOTES V13")', '.setTitle("VOICE NOTES V15")')
$src = $src.Replace('.setTitle("VOICE NOTES V14")', '.setTitle("VOICE NOTES V15")')

$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($main, $src, $utf8)

$g = [IO.File]::ReadAllText($gradleFile)
$g = [regex]::Replace($g, 'versionCode\s+\d+', 'versionCode 15')
$g = [regex]::Replace($g, 'versionName\s+"[^"]+"', 'versionName "15.0"')
[IO.File]::WriteAllText($gradleFile, $g, $utf8)

$sdkForward = $sdk.Replace("\", "/")
[IO.File]::WriteAllText((Join-Path $project "local.properties"), "sdk.dir=" + $sdkForward, $utf8)

Write-Host "[3/4] Building V15..." -ForegroundColor Yellow
$props = @{}
Get-Content $keyInfo | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $props[$matches[1]] = $matches[2]
    }
}
$pass = $props["storePassword"]
$alias = $props["keyAlias"]
if (-not $alias) { $alias = "voicenotes" }
if (-not $pass) { Fail "storePassword not found." }

$gradleArgs = @(
    "--no-daemon",
    "clean",
    "assembleRelease",
    "-PVOICE_NOTES_KEYSTORE=$keyPath",
    "-PVOICE_NOTES_STORE_PASSWORD=$pass",
    "-PVOICE_NOTES_KEY_ALIAS=$alias",
    "-PVOICE_NOTES_KEY_PASSWORD=$pass"
)

Push-Location $project
& $gradle @gradleArgs
$buildCode = $LASTEXITCODE
Pop-Location

if ($buildCode -ne 0) { Fail "Android build failed." }

$built = Join-Path $project "app\build\outputs\apk\release\app-release.apk"
if (!(Test-Path $built)) { Fail "Built APK not found." }
Copy-Item -Force $built $outApk

$meta = @'
{
  "versionCode": 15,
  "versionName": "15.0",
  "apkPath": "/VOICE_NOTES_LATEST.apk"
}
'@
[IO.File]::WriteAllText($outJson, $meta, $utf8)

Write-Host "[4/4] Done." -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " V15 READY FOR GITHUB" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "APK: $outApk" -ForegroundColor White
Write-Host "JSON: $outJson" -ForegroundColor White
Write-Host ""
Write-Host "A GitHub upload page will open now." -ForegroundColor Cyan
Write-Host "Upload ONLY this file from Downloads:" -ForegroundColor Cyan
Write-Host "  VOICE_NOTES_LATEST.apk" -ForegroundColor White

try {
    Start-Process "https://github.com/kostaselectroexpert-ux/voice-notes-updates/upload/main"
    Start-Process explorer.exe (Join-Path $env:USERPROFILE "Downloads")
} catch {}

Read-Host "Press Enter"