<#
Registers the scheduled task for Microsludge Degoblin.

Run this once from an elevated PowerShell prompt. The task runs at logon,
waits two minutes, then calls the installed Windows Update-aware wrapper.
#>

param(
    [switch]$AlwaysApply,
    [switch]$BlockOneDrive,
    [switch]$RemoveOneDrive,
    [switch]$DisableEdgeUpdates,
    [switch]$DisableWindowsAI,
    [switch]$SkipCopilot,
    [switch]$SkipOneDrive,
    [switch]$SkipEdge,
    [switch]$SkipOutlook,
    [switch]$SkipConsumerContent
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$helpers = Join-Path $scriptRoot "Microsludge-Degoblin.Helpers.ps1"
$sourceWrapper = Join-Path $scriptRoot "Invoke-Microsludge-Degoblin-AfterWindowsUpdate.ps1"
$taskName = "Microsludge Degoblin After Windows Update"
$taskPath = "\Microsludge-Degoblin\"
$userId = "$env:USERDOMAIN\$env:USERNAME"

if (-not (Test-Path -LiteralPath $helpers)) {
    throw "Helper script not found: $helpers"
}

. $helpers

function Copy-MicrosludgePackageToInstallRoot {
    param(
        [string]$SourceRoot,
        [string]$InstallRoot
    )

    $expectedInstallRoot = Get-MicrosludgeInstallRoot
    $actualFullPath = [System.IO.Path]::GetFullPath($InstallRoot).TrimEnd("\")
    $expectedFullPath = [System.IO.Path]::GetFullPath($expectedInstallRoot).TrimEnd("\")
    if ($actualFullPath -ne $expectedFullPath) {
        throw "Refusing to install to unexpected path: $InstallRoot"
    }

    if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot "Scripts"))) {
        throw "Source Scripts folder not found: $SourceRoot"
    }

    $sourceFullPath = [System.IO.Path]::GetFullPath($SourceRoot).TrimEnd("\")
    if ($sourceFullPath -eq $actualFullPath) {
        Write-Host "Source is already the installed package copy. Skipping copy refresh."
        return
    }

    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null

    $directories = @("Scripts", "Assets")
    foreach ($directory in $directories) {
        $sourcePath = Join-Path $SourceRoot $directory
        $destinationPath = Join-Path $InstallRoot $directory
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            continue
        }

        if (Test-Path -LiteralPath $destinationPath) {
            Remove-Item -LiteralPath $destinationPath -Recurse -Force
        }

        Copy-Item -LiteralPath $sourcePath -Destination $InstallRoot -Recurse -Force
    }

    Get-ChildItem -LiteralPath $SourceRoot -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch "^\." } |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $InstallRoot -Force
        }
}

if (-not (Test-MicrosludgeIsAdmin)) {
    throw "This installer must be run as Administrator."
}

if (-not (Test-Path -LiteralPath $sourceWrapper)) {
    throw "Wrapper script not found: $sourceWrapper"
}

$installRoot = Get-MicrosludgeInstallRoot
Copy-MicrosludgePackageToInstallRoot -SourceRoot $repoRoot -InstallRoot $installRoot

$installedScriptsRoot = Join-Path $installRoot "Scripts"
$installedWrapper = Join-Path $installedScriptsRoot "Invoke-Microsludge-Degoblin-AfterWindowsUpdate.ps1"
$installedVersion = Get-MicrosludgeVersion -Root $installRoot
$installedLogRoot = Join-Path $installRoot "Logs"

if (-not (Test-Path -LiteralPath $installedWrapper)) {
    throw "Installed wrapper script not found: $installedWrapper"
}

New-Item -ItemType Directory -Force -Path $installedLogRoot | Out-Null

$switchValues = @{
    AlwaysApply = $AlwaysApply.IsPresent
    BlockOneDrive = $BlockOneDrive.IsPresent
    RemoveOneDrive = $RemoveOneDrive.IsPresent
    DisableEdgeUpdates = $DisableEdgeUpdates.IsPresent
    DisableWindowsAI = $DisableWindowsAI.IsPresent
    SkipCopilot = $SkipCopilot.IsPresent
    SkipOneDrive = $SkipOneDrive.IsPresent
    SkipEdge = $SkipEdge.IsPresent
    SkipOutlook = $SkipOutlook.IsPresent
    SkipConsumerContent = $SkipConsumerContent.IsPresent
}

$taskArguments = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-WindowStyle",
    "Hidden",
    "-File",
    ('"{0}"' -f $installedWrapper)
) + (Get-MicrosludgeSwitchArgumentList -Values $switchValues -Names (Get-MicrosludgeWrapperSwitchNames))

$argument = $taskArguments -join " "
$optionSummary = Get-MicrosludgeOptionSummary -Values $switchValues -Names (Get-MicrosludgeWrapperSwitchNames)

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument $argument `
    -WorkingDirectory $installRoot

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
$trigger.Delay = "PT2M"

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

$principal = New-ScheduledTaskPrincipal `
    -UserId $userId `
    -LogonType Interactive `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $taskName `
    -TaskPath $taskPath `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Runs Microsludge Degoblin $installedVersion after logon only when Windows Update evidence is found. Options: $optionSummary." `
    -Force | Out-Null

Write-Host "Installed package copy: $installRoot"
Write-Host "Installed version: $installedVersion"
Write-Host "Scheduled task wrapper: $installedWrapper"
Write-Host "Installed logs: $installedLogRoot"

Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath |
    Select-Object TaskName, TaskPath, State
