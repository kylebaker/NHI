$ErrorActionPreference = 'Continue'

Import-Module Boxstarter.Chocolatey
Import-Module "$($Boxstarter.BaseDir)\Boxstarter.Common\boxstarter.common.psd1"

$packageName      = 'installer'
$toolsDir         = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$cache            =  "$env:userprofile\AppData\Local\ChocoCache"
$globalCinstArgs  = "--cacheLocation $cache -y"
$exercises         = "C:\Exercises"
$pkgPath          = Join-Path $toolsDir "packages.json"


# https://stackoverflow.com/questions/28077854/powershell-2-0-convertfrom-json-and-convertto-json-implementation
function ConvertFrom-Json([object] $item) {
  Add-Type -Assembly system.web.extensions
  $ps_js = New-Object system.web.script.serialization.javascriptSerializer

  #The comma operator is the array construction operator in PowerShell
  return ,$ps_js.DeserializeObject($item)
}

function LoadPackages {
  try {
    $json = Get-Content $pkgPath -ErrorAction Stop
    $packages = ConvertFrom-Json $json
  } catch {
    return $null
  }
  return $packages
}

function InstallOnePackage {
  param([hashtable] $pkg)
  $name = $pkg.name
  $pkgargs = $pkg.args
  try {
    $is64Only = $pkg.x64Only
  } catch {
    $is64Only = $false
  }

  if ($is64Only) {
    if (Get-OSArchitectureWidth -Compare 64) {
      # pass
    } else {
      Write-Warning "[!] Not installing $name on x86 systems"
      return $true
    }
  }

  if ($pkgargs -eq $null) {
    $args = $globalCinstArgs
  } else {
    $args = $pkgargs,$globalCinstArgs -Join " "
  }

  if ($args -like "*-source*" -Or $args -like "*--package-parameters*" -Or $args -like "*--parameters*") {
    Write-Warning "[!] Installing using host choco.exe! Errors are ignored. Please check to confirm $name is installed properly"
    Write-Warning "[!] Executing: iex choco upgrade $name $args"
    $rc = iex "choco upgrade $name $args"
    Write-Host $rc
  } else {
    choco upgrade $name $args
  }

  if ($([System.Environment]::ExitCode) -ne 0 -And $([System.Environment]::ExitCode) -ne 3010) {
    Write-Host "ExitCode: $([System.Environment]::ExitCode)"
    return $false
  }
  return $true
}

function InitialSetup {
  # Basic system setup
  Update-ExecutionPolicy Unrestricted
  Set-WindowsExplorerOptions -EnableShowProtectedOSFiles -EnableShowFileExtensions -EnableShowHiddenFilesFoldersDrives
  Disable-MicrosoftUpdate
  Disable-BingSearch
  Disable-GameBarTips
  Disable-ComputerRestore -Drive ${Env:SystemDrive}

  # Chocolatey setup
  Write-Host "Initializing chocolatey"
  iex "choco feature enable -n allowGlobalConfirmation"
  iex "choco feature enable -n allowEmptyChecksums"

  # Create the cache directory
  New-Item -Path $cache -ItemType directory -Force

  # Create excercises folder if it doesn't exist
  if (-Not (Test-Path -Path $exercises) ) {
    New-Item -Path $exercises -ItemType directory
  }

  $desktopShortcut = Join-Path ${Env:UserProfile} "Desktop\Exercises.lnk"
  Install-ChocolateyShortcut -shortcutFilePath $desktopShortcut -targetPath $exercises

  # Set common paths in environment variables
  Install-ChocolateyEnvironmentVariable -VariableName "FLARE_START" -VariableValue $toolList -VariableType 'Machine'
  Install-ChocolateyEnvironmentVariable -VariableName "TOOL_LIST_SHORTCUT" -VariableValue $toolList -VariableType 'Machine'
  refreshenv

  # BoxStarter setup
  Set-BoxstarterConfig -LocalRepo "C:\packages\"

  # Tweak power options to prevent installs from timing out
  & powercfg -change -monitor-timeout-ac 0 | Out-Null
  & powercfg -change -monitor-timeout-dc 0 | Out-Null
  & powercfg -change -disk-timeout-ac 0 | Out-Null
  & powercfg -change -disk-timeout-dc 0 | Out-Null
  & powercfg -change -standby-timeout-ac 0 | Out-Null
  & powercfg -change -standby-timeout-dc 0 | Out-Null
  & powercfg -change -hibernate-timeout-ac 0 | Out-Null
  & powercfg -change -hibernate-timeout-dc 0 | Out-Null
}


function CleanUp
{
  # clean up the cache directory
  Remove-Item $cache -Recurse

  # Final commandovm installation
  iex "choco upgrade config -s C:\packages\"
}


function Main {
  InitialSetup

  $json = LoadPackages $pkgPath
  if ($json -eq $null -Or $json.packages -eq $null) {
    Write-Host "Packages property not found! Exiting"
    return -1
  }

  $packages = $json.packages
  foreach ($pkg in $packages) {
    $name = $pkg.name
    $rc = InstallOnePackage $pkg
    if ($rc) {
      # Try not to get rate-limited
      if (-Not ($name.Contains(".flare") -or $name.Contains(".fireeye"))) {
        Start-Sleep -Seconds 5
      }
    } else {
      Write-Error "Failed to install $name"
    }
  }

  CleanUp
  return 0
}

Enable-UAC
Enable-MicrosoftUpdate
Install-WindowsUpdate -acceptEula
if (Test-PendingReboot) { Invoke-Reboot }

Main