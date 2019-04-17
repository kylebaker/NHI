$ErrorActionPreference = 'Continue'

Import-Module Boxstarter.Chocolatey
Import-Module "$($Boxstarter.BaseDir)\Boxstarter.Common\boxstarter.common.psd1"

$packageName      = 'installer'
$toolsDir         = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$cache            =  "$env:userprofile\AppData\Local\ChocoCache"
$globalCinstArgs  = "--cacheLocation $cache -y"
$exercises         = "C:\Exercises"
$pkgPath          = Join-Path $toolsDir "packages.json"


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
  Write-Host "Now running CleanUp"
  # clean up the cache directory
  Remove-Item $cache -Recurse

  # Final commandovm installation
  iex "choco upgrade config -s C:\packages\"
}


function Main {
  InitialSetup

  cinst upgrade sms $globalCinstArgs
  cinst upgrade wms $globalCinstArgs


  CleanUp
  return 0
}

Enable-UAC
Enable-MicrosoftUpdate
Install-WindowsUpdate -acceptEula
if (Test-PendingReboot) { Invoke-Reboot }

Main