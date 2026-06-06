<#
Interactive walkthrough for Microsludge Degoblin.

This launcher does not hide what it runs. It shows the selected command, asks for
confirmation before apply/removal paths, and then delegates to the real scripts.
#>

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = Join-Path $scriptRoot "Microsludge-Degoblin.ps1"
$installerScript = Join-Path $scriptRoot "Install-Microsludge-DegoblinTask.ps1"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-CommandPreview {
    param(
        [string]$Label,
        [string]$ScriptPath,
        [string[]]$ExtraArgs,
        [string]$ConfirmationWord
    )

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        Write-Host ""
        Write-Host "Missing script: $ScriptPath"
        return
    }

    $displayArgs = @(
        "powershell",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ('"{0}"' -f $ScriptPath)
    ) + $ExtraArgs

    Write-Host ""
    Write-Host $Label
    Write-Host ($displayArgs -join " ")

    if ($ConfirmationWord) {
        Write-Host ""
        $answer = Read-Host "Type $ConfirmationWord to continue"
        if ($answer -ne $ConfirmationWord) {
            Write-Host "Skipped."
            return
        }
    }

    $runArgs = @(
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $ScriptPath
    ) + $ExtraArgs

    & powershell.exe @runArgs
}

function Show-Menu {
    Clear-Host
    Write-Host "Microsludge Degoblin Walkthrough"
    Write-Host ""
    Write-Host "Default apply does real cleanup for Copilot, OneDrive startup, new Outlook,"
    Write-Host "Edge background behavior, GameAssist, Microsoft consumer content, widgets,"
    Write-Host "and SoftLanding tasks."
    Write-Host ""
    Write-Host "Dry run logs what would change. Apply performs the changes."
    Write-Host ""
    Write-Host "1. Dry run default cleanup"
    Write-Host "2. Apply default cleanup"
    Write-Host "3. Apply plus block OneDrive file sync"
    Write-Host "4. Apply plus block OneDrive and disable Edge updates"
    Write-Host "5. Apply plus uninstall OneDrive"
    Write-Host "6. Install post-update scheduled task"
    Write-Host "7. Install post-update task with OneDrive block and Edge update disable"
    Write-Host "8. Open walkthrough text"
    Write-Host "Q. Quit"
    Write-Host ""
}

if (-not (Test-IsAdmin)) {
    Write-Host "This walkthrough should be run from an Administrator PowerShell window."
    Write-Host "Dry run may work without admin, but apply/install paths need elevation."
    Write-Host ""
}

do {
    Show-Menu
    $choice = Read-Host "Choose"

    switch ($choice.ToUpperInvariant()) {
        "1" {
            Invoke-CommandPreview `
                -Label "Dry run default cleanup:" `
                -ScriptPath $mainScript `
                -ExtraArgs @() `
                -ConfirmationWord $null
        }
        "2" {
            Invoke-CommandPreview `
                -Label "Apply default cleanup:" `
                -ScriptPath $mainScript `
                -ExtraArgs @("-Apply") `
                -ConfirmationWord "APPLY"
        }
        "3" {
            Invoke-CommandPreview `
                -Label "Apply cleanup and block OneDrive file sync:" `
                -ScriptPath $mainScript `
                -ExtraArgs @("-Apply", "-BlockOneDrive") `
                -ConfirmationWord "APPLY"
        }
        "4" {
            Invoke-CommandPreview `
                -Label "Apply cleanup, block OneDrive, and disable Edge updates:" `
                -ScriptPath $mainScript `
                -ExtraArgs @("-Apply", "-BlockOneDrive", "-DisableEdgeUpdates") `
                -ConfirmationWord "APPLY"
        }
        "5" {
            Invoke-CommandPreview `
                -Label "Apply cleanup and uninstall OneDrive:" `
                -ScriptPath $mainScript `
                -ExtraArgs @("-Apply", "-RemoveOneDrive") `
                -ConfirmationWord "REMOVE"
        }
        "6" {
            Invoke-CommandPreview `
                -Label "Install post-update scheduled task:" `
                -ScriptPath $installerScript `
                -ExtraArgs @() `
                -ConfirmationWord "INSTALL"
        }
        "7" {
            Invoke-CommandPreview `
                -Label "Install post-update task with OneDrive block and Edge update disable:" `
                -ScriptPath $installerScript `
                -ExtraArgs @("-BlockOneDrive", "-DisableEdgeUpdates") `
                -ConfirmationWord "INSTALL"
        }
        "8" {
            $walkthrough = Join-Path $scriptRoot "WALKTHROUGH.txt"
            if (Test-Path -LiteralPath $walkthrough) {
                Get-Content -LiteralPath $walkthrough | more
            } else {
                Write-Host "Missing walkthrough: $walkthrough"
            }
        }
        "Q" {
            return
        }
        default {
            Write-Host "Unknown choice."
        }
    }

    Write-Host ""
    Read-Host "Press Enter to return to the menu"
} while ($true)

