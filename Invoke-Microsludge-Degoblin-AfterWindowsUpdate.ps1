<#
Runs Microsludge-Degoblin.ps1 only when the last reboot appears tied to Windows Update.

This wrapper is meant for Task Scheduler. It logs either the Windows Update evidence it
found or the reason it skipped the run. Use -AlwaysApply to bypass the Windows
Update evidence gate and run at every scheduled launch.
#>

param(
    [switch]$TestOnly,
    [switch]$AlwaysApply,
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
$helpers = Join-Path $scriptRoot "Microsludge-Degoblin.Helpers.ps1"
$targetScript = Join-Path $scriptRoot "Microsludge-Degoblin.ps1"
$logRoot = Join-Path $scriptRoot "Logs"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logPath = Join-Path $logRoot "Microsludge-Degoblin-Auto-$timestamp.log"

if (-not (Test-Path -LiteralPath $helpers)) {
    throw "Helper script not found: $helpers"
}

. $helpers

New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

function Write-AutoLog {
    param([string]$Message)

    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    Write-Output $line
    Add-Content -Path $logPath -Value $line
}

function Get-LastBootTime {
    return (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
}

function Get-WindowsUpdateRebootEvidence {
    param([datetime]$LastBootTime)

    $evidence = New-Object System.Collections.Generic.List[string]
    $now = Get-Date
    $preBootStart = $LastBootTime.AddHours(-24)
    $postBootEnd = $LastBootTime.AddHours(2)
    if ($postBootEnd -gt $now) {
        $postBootEnd = $now
    }

    $updatePattern = "Windows Update|UpdateOrchestrator|UsoClient|MoUsoCoreWorker|MusNotification|hotfix|servicing|service pack|reboot|restart|required|successfully installed|installation successful"

    try {
        $restartEvents = Get-WinEvent -FilterHashtable @{
            LogName = "System"
            Id = 1074
            StartTime = $preBootStart
            EndTime = $LastBootTime.AddMinutes(10)
        } -ErrorAction SilentlyContinue

        foreach ($event in $restartEvents) {
            if ($event.Message -match $updatePattern) {
                $evidence.Add("System event 1074 at $($event.TimeCreated): $($event.ProviderName)")
            }
        }
    } catch {
        $evidence.Add("Unable to inspect System restart events: $($_.Exception.Message)")
    }

    try {
        $updateEvents = Get-WinEvent -FilterHashtable @{
            LogName = "Microsoft-Windows-WindowsUpdateClient/Operational"
            StartTime = $preBootStart
            EndTime = $postBootEnd
        } -MaxEvents 200 -ErrorAction SilentlyContinue

        foreach ($event in $updateEvents) {
            if ($event.Message -match $updatePattern) {
                $evidence.Add("WindowsUpdateClient event $($event.Id) at $($event.TimeCreated)")
            }
        }
    } catch {
        Write-AutoLog "Windows Update operational log unavailable: $($_.Exception.Message)"
    }

    return $evidence | Select-Object -First 8
}

$wrapperSwitchValues = @{
    AlwaysApply = $AlwaysApply.IsPresent
    BlockOneDrive = $BlockOneDrive.IsPresent
    RemoveOneDrive = $RemoveOneDrive.IsPresent
    DisableEdgeUpdates = $DisableEdgeUpdates.IsPresent
    SkipCopilot = $SkipCopilot.IsPresent
    SkipOneDrive = $SkipOneDrive.IsPresent
    SkipEdge = $SkipEdge.IsPresent
    SkipOutlook = $SkipOutlook.IsPresent
    SkipConsumerContent = $SkipConsumerContent.IsPresent
}

$cleanupSwitchValues = @{
    BlockOneDrive = $BlockOneDrive.IsPresent
    RemoveOneDrive = $RemoveOneDrive.IsPresent
    DisableEdgeUpdates = $DisableEdgeUpdates.IsPresent
    SkipCopilot = $SkipCopilot.IsPresent
    SkipOneDrive = $SkipOneDrive.IsPresent
    SkipEdge = $SkipEdge.IsPresent
    SkipOutlook = $SkipOutlook.IsPresent
    SkipConsumerContent = $SkipConsumerContent.IsPresent
}

$optionSummary = Get-MicrosludgeOptionSummary -Values $wrapperSwitchValues -Names (Get-MicrosludgeWrapperSwitchNames)

Write-AutoLog "Starting automated Microsludge Degoblin check."
Write-AutoLog "Mode: $(if ($TestOnly) { 'TEST ONLY' } elseif ($AlwaysApply) { 'APPLY AT EVERY SCHEDULED LAUNCH' } else { 'APPLY IF WINDOWS UPDATE REBOOT IS DETECTED' })"
Write-AutoLog "Options: $optionSummary"
Write-AutoLog "Wrapper log: $logPath"

Remove-MicrosludgeOldLogs `
    -LogRoot $logRoot `
    -KeepMostRecent 20 `
    -OlderThanDays 90 `
    -ExcludePath $logPath `
    -Logger { param($Message) Write-AutoLog $Message }

if (-not (Test-Path -LiteralPath $targetScript)) {
    Write-AutoLog "ERROR: Target script not found: $targetScript"
    exit 1
}

$lastBootTime = Get-LastBootTime
Write-AutoLog "Last boot time: $lastBootTime"

if ($AlwaysApply) {
    Write-AutoLog "AlwaysApply requested. Skipping Windows Update reboot evidence gate."
} else {
    $evidence = @(Get-WindowsUpdateRebootEvidence -LastBootTime $lastBootTime)
    if ($evidence.Count -eq 0) {
        Write-AutoLog "No Windows Update reboot evidence found. Skipping cleanup script."
        exit 0
    }

    Write-AutoLog "Windows Update reboot evidence found:"
    foreach ($item in $evidence) {
        Write-AutoLog "  $item"
    }
}

if ($TestOnly) {
    Write-AutoLog "TestOnly requested. Skipping Microsludge-Degoblin.ps1 -Apply."
    exit 0
}

$arguments = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $targetScript,
    "-Apply"
)

$arguments += Get-MicrosludgeSwitchArgumentList -Values $cleanupSwitchValues -Names (Get-MicrosludgeCleanupSwitchNames)

Write-AutoLog "Running Microsludge-Degoblin.ps1 -Apply with options: $optionSummary"
& powershell.exe @arguments *>&1 |
    ForEach-Object {
        $line = "$_"
        Write-Output $line
        Add-Content -Path $logPath -Value $line
    }

$exitCode = $LASTEXITCODE
if ($null -eq $exitCode) {
    $exitCode = 0
}

Write-AutoLog "Microsludge-Degoblin exit code: $exitCode"
exit $exitCode

