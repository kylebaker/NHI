$ErrorActionPreference = 'Continue'

$packageName = 'config'
$toolsDir    = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

function PinToTaskbar {
  # https://stackoverflow.com/questions/31720595/pin-program-to-taskbar-using-ps-in-windows-10
  param (
    [parameter(Mandatory=$True, HelpMessage="Target item to pin")]
    [ValidateNotNullOrEmpty()]
    [string] $Target
  )
  if (-Not (Test-Path $Target)) {
    Write-Warning "$Target does not exist"
    throw [System.IO.FileNotFoundException] "$Target does not exist"
  }

  $KeyPath1  = "HKCU:\SOFTWARE\Classes"
  $KeyPath2  = "*"
  $KeyPath3  = "shell"
  $KeyPath4  = "{:}"
  $ValueName = "ExplorerCommandHandler"
  $ValueData =
    (Get-ItemProperty `
        ("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\" + `
            "CommandStore\shell\Windows.taskbarpin")
    ).ExplorerCommandHandler

  $Key2 = (Get-Item $KeyPath1).OpenSubKey($KeyPath2, $true)
  $Key3 = $Key2.CreateSubKey($KeyPath3, $true)
  $Key4 = $Key3.CreateSubKey($KeyPath4, $true)
  $Key4.SetValue($ValueName, $ValueData)

  $Shell = New-Object -ComObject "Shell.Application"
  $Folder = $Shell.Namespace((Get-Item $Target).DirectoryName)
  $Item = $Folder.ParseName((Get-Item $Target).Name)
  $Item.InvokeVerb("{:}")

  $Key3.DeleteSubKey($KeyPath4)
  if ($Key3.SubKeyCount -eq 0 -and $Key3.ValueCount -eq 0) {
    $Key2.DeleteSubKey($KeyPath3)
  }
}

### Commando Windows 10 Attack VM ###
Write-Host "[+] Beginning host configuration..." -ForegroundColor Green


# #### Disable services ####
Write-Host "[-] Disabling services" -ForegroundColor Green
Set-Service OpenVPNService -StartupType Manual -ErrorAction SilentlyContinue 
Set-Service OpenVPNServiceInteractive -StartupType Manual -ErrorAction SilentlyContinue 
Set-Service OpenVPNServiceLegacy -StartupType Manual -ErrorAction SilentlyContinue 
Write-Host "`t[+] Disabled OpenVPN Services" -ForegroundColor Green
Set-Service neo4j -StartupType Manual -ErrorAction SilentlyContinue
Stop-Service -Name neo4j 
Write-Host "`t[+] Disabled Neo4j" -ForegroundColor Green
Set-Service OpenSSHd -StartupType Manual -ErrorAction SilentlyContinue
Stop-Service -Name OpenSSHd -ErrorAction SilentlyContinue
Write-Host "`t[+] Disabled OpenSSH Service" -ForegroundColor Green
Start-Sleep -Seconds 2


#### Remove Desktop Shortcuts ####
Write-Host "[+] Cleaning up the Desktop" -ForegroundColor Green
$shortcut_path = "C:\Users\Public\Desktop\Boxstarter Shell.lnk"
Remove-Item $shortcut_path -Force | Out-Null
Start-Sleep -Seconds 2
$shortcut_path = "$Env:USERPROFILE\Desktop\Microsoft Edge.lnk"
Remove-Item $shortcut_path -Force | Out-Null


#### Add timestamp to PowerShell prompt ####
$psprompt = @"
function prompt
{
    Write-Host "COMMANDO " -ForegroundColor Green -NoNewLine
    Write-Host `$(get-date) -ForegroundColor Green
    Write-Host  "PS" `$PWD ">" -nonewline -foregroundcolor White
    return " "
}
"@
New-Item -ItemType File -Path $profile -Force | Out-Null
Set-Content -Path $profile -Value $psprompt
# Add timestamp to cmd prompt
# Note: The string below is base64-encoded due to issues properly escaping the '$' character in PowersShell
#   Offending string: "Y21kIC9jICdzZXR4IFBST01QVCBDT01NQU5ETyRTJGQkcyR0JF8kcCQrJGcn"
#   Resolves to: "cmd /c 'setx PROMPT COMMANDO$S$d$s$t$_$p$+$g'"
iex ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("Y21kIC9jICdzZXR4IFBST01QVCBDT01NQU5ETyRTJGQkcyR0JF8kcCQrJGcn"))) | Out-Null
Write-Host "`t[+] Timestamps added to cmd prompt and PowerShell" -ForegroundColor Green


#### Pin Items to Taskbar ####
Write-Host "[-] Pinning items to Taskbar" -ForegroundColor Green

# Exploarer
$target_file = Join-Path ${Env:WinDir} "explorer.exe"
try {
  PinToTaskbar $target_file
} catch {
  Write-Host "Could not pin $target_file to the tasbar"
}

# SMS
$target_file = Join-Path ${Env:WinDir} "Program Files\SMS 13.0 64-bit\sms130.exe"
$target_dir = ${Env:UserProfile}
$shortcut = Join-Path ${Env:UserProfile} "temp\CMD.lnk"
Install-ChocolateyShortcut -shortcutFilePath $shortcut -targetPath $target_file -Arguments $target_args -WorkingDirectory $target_dir -PinToTaskbar -RunasAdmin
try {
  PinToTaskbar $shortcut
} catch {
  Write-Host "Could not pin $target_file to the tasbar"
}

# Powershell
$target_file = Join-Path (Join-Path ${Env:WinDir} "system32\WindowsPowerShell\v1.0") "powershell.exe"
$target_dir = ${Env:UserProfile}
$target_args = '-NoExit -Command "cd ' + "${Env:UserProfile}" + '"'
$shortcut = Join-Path ${Env:UserProfile} "temp\PowerShell.lnk"
Install-ChocolateyShortcut -shortcutFilePath $shortcut -targetPath $target_file -Arguments $target_args -WorkingDirectory $target_dir -PinToTaskbar -RunasAdmin
try {
  PinToTaskbar $shortcut
} catch {
  Write-Host "Could not pin $target_file to the tasbar"
}


#### Rename the computer ####
Write-Host "[+] Renaming host to 'commando'" -ForegroundColor Green
(Get-WmiObject win32_computersystem).rename("commando") | Out-Null
Write-Host "`t[-] Make sure to restart the machine for this change to take effect" -ForegroundColor Yellow
Write-Host "[+] Changing Desktop Background" -ForegroundColor Green


#### Update background ####
# Set desktop background to black
Set-ItemProperty -Path 'HKCU:\Control Panel\Colors' -Name Background -Value "0 0 0" -Force | Out-Null
Invoke-Expression "$WallpaperChanger $fileBackground 3"


# Copy readme.txt on the Desktop
Write-Host "[+] Copying README.txt to Desktop" -ForegroundColor Green
$fileReadme = Join-Path $toolsDir 'readme.txt'
$desktopReadme = Join-Path ${Env:USERPROFILE} "Desktop\README.txt"
Copy-Item $fileReadme $desktopReadme


# Remove desktop.ini files
Get-ChildItem -Path (Join-Path ${Env:UserProfile} "Desktop") -Hidden -Filter "desktop.ini" -Force | foreach {$_.Delete()}
Get-ChildItem -Path (Join-Path ${Env:Public} "Desktop") -Hidden -Filter "desktop.ini" -Force | foreach {$_.Delete()}


# Should be PS >5.1 now, enable transcription and script block logging
# More info: https://www.fireeye.com/blog/threat-research/2016/02/greater_visibilityt.html
if ($PSVersionTable -And $PSVersionTable.PSVersion.Major -ge 5) {
  $psLoggingPath = 'HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell'
  if (-Not (Test-Path $psLoggingPath)) {
    New-Item -Path $psLoggingPath -Force | Out-Null
  }
  $psLoggingPath = 'HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\Transcription'
  if (-Not (Test-Path $psLoggingPath)) {
    New-Item -Path $psLoggingPath -Force | Out-Null
  }
  New-ItemProperty -Path $psLoggingPath -Name "EnableInvocationHeader" -Value 1 -PropertyType DWORD -Force | Out-Null
  New-ItemProperty -Path $psLoggingPath -Name "EnableTranscripting" -Value 1 -PropertyType DWORD -Force | Out-Null
  New-ItemProperty -Path $psLoggingPath -Name "OutputDirectory" -Value (Join-Path ${Env:UserProfile} "Desktop\PS_Transcripts") -PropertyType String -Force | Out-Null
  
  $psLoggingPath = 'HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
  if (-Not (Test-Path $psLoggingPath)) {
    New-Item -Path $psLoggingPath -Force | Out-Null
  }
  New-ItemProperty -Path $psLoggingPath -Name "EnableScriptBlockLogging" -Value 1 -PropertyType DWORD -Force | Out-Null
}

# Done
Write-Host "[!] Done with configuration, shutting down Boxstarter..." -ForegroundColor Green