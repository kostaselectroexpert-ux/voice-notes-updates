$ErrorActionPreference = "Stop"

function Fail([string]$m) {
  Write-Host ""
  Write-Host "ΣΦΑΛΜΑ: $m" -ForegroundColor Red
  Read-Host "Πάτησε Enter"
  exit 1
}

function IsAdmin {
  $id=[Security.Principal.WindowsIdentity]::GetCurrent()
  $p=New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (IsAdmin)) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
  exit
}

Clear-Host
Write-Host "VOICE NOTES V15 - GITHUB INTERNET UPDATE" -ForegroundColor Cyan
Write-Host ""

$candidates=@(
  "C:\VOICE-NOTES-ANDROID-V13\VOICE_NOTES_V13_FIREBASE",
  "C:\VOICE-NOTES-ANDROID-V12\VOICE_NOTES_V12_FIREBASE"
)
$project=$null
foreach($c in $candidates){
  if(Test-Path (Join-Path $c "app\build.gradle")){$project=$c;break}
}
if(!$project){Fail "Δεν βρέθηκε το Android project V13/V12."}

$main=Join-Path $project "app\src\main\java\com\voicenotes\kb\MainActivity.java"
$gradleFile=Join-Path $project "app\build.gradle"
$keyPath="C:\VOICE-NOTES-KEYS\voice-notes-release.jks"
$keyInfo="C:\VOICE-NOTES-KEYS\voice-notes-key.properties"
$gradle="C:\Gradle\gradle-8.9\bin\gradle.bat"
$sdk=Join-Path $env:LOCALAPPDATA "Android\Sdk"
$outApk=Join-Path $env:USERPROFILE "Downloads\VOICE_NOTES_V15_GITHUB.apk"
$baseUrl="https://raw.githubusercontent.com/kostaselectroexpert-ux/voice-notes-updates/main"

if(!(Test-Path $main)){Fail "Δεν βρέθηκε MainActivity.java"}
if(!(Test-Path $keyPath)-or !(Test-Path $keyInfo)){Fail "Δεν βρέθηκε το μόνιμο κλειδί υπογραφής."}
if(!(Test-Path $gradle)){Fail "Δεν βρέθηκε Gradle 8.9."}

Write-Host "[1/4] Backup..." -ForegroundColor Yellow
$stamp=Get-Date -Format "yyyyMMdd_HHmmss"
$backup="$project-BACKUP-GITHUB-$stamp"
Copy-Item -Recurse -Force $project $backup

Write-Host "[2/4] Ρυθμίζω ενημερώσεις από GitHub μέσω Internet..." -ForegroundColor Yellow
$src=[IO.File]::ReadAllText($main)

# onCreate: είτε από την αρχική V13 είτε από την αποτυχημένη V14/Firebase προσπάθεια
$src=[regex]::Replace(
  $src,
  'updateBaseUrl\s*=\s*prefs\.getString\(KEY_LAN_BASE_URL,\s*null\);\s*startUpdateCenterDiscovery\(\);\s*// only for APK updates on the local Wi-Fi',
  'updateBaseUrl = "'+$baseUrl+'";'+"\r\n"+'        prefs.edit().putString(KEY_LAN_BASE_URL, updateBaseUrl).apply();',
  1
)
$src=$src.Replace('updateBaseUrl = "https://voice-notes-kb.web.app";','updateBaseUrl = "'+$baseUrl+'";')

# Update JSON στο root του GitHub repo
$src=$src.Replace('base + "/voice-notes/update.json?ts="','base + "/update.json?ts="')
$src=$src.Replace('o.optString("apkPath", "/voice-notes/latest.apk")','o.optString("apkPath", "/VOICE_NOTES_LATEST.apk")')

# Κείμενα εφαρμογής
$src=$src.Replace('Ενημέρωση εφαρμογής μέσω Wi‑Fi','Ενημέρωση εφαρμογής μέσω Internet')
$src=$src.Replace('Update Center δεν βρέθηκε ακόμη στο ίδιο Wi‑Fi','Internet Update Center')
$src=$src.Replace('Update Center Online • πάτησε για έλεγχο','Internet • Wi‑Fi ή 4G/5G • πάτησε για έλεγχο')
$src=$src.Replace('Το APK θα κατέβει από το laptop μέσω του ίδιου Wi‑Fi.','Το APK θα κατέβει από το Internet μέσω GitHub. Μπορείς να είσαι σε οποιοδήποτε Wi‑Fi ή σε 4G/5G.')
$src=$src.Replace('μέσω Wi‑Fi...','μέσω Internet...')
$src=$src.Replace('Δεν μπόρεσα να επικοινωνήσω με το Update Center.','Δεν μπόρεσα να ελέγξω για ενημέρωση μέσω Internet.')

# Σε αποτυχία κρατάμε πάντα το GitHub URL
$src=$src.Replace('updateBaseUrl = null;'+[Environment]::NewLine+'                    updateTopStatusIcons();'+[Environment]::NewLine+'                    toast("Δεν μπόρεσα να ελέγξω για ενημέρωση μέσω Internet.");',
                  'updateBaseUrl = "'+$baseUrl+'";'+[Environment]::NewLine+'                    updateTopStatusIcons();'+[Environment]::NewLine+'                    toast("Δεν μπόρεσα να ελέγξω για ενημέρωση μέσω Internet.");')
$src=$src.Replace('updateBaseUrl = null;'+[Environment]::NewLine+'                    updateTopStatusIcons();'+[Environment]::NewLine+'                    toast("Δεν μπόρεσα να επικοινωνήσω με το Update Center.");',
                  'updateBaseUrl = "'+$baseUrl+'";'+[Environment]::NewLine+'                    updateTopStatusIcons();'+[Environment]::NewLine+'                    toast("Δεν μπόρεσα να ελέγξω για ενημέρωση μέσω Internet.");')

# Αν το project ήταν ήδη V14 από το προηγούμενο script, αλλάζουμε τα labels
$src=$src.Replace('"VOICE NOTES V14 • Internet Update"','"VOICE NOTES V15 • GitHub Internet Update"')
$src=$src.Replace('"VOICE NOTES V13 • Φωτογραφίες • LAN • Στατιστικά"','"VOICE NOTES V15 • GitHub Internet Update"')
$src=$src.Replace('.setTitle("VOICE NOTES V14")','.setTitle("VOICE NOTES V15")')
$src=$src.Replace('.setTitle("VOICE NOTES V13")','.setTitle("VOICE NOTES V15")')

$utf8=New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($main,$src,$utf8)

$g=[IO.File]::ReadAllText($gradleFile)
$g=[regex]::Replace($g,'versionCode\s+\d+','versionCode 15')
$g=[regex]::Replace($g,'versionName\s+"[^"]+"','versionName "15.0"')
[IO.File]::WriteAllText($gradleFile,$g,$utf8)
[IO.File]::WriteAllText((Join-Path $project "local.properties"),"sdk.dir="+$sdk.Replace("\","/"),$utf8)

Write-Host "[3/4] Build V15 με το μόνιμο κλειδί..." -ForegroundColor Yellow
$props=@{}
Get-Content $keyInfo | ForEach-Object {
  if($_ -match '^([^=]+)=(.*)$'){$props[$matches[1]]=$matches[2]}
}
$pass=$props["storePassword"]
$alias=$props["keyAlias"]
if(!$alias){$alias="voicenotes"}
if(!$pass){Fail "Δεν βρέθηκε storePassword."}

Push-Location $project
& $gradle --no-daemon clean assembleRelease `
 "-PVOICE_NOTES_KEYSTORE=$keyPath" `
 "-PVOICE_NOTES_STORE_PASSWORD=$pass" `
 "-PVOICE_NOTES_KEY_ALIAS=$alias" `
 "-PVOICE_NOTES_KEY_PASSWORD=$pass"
$buildCode=$LASTEXITCODE
Pop-Location
if($buildCode -ne 0){Fail "Το Android build απέτυχε."}

$built=Join-Path $project "app\build\outputs\apk\release\app-release.apk"
if(!(Test-Path $built)){Fail "Δεν βρέθηκε το APK."}
Copy-Item -Force $built $outApk

Write-Host "[4/4] V15 έτοιμη." -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " V15 ΕΤΟΙΜΗ ΓΙΑ GITHUB" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "APK:" -ForegroundColor Cyan
Write-Host $outApk -ForegroundColor White
Write-Host ""
Write-Host "Τώρα ανέβασε αυτό το APK στο repository voice-notes-updates." -ForegroundColor Cyan
Write-Host "ΜΗΝ αλλάξεις το όνομα του αρχείου." -ForegroundColor Yellow

try {
  Start-Process "https://github.com/kostaselectroexpert-ux/voice-notes-updates/upload/main"
  Start-Process explorer.exe "/select,`"$outApk`""
} catch {}

Read-Host "Πάτησε Enter"
