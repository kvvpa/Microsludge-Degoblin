<#
Registers the scheduled task for Microsludge Degoblin.

Run this once from an elevated PowerShell prompt. The task runs at logon,
waits two minutes, then calls the Windows Update-aware wrapper.
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
$helpers = Join-Path $scriptRoot "Microsludge-Degoblin.Helpers.ps1"
$wrapper = Join-Path $scriptRoot "Invoke-Microsludge-Degoblin-AfterWindowsUpdate.ps1"
$taskName = "Microsludge Degoblin After Windows Update"
$taskPath = "\Microsludge-Degoblin\"
$userId = "$env:USERDOMAIN\$env:USERNAME"

if (-not (Test-Path -LiteralPath $helpers)) {
    throw "Helper script not found: $helpers"
}

. $helpers

if (-not (Test-MicrosludgeIsAdmin)) {
    throw "This installer must be run as Administrator."
}

if (-not (Test-Path -LiteralPath $wrapper)) {
    throw "Wrapper script not found: $wrapper"
}

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
    ('"{0}"' -f $wrapper)
) + (Get-MicrosludgeSwitchArgumentList -Values $switchValues -Names (Get-MicrosludgeWrapperSwitchNames))

$argument = $taskArguments -join " "
$optionSummary = Get-MicrosludgeOptionSummary -Values $switchValues -Names (Get-MicrosludgeWrapperSwitchNames)

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

