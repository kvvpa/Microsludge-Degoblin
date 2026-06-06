<#
Unregisters the scheduled task for Microsludge Degoblin.

Run this from an elevated PowerShell prompt when the automatic post-update task
should stop running. It also removes the installed package copy from ProgramData.
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

$installRoot = Get-MicrosludgeInstallRoot

$task = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
if ($task) {
    Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
    Write-Host "Removed scheduled task: $taskPath$taskName"
} else {
    Write-Host "Scheduled task not found: $taskPath$taskName"
}

if (-not (Test-Path -LiteralPath $installRoot)) {
    Write-Host "Installed package copy not found: $installRoot"
    return
}

$expectedInstallRoot = Get-MicrosludgeInstallRoot
$actualFullPath = [System.IO.Path]::GetFullPath($installRoot).TrimEnd("\")
$expectedFullPath = [System.IO.Path]::GetFullPath($expectedInstallRoot).TrimEnd("\")
if ($actualFullPath -ne $expectedFullPath) {
    throw "Refusing to remove unexpected path: $installRoot"
}

$currentPackageRoot = Split-Path -Parent $scriptRoot
$currentPackageFullPath = [System.IO.Path]::GetFullPath($currentPackageRoot).TrimEnd("\")
if ($currentPackageFullPath -eq $actualFullPath) {
    if (-not $env:TEMP -or -not (Test-Path -LiteralPath $env:TEMP)) {
        Write-Host "WARNING: Could not queue installed package removal because TEMP is unavailable."
        return
    }

    $cleanupScript = Join-Path $env:TEMP ("Remove-Microsludge-Degoblin-{0}.ps1" -f ([guid]::NewGuid().ToString("N")))
    $escapedInstallRoot = $installRoot.Replace("'", "''")
$cleanupContent = @"
Start-Sleep -Seconds 2
Remove-Item -LiteralPath '$escapedInstallRoot' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath `$($MyInvocation.MyCommand.Path) -Force -ErrorAction SilentlyContinue
"@

    Set-Content -LiteralPath $cleanupScript -Value $cleanupContent -Encoding ASCII
    Set-Location -LiteralPath $env:TEMP
    Start-Process -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", ('"{0}"' -f $cleanupScript)) `
        -WindowStyle Hidden
    Write-Host "Queued installed package removal: $installRoot"
    return
}

try {
    if ($env:TEMP -and (Test-Path -LiteralPath $env:TEMP)) {
        Set-Location -LiteralPath $env:TEMP
    }

    Remove-Item -LiteralPath $installRoot -Recurse -Force -ErrorAction Stop
    Write-Host "Removed installed package copy: $installRoot"
} catch {
    Write-Host "WARNING: Could not remove installed package copy: $installRoot"
    Write-Host "WARNING: $($_.Exception.Message)"
}
