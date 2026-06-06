<#
Registers the scheduled task for Microsludge Degoblin.

Run this once from an elevated PowerShell prompt. The task runs at logon,
waits two minutes, then calls the Windows Update-aware wrapper.
#>

param(
    [switch]$BlockOneDrive,
    [switch]$RemoveOneDrive,
    [switch]$DisableEdgeUpdates,
    [switch]$SkipCopilot,
    [switch]$SkipOneDrive,
    [switch]$SkipEdge,
    [switch]$SkipOutlook,
    [switch]$SkipConsumerContent
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$wrapper = Join-Path $scriptRoot "Invoke-Microsludge-Degoblin-AfterWindowsUpdate.ps1"
$taskName = "Microsludge Degoblin After Windows Update"
$taskPath = "\Microsludge-Degoblin\"
$userId = "$env:USERDOMAIN\$env:USERNAME"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    throw "This installer must be run as Administrator."
}

if (-not (Test-Path -LiteralPath $wrapper)) {
    throw "Wrapper script not found: $wrapper"
}

$argument = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $wrapper
if ($BlockOneDrive) {
    $argument += " -BlockOneDrive"
}
if ($RemoveOneDrive) {
    $argument += " -RemoveOneDrive"
}
if ($DisableEdgeUpdates) {
    $argument += " -DisableEdgeUpdates"
}
if ($SkipCopilot) {
    $argument += " -SkipCopilot"
}
if ($SkipOneDrive) {
    $argument += " -SkipOneDrive"
}
if ($SkipEdge) {
    $argument += " -SkipEdge"
}
if ($SkipOutlook) {
    $argument += " -SkipOutlook"
}
if ($SkipConsumerContent) {
    $argument += " -SkipConsumerContent"
}

$options = @()
if ($BlockOneDrive) {
    $options += "BlockOneDrive"
}
if ($RemoveOneDrive) {
    $options += "RemoveOneDrive"
}
if ($DisableEdgeUpdates) {
    $options += "DisableEdgeUpdates"
}
if ($SkipCopilot) {
    $options += "SkipCopilot"
}
if ($SkipOneDrive) {
    $options += "SkipOneDrive"
}
if ($SkipEdge) {
    $options += "SkipEdge"
}
if ($SkipOutlook) {
    $options += "SkipOutlook"
}
if ($SkipConsumerContent) {
    $options += "SkipConsumerContent"
}
$optionSummary = if ($options.Count -gt 0) { $options -join ", " } else { "default" }

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument $argument `
    -WorkingDirectory $scriptRoot

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
    -Description "Runs Microsludge Degoblin after logon only when the last reboot appears tied to Windows Update. Options: $optionSummary." `
    -Force | Out-Null

Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath |
    Select-Object TaskName, TaskPath, State

