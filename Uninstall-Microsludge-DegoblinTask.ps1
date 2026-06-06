<#
Unregisters the scheduled task for Microsludge Degoblin.

Run this from an elevated PowerShell prompt when the automatic post-update task
should stop running.
#>

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$helpers = Join-Path $scriptRoot "Microsludge-Degoblin.Helpers.ps1"
$taskName = "Microsludge Degoblin After Windows Update"
$taskPath = "\Microsludge-Degoblin\"

if (-not (Test-Path -LiteralPath $helpers)) {
    throw "Helper script not found: $helpers"
}

. $helpers

if (-not (Test-MicrosludgeIsAdmin)) {
    throw "This uninstaller must be run as Administrator."
}

$task = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Host "Scheduled task not found: $taskPath$taskName"
    return
}

Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
Write-Host "Removed scheduled task: $taskPath$taskName"
