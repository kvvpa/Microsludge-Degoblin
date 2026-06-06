<#
Reports whether known Windows AI policy targets and related packages/features
appear to exist on the current machine.

This script is detection-only. It does not change registry values, packages,
features, services, tasks, or processes.
#>

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$helpers = Join-Path $scriptRoot "Microsludge-Degoblin.Helpers.ps1"

if (-not (Test-Path -LiteralPath $helpers)) {
    throw "Helper script not found: $helpers"
}

. $helpers

if (-not (Test-MicrosludgeIsAdmin)) {
    throw "This detection script must be run as Administrator."
}

$detection = Get-MicrosludgeWindowsAIDetection
Write-MicrosludgeWindowsAIReport -Detection $detection
