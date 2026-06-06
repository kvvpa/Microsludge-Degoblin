<#
Interactive walkthrough for Microsludge Degoblin.

This launcher does not hide what it runs. It refuses to continue without admin,
shows the selected command, asks for confirmation before apply/removal paths,
and then delegates to the real scripts.
#>

param(
    [switch]$Wizard
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$helpers = Join-Path $scriptRoot "Microsludge-Degoblin.Helpers.ps1"
$mainScript = Join-Path $scriptRoot "Microsludge-Degoblin.ps1"
$installerScript = Join-Path $scriptRoot "Install-Microsludge-DegoblinTask.ps1"
$uninstallerScript = Join-Path $scriptRoot "Uninstall-Microsludge-DegoblinTask.ps1"
$windowsAITestScript = Join-Path $scriptRoot "Test-Microsludge-WindowsAI.ps1"

if (-not (Test-Path -LiteralPath $helpers)) {
    throw "Helper script not found: $helpers"
}

. $helpers

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

function Show-Banner {
    $banner = @(
        '====================================================================',
        '||                                                                ||',
        '||                  MICROSLUDGE DEGOBLIN 9000                     ||',
        '||                                                                ||',
        '||     [ Copilot ]--[ OneDrive ]--[ Edge ]--[ Outlook ]--[ Ads ]  ||',
        '||           \          |          |          |          /         ||',
        '||            \_________|__________|__________|_________/          ||',
        '||                         ______________                         ||',
        '||                        /              \                        ||',
        '||       REGISTRY        /  SLUDGE TANK   \       TASKS           ||',
        '||       PLUNGER  --->  |   DO NOT SIP    |  <--- DISABLER        ||',
        '||                       \________________/                       ||',
        '||                                                                ||',
        '||            "apply mode means it actually bites"                ||',
        '||                                                                ||',
        '====================================================================',
        '',
        ' __  __ ___ ____ ____   ___  ____  _    _   _ ____   ____ _____',
        '|  \/  |_ _/ ___|  _ \ / _ \/ ___|| |  | | | |  _ \ / ___| ____|',
        '| |\/| || | |   | |_) | | | \___ \| |  | | | | | | | |  _|  _|',
        '| |  | || | |___|  _ <| |_| |___) | |__| |_| | |_| | |_| | |___',
        '|_|  |_|___\____|_| \_\\___/|____/|_____\___/|____/ \____|_____|',
        '',
        ' ____  _____ ____  ___  ____  _     ___ _   _',
        '|  _ \| ____/ ___|/ _ \| __ )| |   |_ _| \ | |',
        '| | | |  _|| |  _| | | |  _ \| |    | ||  \| |',
        '| |_| | |__| |_| | |_| | |_) | |___ | || |\  |',
        '|____/|_____\____|\___/|____/|_____|___|_| \_|'
    )

    foreach ($line in $banner) {
        Write-Host $line
    }
}

function Read-WizardChoice {
    param(
        [string]$Prompt,
        [string[]]$Allowed
    )

    while ($true) {
        $answer = Read-Host $Prompt
        if ($null -eq $answer) {
            $answer = ""
        }

        $choice = $answer.Trim().ToUpperInvariant()
        if ($Allowed -contains $choice) {
            return $choice
        }

        Write-Host "Pick one of: $($Allowed -join ', ')."
    }
}

function Read-WizardYesNo {
    param(
        [string]$Question,
        [bool]$DefaultYes,
        [string]$Explanation
    )

    Write-Host ""
    if ($Explanation) {
        Write-Host $Explanation
    }

    $suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    while ($true) {
        $answer = Read-Host "$Question $suffix"
        if ($null -eq $answer) {
            $answer = ""
        }

        $normalized = $answer.Trim().ToLowerInvariant()
        if ($normalized -eq "") {
            return $DefaultYes
        }

        if (@("y", "yes") -contains $normalized) {
            return $true
        }

        if (@("n", "no") -contains $normalized) {
            return $false
        }

        Write-Host "Answer yes or no."
    }
}

function Format-CommandLine {
    param(
        [string]$ScriptPath,
        [string[]]$ExtraArgs
    )

    $parts = @(
        "powershell",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ('"{0}"' -f $ScriptPath)
    ) + $ExtraArgs

    return $parts -join " "
}

function Start-Wizard {
    Clear-Host
    Show-Banner
    Write-Host ""
    Write-Host "Microsludge Degoblin Wizard"
    Write-Host ""
    Write-Host "This will ask what to include, explain the stronger options, show the exact command,"
    Write-Host "and ask for confirmation before doing anything that changes the machine."
    Write-Host ""
    Write-Host "Run modes:"
    Write-Host "  1. Dry run now: logs what would change, changes nothing."
    Write-Host "  2. Apply now: performs the selected cleanup immediately."
    Write-Host "  3. Install post-update task: saves these choices for automatic cleanup after Windows Update reboots."
    Write-Host "  4. Uninstall post-update task: removes the saved automatic cleanup task."
    Write-Host "  5. Test for Windows AI targets: report only, changes nothing."
    Write-Host "  Q. Quit"
    Write-Host ""

    $modeChoice = Read-WizardChoice -Prompt "Choose run mode" -Allowed @("1", "2", "3", "4", "5", "Q")
    if ($modeChoice -eq "Q") {
        Write-Host "Wizard cancelled."
        return
    }

    $modeName = switch ($modeChoice) {
        "1" { "Dry run now" }
        "2" { "Apply now" }
        "3" { "Install post-update task" }
        "4" { "Uninstall post-update task" }
        "5" { "Test for Windows AI targets" }
    }

    if ($modeChoice -eq "4") {
        Write-Host ""
        Write-Host "This removes the saved scheduled task. It does not undo previous cleanup changes."
        Write-Host ""
        Write-Host "Command:"
        Write-Host (Format-CommandLine -ScriptPath $uninstallerScript -ExtraArgs @())

        Invoke-CommandPreview `
            -Label "Uninstalling post-update scheduled task:" `
            -ScriptPath $uninstallerScript `
            -ExtraArgs @() `
            -ConfirmationWord "UNINSTALL"

        return
    }

    if ($modeChoice -eq "5") {
        Write-Host ""
        Write-Host "This checks for known Windows AI policy values, Recall optional feature state,"
        Write-Host "related Appx packages, and related running processes. It does not change anything."
        Write-Host ""
        Write-Host "Command:"
        Write-Host (Format-CommandLine -ScriptPath $windowsAITestScript -ExtraArgs @())

        Invoke-CommandPreview `
            -Label "Running Windows AI detection report:" `
            -ScriptPath $windowsAITestScript `
            -ExtraArgs @() `
            -ConfirmationWord $null

        return
    }

    Write-Host ""
    Write-Host "Step 1: choose cleanup targets."

    $alwaysApply = $false
    if ($modeChoice -eq "3") {
        $alwaysApply = Read-WizardYesNo `
            -Question "Run the scheduled task at every logon instead of only after Windows Update reboots?" `
            -DefaultYes $false `
            -Explanation "Default is safer: run only when the wrapper finds Windows Update reboot evidence. Pick yes if this should be routine logon cleanup."
    }

    $includeCopilot = Read-WizardYesNo `
        -Question "Include Copilot cleanup?" `
        -DefaultYes $true `
        -Explanation "Removes installed/provisioned Copilot packages and sets Windows Copilot off policies."

    $includeOneDrive = Read-WizardYesNo `
        -Question "Include OneDrive startup cleanup?" `
        -DefaultYes $true `
        -Explanation "Stops OneDrive if running, removes OneDrive startup entries, and disables OneDrive scheduled tasks. This does not uninstall OneDrive by itself."

    $blockOneDrive = $false
    $removeOneDrive = $false
    if ($includeOneDrive) {
        $blockOneDrive = Read-WizardYesNo `
            -Question "Block OneDrive file sync by policy?" `
            -DefaultYes $false `
            -Explanation "Stronger option: sets the machine policy that blocks OneDrive file sync. Pick yes only if OneDrive should stay off."

        $removeOneDrive = Read-WizardYesNo `
            -Question "Uninstall OneDrive when the local uninstaller is found?" `
            -DefaultYes $false `
            -Explanation "Strongest OneDrive option: runs OneDriveSetup.exe /uninstall. Startup cleanup is usually enough if you only want it out of the way."
    }

    $includeEdge = Read-WizardYesNo `
        -Question "Include Edge background cleanup?" `
        -DefaultYes $true `
        -Explanation "Removes Edge GameAssist, blocks Edge startup boost/background mode/sidebar behavior by policy, and removes Edge background autolaunch entries. It does not remove Edge itself."

    $disableEdgeUpdates = $false
    if ($includeEdge) {
        $disableEdgeUpdates = Read-WizardYesNo `
            -Question "Disable Edge update services and scheduled tasks?" `
            -DefaultYes $false `
            -Explanation "Stronger option: disables MicrosoftEdgeUpdate tasks plus edgeupdate and edgeupdatem services. This can affect Edge and WebView2 update freshness."
    }

    $includeOutlook = Read-WizardYesNo `
        -Question "Include new Outlook cleanup?" `
        -DefaultYes $true `
        -Explanation "Removes Microsoft.OutlookForWindows installed and provisioned Appx packages."

    $includeConsumerContent = Read-WizardYesNo `
        -Question "Include Microsoft ads, suggestions, widgets, and SoftLanding cleanup?" `
        -DefaultYes $true `
        -Explanation "Turns off consumer-content suggestions, advertising ID, tailored experiences, widgets/news policy, activity upload, and SoftLanding-style tasks."

    $selectedSwitches = @{
        AlwaysApply = $alwaysApply
        BlockOneDrive = $blockOneDrive
        RemoveOneDrive = $removeOneDrive
        DisableEdgeUpdates = $disableEdgeUpdates
        SkipCopilot = -not $includeCopilot
        SkipOneDrive = -not $includeOneDrive
        SkipEdge = -not $includeEdge
        SkipOutlook = -not $includeOutlook
        SkipConsumerContent = -not $includeConsumerContent
    }

    $switchNames = if ($modeChoice -eq "3") {
        Get-MicrosludgeWrapperSwitchNames
    } else {
        Get-MicrosludgeCleanupSwitchNames
    }

    $extraArgs = @()
    if ($modeChoice -eq "2") {
        $extraArgs += "-Apply"
    }
    $extraArgs += Get-MicrosludgeSwitchArgumentList -Values $selectedSwitches -Names $switchNames

    $scriptPath = if ($modeChoice -eq "3") { $installerScript } else { $mainScript }
    $confirmationWord = $null
    if ($modeChoice -eq "2") {
        $confirmationWord = if ($removeOneDrive) { "REMOVE" } else { "APPLY" }
    } elseif ($modeChoice -eq "3") {
        $confirmationWord = "INSTALL"
    }

    Write-Host ""
    Write-Host "Step 2: review your choices."
    Write-Host "  Mode: $modeName"
    if ($modeChoice -eq "3") {
        Write-Host "  Run at every logon: $alwaysApply"
    }
    Write-Host "  Copilot cleanup: $includeCopilot"
    Write-Host "  OneDrive startup cleanup: $includeOneDrive"
    Write-Host "  Block OneDrive sync: $blockOneDrive"
    Write-Host "  Uninstall OneDrive: $removeOneDrive"
    Write-Host "  Edge background cleanup: $includeEdge"
    Write-Host "  Disable Edge updates: $disableEdgeUpdates"
    Write-Host "  New Outlook cleanup: $includeOutlook"
    Write-Host "  Ads/suggestions/widgets cleanup: $includeConsumerContent"
    Write-Host ""
    Write-Host "Command:"
    Write-Host (Format-CommandLine -ScriptPath $scriptPath -ExtraArgs $extraArgs)

    if ($modeChoice -eq "1") {
        $runDryRun = Read-WizardYesNo `
            -Question "Run this dry run now?" `
            -DefaultYes $true `
            -Explanation "Dry run mode only reports what would change."

        if (-not $runDryRun) {
            Write-Host "Dry run skipped."
            return
        }
    }

    $label = switch ($modeChoice) {
        "1" { "Running wizard-selected dry run:" }
        "2" { "Running wizard-selected apply:" }
        "3" { "Installing wizard-selected post-update task:" }
    }

    Invoke-CommandPreview `
        -Label $label `
        -ScriptPath $scriptPath `
        -ExtraArgs $extraArgs `
        -ConfirmationWord $confirmationWord
}

function Show-Menu {
    Clear-Host
    Show-Banner
    Write-Host ""
    Write-Host "Microsludge Degoblin Walkthrough"
    Write-Host ""
    Write-Host "Default apply does real cleanup for Copilot, OneDrive startup, new Outlook,"
    Write-Host "Edge background behavior, GameAssist, Microsoft consumer content, widgets,"
    Write-Host "and SoftLanding tasks."
    Write-Host ""
    Write-Host "Dry run logs what would change. Apply performs the changes."
    Write-Host ""
    Write-Host "1. Guided step-by-step wizard"
    Write-Host "2. Dry run default cleanup"
    Write-Host "3. Apply default cleanup"
    Write-Host "4. Apply plus block OneDrive file sync"
    Write-Host "5. Apply plus block OneDrive and disable Edge updates"
    Write-Host "6. Apply plus uninstall OneDrive"
    Write-Host "7. Install post-update scheduled task"
    Write-Host "8. Install every-logon scheduled task"
    Write-Host "9. Install post-update task with OneDrive block and Edge update disable"
    Write-Host "10. Uninstall scheduled task"
    Write-Host "11. Test for Windows AI targets"
    Write-Host "12. Open walkthrough text"
    Write-Host "Q. Quit"
    Write-Host ""
}

if (-not (Test-MicrosludgeIsAdmin)) {
    Write-Host "ERROR: Microsludge Degoblin must be run from an Administrator PowerShell window."
    Write-Host "Right-click PowerShell, choose Run as administrator, then rerun this command."
    Write-Host "No cleanup, dry run, or scheduled-task install was started."
    Write-Host ""
    exit 1
}

if ($Wizard) {
    Start-Wizard
    return
}

do {
    Show-Menu
    $choice = Read-Host "Choose"

    switch ($choice.ToUpperInvariant()) {
        "1" {
            Start-Wizard
        }
        "2" {
            Invoke-CommandPreview `
                -Label "Dry run default cleanup:" `
                -ScriptPath $mainScript `
                -ExtraArgs @() `
                -ConfirmationWord $null
        }
        "3" {
            Invoke-CommandPreview `
                -Label "Apply default cleanup:" `
                -ScriptPath $mainScript `
                -ExtraArgs @("-Apply") `
                -ConfirmationWord "APPLY"
        }
        "4" {
            Invoke-CommandPreview `
                -Label "Apply cleanup and block OneDrive file sync:" `
                -ScriptPath $mainScript `
                -ExtraArgs @("-Apply", "-BlockOneDrive") `
                -ConfirmationWord "APPLY"
        }
        "5" {
            Invoke-CommandPreview `
                -Label "Apply cleanup, block OneDrive, and disable Edge updates:" `
                -ScriptPath $mainScript `
                -ExtraArgs @("-Apply", "-BlockOneDrive", "-DisableEdgeUpdates") `
                -ConfirmationWord "APPLY"
        }
        "6" {
            Invoke-CommandPreview `
                -Label "Apply cleanup and uninstall OneDrive:" `
                -ScriptPath $mainScript `
                -ExtraArgs @("-Apply", "-RemoveOneDrive") `
                -ConfirmationWord "REMOVE"
        }
        "7" {
            Invoke-CommandPreview `
                -Label "Install post-update scheduled task:" `
                -ScriptPath $installerScript `
                -ExtraArgs @() `
                -ConfirmationWord "INSTALL"
        }
        "8" {
            Invoke-CommandPreview `
                -Label "Install every-logon scheduled task:" `
                -ScriptPath $installerScript `
                -ExtraArgs @("-AlwaysApply") `
                -ConfirmationWord "INSTALL"
        }
        "9" {
            Invoke-CommandPreview `
                -Label "Install post-update task with OneDrive block and Edge update disable:" `
                -ScriptPath $installerScript `
                -ExtraArgs @("-BlockOneDrive", "-DisableEdgeUpdates") `
                -ConfirmationWord "INSTALL"
        }
        "10" {
            Invoke-CommandPreview `
                -Label "Uninstall scheduled task:" `
                -ScriptPath $uninstallerScript `
                -ExtraArgs @() `
                -ConfirmationWord "UNINSTALL"
        }
        "11" {
            Invoke-CommandPreview `
                -Label "Running Windows AI detection report:" `
                -ScriptPath $windowsAITestScript `
                -ExtraArgs @() `
                -ConfirmationWord $null
        }
        "12" {
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

