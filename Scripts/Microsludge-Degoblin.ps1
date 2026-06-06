<#
Microsludge-Degoblin.ps1

Purpose:
  Re-check and correct common Microsoft app, startup, and policy resurrections after
  Windows Updates or feature upgrades.

Default targets:
  - Copilot packages and off policies
  - OneDrive process and startup entries
  - Microsoft.OutlookForWindows
  - Microsoft.Edge.GameAssist
  - Edge background/startup/sidebar policies
  - Microsoft consumer content, suggestions, ads, tailored experiences, activity upload
  - Widgets/news taskbar setting
  - SoftLanding scheduled tasks

Default non-targets:
  - Does not move user folders or change shell-folder mappings
  - Does not disable third-party startup items
  - Does not remove Edge browser itself
  - Does not remove or block WebView2
  - Does not uninstall OneDrive unless -RemoveOneDrive is passed
  - Does not disable Edge update services/tasks unless -DisableEdgeUpdates is passed
  - Does not disable Windows AI policies unless -DisableWindowsAI is passed

Usage:
  powershell -ExecutionPolicy Bypass -File .\Scripts\Microsludge-Degoblin.ps1
  powershell -ExecutionPolicy Bypass -File .\Scripts\Microsludge-Degoblin.ps1 -Apply
  powershell -ExecutionPolicy Bypass -File .\Scripts\Microsludge-Degoblin.ps1 -Apply -BlockOneDrive -DisableEdgeUpdates
#>

param(
    [switch]$Apply,
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

$ErrorActionPreference = "Continue"

$scriptRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptRoot
$helpers = Join-Path $scriptRoot "Microsludge-Degoblin.Helpers.ps1"
if (-not (Test-Path -LiteralPath $helpers)) {
    throw "Helper script not found: $helpers"
}

. $helpers

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logRoot = Join-Path $repoRoot "Logs"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$logPath = Join-Path $logRoot "Microsludge-Degoblin-$timestamp.log"
$packageVersion = Get-MicrosludgeVersion -Root $repoRoot

function Write-Log {
    param([string]$Message)

    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -Path $logPath -Value $line
}

function Invoke-Fix {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

    if ($Apply) {
        Write-Log "FIX: $Description"
        try {
            & $Action
        } catch {
            Write-Log "ERROR during '$Description': $($_.Exception.Message)"
        }
    } else {
        Write-Log "WOULD FIX: $Description"
    }
}

function Set-RegDword {
    param(
        [string]$Path,
        [string]$Name,
        [int]$Value
    )

    $target = "$Path\$Name"
    try {
        $output = @(reg.exe add $Path /v $Name /t REG_DWORD /d $Value /f 2>&1)
        $exitCode = $LASTEXITCODE
        $outputText = (@($output) | ForEach-Object { "$_" }) -join " "

        if ($exitCode -ne 0) {
            if ([string]::IsNullOrWhiteSpace($outputText)) {
                $outputText = "reg.exe exited with code $exitCode."
            } else {
                $outputText = "reg.exe exited with code ${exitCode}: $outputText"
            }

            Write-Log "ERROR: Registry write failed: $target = $Value. $outputText"
            return
        }

        Write-Log "OK: Registry write: $target = $Value"
    } catch {
        Write-Log "ERROR: Registry write failed: $target = $Value. $($_.Exception.Message)"
    }
}

function Write-RegDwordCheck {
    param(
        [string]$Path,
        [string]$Name,
        [int]$Expected
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Log "WARNING: Registry path missing: $Path"
        return
    }

    try {
        $property = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
        $actual = [int]$property.$Name
        if ($actual -eq $Expected) {
            Write-Log "OK: Registry $Path\$Name = $Expected"
        } else {
            Write-Log "WARNING: Registry $Path\$Name expected $Expected, found $actual"
        }
    } catch {
        Write-Log "WARNING: Registry value missing or unreadable: $Path\$Name"
    }
}

function Remove-AppxPackagesByPattern {
    param(
        [string]$Pattern,
        [string]$Description
    )

    $packages = @(Get-AppxPackage -AllUsers $Pattern -ErrorAction SilentlyContinue)
    if ($packages.Count -gt 0) {
        Invoke-Fix $Description {
            Get-AppxPackage -AllUsers $Pattern -ErrorAction SilentlyContinue |
                Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        }
    } else {
        Write-Log "OK: No installed Appx packages found for pattern '$Pattern'."
    }
}

function Remove-ProvisionedPackagesByDisplayName {
    param(
        [string]$Pattern,
        [string]$Description
    )

    $packages = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like $Pattern })

    if ($packages.Count -gt 0) {
        Invoke-Fix $Description {
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like $Pattern } |
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        }
    } else {
        Write-Log "OK: No provisioned packages found for pattern '$Pattern'."
    }
}

function Remove-StartupEntriesByPattern {
    param(
        [string[]]$Patterns,
        [string]$Description
    )

    $runKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce",
        "Registry::HKEY_USERS\S-1-5-19\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "Registry::HKEY_USERS\S-1-5-20\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    )

    Write-Log "Checking startup entries: $Description"

    foreach ($key in $runKeys) {
        if (-not (Test-Path -LiteralPath $key)) {
            continue
        }

        $props = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Name -match "^PS") {
                continue
            }

            $value = "$($prop.Value)"
            $matched = $false
            foreach ($pattern in $Patterns) {
                if ($prop.Name -match $pattern -or $value -match $pattern) {
                    $matched = $true
                    break
                }
            }

            if ($matched) {
                Invoke-Fix "Remove startup entry '$($prop.Name)' from $key" {
                    Remove-ItemProperty -LiteralPath $key -Name $prop.Name -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

function Disable-ScheduledTasksByPattern {
    param(
        [string[]]$Patterns,
        [string]$Description
    )

    $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $fullName = "$($_.TaskPath)$($_.TaskName)"
        $matched = $false
        foreach ($pattern in $Patterns) {
            if ($fullName -match $pattern) {
                $matched = $true
                break
            }
        }
        $matched
    })

    if ($tasks.Count -eq 0) {
        Write-Log "OK: No scheduled tasks found for $Description."
        return
    }

    foreach ($task in $tasks) {
        if ($task.State -ne "Disabled") {
            Invoke-Fix "Disable scheduled task $($task.TaskPath)$($task.TaskName)" {
                Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue | Out-Null
            }
        } else {
            Write-Log "OK: Scheduled task already disabled: $($task.TaskPath)$($task.TaskName)"
        }
    }
}

function Disable-ServiceIfPresent {
    param([string]$Name)

    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Log "OK: Service not found: $Name"
        return
    }

    if ($svc.Status -ne "Stopped") {
        Invoke-Fix "Stop service $Name" {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Log "OK: Service already stopped: $Name"
    }

    if ($svc.StartType -ne "Disabled") {
        Invoke-Fix "Disable service $Name" {
            Set-Service -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue
        }
    } else {
        Write-Log "OK: Service already disabled: $Name"
    }
}

Write-Log "Starting Microsludge-Degoblin.ps1"
Write-Log "Version: $packageVersion"
Write-Log "Mode: $(if ($Apply) { 'APPLY' } else { 'DRY RUN' })"
Write-Log "Log: $logPath"
$selectedSwitches = @{
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
Write-Log "Options: $(Get-MicrosludgeOptionSummary -Values $selectedSwitches -Names (Get-MicrosludgeCleanupSwitchNames))"

if (-not (Test-MicrosludgeIsAdmin)) {
    Write-Log "ERROR: This script must be run as Administrator."
    Write-Log "Open PowerShell as Administrator and rerun."
    exit 1
}

if (-not $SkipOneDrive) {
    Write-Log ""
    Write-Log "ONEDRIVE"

    $oneDriveProcess = Get-Process -Name OneDrive -ErrorAction SilentlyContinue
    if ($oneDriveProcess) {
        Invoke-Fix "Stop OneDrive process" {
            taskkill.exe /F /IM OneDrive.exe 2>$null | Out-Null
        }
    } else {
        Write-Log "OK: OneDrive process is not running."
    }

    Remove-StartupEntriesByPattern -Description "OneDrive" -Patterns @(
        "OneDrive",
        "OneDriveSetup"
    )

    Disable-ScheduledTasksByPattern -Description "OneDrive" -Patterns @(
        "OneDrive"
    )

    if ($BlockOneDrive) {
        Invoke-Fix "Apply OneDrive file sync block policy" {
            Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1
        }
    } else {
        Write-Log "INFO: OneDrive sync block policy skipped. Use -BlockOneDrive to enable it."
    }

    if ($RemoveOneDrive) {
        $oneDriveSetupCandidates = @(
            (Join-Path $env:SystemRoot "SysWOW64\OneDriveSetup.exe"),
            (Join-Path $env:SystemRoot "System32\OneDriveSetup.exe"),
            (Join-Path $env:LOCALAPPDATA "Microsoft\OneDrive\OneDriveSetup.exe")
        ) | Select-Object -Unique

        $existingOneDriveSetups = @($oneDriveSetupCandidates | Where-Object { Test-Path -LiteralPath $_ })
        if ($existingOneDriveSetups.Count -gt 0) {
            Invoke-Fix "Run OneDrive uninstallers" {
                foreach ($setup in $existingOneDriveSetups) {
                    Start-Process -FilePath $setup -ArgumentList "/uninstall" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                }
            }
        } else {
            Write-Log "OK: No OneDriveSetup.exe uninstall candidate found."
        }
    } else {
        Write-Log "INFO: OneDrive uninstall skipped. Use -RemoveOneDrive to run OneDriveSetup.exe /uninstall."
    }
} else {
    Write-Log "SKIP: OneDrive cleanup disabled by parameter."
}

if (-not $SkipCopilot) {
    Write-Log ""
    Write-Log "COPILOT"

    Remove-AppxPackagesByPattern -Pattern "*copilot*" -Description "Remove installed Copilot Appx packages"
    Remove-ProvisionedPackagesByDisplayName -Pattern "*Copilot*" -Description "Remove provisioned Copilot packages"

    Invoke-Fix "Set Copilot-off policies" {
        Set-RegDword -Path "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
    }

    Remove-StartupEntriesByPattern -Description "Copilot" -Patterns @(
        "Copilot"
    )
} else {
    Write-Log "SKIP: Copilot cleanup disabled by parameter."
}

if (-not $SkipOutlook) {
    Write-Log ""
    Write-Log "OUTLOOK FOR WINDOWS"

    Remove-AppxPackagesByPattern -Pattern "Microsoft.OutlookForWindows" -Description "Remove Microsoft.OutlookForWindows app"
    Remove-ProvisionedPackagesByDisplayName -Pattern "Microsoft.OutlookForWindows" -Description "Remove provisioned Microsoft.OutlookForWindows package"
} else {
    Write-Log "SKIP: Outlook cleanup disabled by parameter."
}

if (-not $SkipEdge) {
    Write-Log ""
    Write-Log "EDGE"

    Remove-AppxPackagesByPattern -Pattern "Microsoft.Edge.GameAssist" -Description "Remove Microsoft.Edge.GameAssist app"
    Remove-ProvisionedPackagesByDisplayName -Pattern "*Edge.GameAssist*" -Description "Remove provisioned Edge GameAssist packages"
    Remove-ProvisionedPackagesByDisplayName -Pattern "*GameAssist*" -Description "Remove provisioned GameAssist packages"

    Invoke-Fix "Apply Edge browser anti-background policies" {
        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Edge" -Name "StartupBoostEnabled" -Value 0
        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Edge" -Name "BackgroundModeEnabled" -Value 0
        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Edge" -Name "HideFirstRunExperience" -Value 1
        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Edge" -Name "HubsSidebarEnabled" -Value 0
    }

    Remove-StartupEntriesByPattern -Description "Edge background startup entries" -Patterns @(
        "MicrosoftEdgeAutoLaunch",
        "msedge\.exe.*--no-startup-window",
        "msedge\.exe.*--win-session-start"
    )

    if ($DisableEdgeUpdates) {
        Disable-ScheduledTasksByPattern -Description "Microsoft Edge update" -Patterns @(
            "MicrosoftEdgeUpdate"
        )

        foreach ($svcName in @("edgeupdate", "edgeupdatem")) {
            Disable-ServiceIfPresent -Name $svcName
        }
    } else {
        Write-Log "INFO: Edge update services/tasks left alone. Use -DisableEdgeUpdates to disable them."
    }
} else {
    Write-Log "SKIP: Edge cleanup disabled by parameter."
}

if (-not $SkipConsumerContent) {
    Write-Log ""
    Write-Log "MICROSOFT CONSUMER CONTENT"

    Invoke-Fix "Apply anti-consumer-content and telemetry reduction policies" {
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0

        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "ContentDeliveryAllowed" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "FeatureManagementEnabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "OemPreInstalledAppsEnabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEnabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEverEnabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SoftLandingEnabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338387Enabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353694Enabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353696Enabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -Value 0
        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0

        Set-RegDword -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0

        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1
        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableTailoredExperiencesWithDiagnosticData" -Value 1
        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 1

        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0
        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0
        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0

        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0
    }

    Disable-ScheduledTasksByPattern -Description "SoftLanding/creative/deferral" -Patterns @(
        "SoftLanding",
        "Creative",
        "Deferral"
    )
} else {
    Write-Log "SKIP: Microsoft consumer content cleanup disabled by parameter."
}

if ($DisableWindowsAI) {
    Write-Log ""
    Write-Log "WINDOWS AI"

    $windowsAIDetection = Get-MicrosludgeWindowsAIDetection
    Write-MicrosludgeWindowsAIReport -Detection $windowsAIDetection -Writer { param($Message) Write-Log $Message }

    Invoke-Fix "Apply Windows AI disable policies" {
        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "AllowRecallEnablement" -Value 0
        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1
        Set-RegDword -Path "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1
        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableClickToDo" -Value 1
        Set-RegDword -Path "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableClickToDo" -Value 1
        Set-RegDword -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableSettingsAgent" -Value 1

        Set-RegDword -Path "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Paint" -Name "DisableCocreator" -Value 1
        Set-RegDword -Path "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Paint" -Name "DisableGenerativeFill" -Value 1
        Set-RegDword -Path "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Paint" -Name "DisableImageCreator" -Value 1
    }
} else {
    Write-Log "INFO: Windows AI cleanup skipped. Use -DisableWindowsAI to enable it."
}

Write-Log ""
Write-Log "FINAL CHECKS"

$startup = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -match "OneDrive|Copilot|Edge|Outlook" -or
        $_.Command -match "OneDrive|Copilot|msedge|MicrosoftEdge|OutlookForWindows|GameAssist"
    } |
    Select-Object Name, Command, Location, User |
    Sort-Object Name

if ($startup) {
    Write-Log "Microsoft-related startup entries still present:"
    foreach ($entry in $startup) {
        Write-Log "  $($entry.Name) | $($entry.Command)"
    }
} else {
    Write-Log "OK: No Microsoft-related startup entries found by Win32_StartupCommand."
}

$oneDrive = Get-Process -Name OneDrive -ErrorAction SilentlyContinue
if ($oneDrive) {
    Write-Log "WARNING: OneDrive process still running."
} else {
    Write-Log "OK: OneDrive process absent."
}

$copilotLeft = Get-AppxPackage -AllUsers "*copilot*" -ErrorAction SilentlyContinue
if ($copilotLeft) {
    Write-Log "WARNING: Copilot packages still found."
} else {
    Write-Log "OK: Copilot packages absent."
}

$outlookLeft = Get-AppxPackage -AllUsers "Microsoft.OutlookForWindows" -ErrorAction SilentlyContinue
if ($outlookLeft) {
    Write-Log "WARNING: Microsoft.OutlookForWindows still found."
} else {
    Write-Log "OK: Microsoft.OutlookForWindows absent."
}

$gameAssistLeft = Get-AppxPackage -AllUsers "Microsoft.Edge.GameAssist" -ErrorAction SilentlyContinue
if ($gameAssistLeft) {
    Write-Log "WARNING: Microsoft.Edge.GameAssist still found."
} else {
    Write-Log "OK: Microsoft.Edge.GameAssist absent."
}

$edgeProcesses = Get-Process -Name msedge, MicrosoftEdgeUpdate -ErrorAction SilentlyContinue |
    Select-Object ProcessName, Id, Path

if ($edgeProcesses) {
    Write-Log "Edge-related processes:"
    foreach ($proc in $edgeProcesses) {
        Write-Log "  $($proc.ProcessName) | $($proc.Path)"
    }
} else {
    Write-Log "OK: No Edge browser/update processes found."
}

if ($Apply) {
    Write-Log ""
    Write-Log "REGISTRY POLICY CHECKS"

    if (-not $SkipCopilot) {
        Write-RegDwordCheck -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Expected 1
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Expected 1
    }

    if (-not $SkipOneDrive -and $BlockOneDrive) {
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Expected 1
    }

    if (-not $SkipEdge) {
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "StartupBoostEnabled" -Expected 0
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "BackgroundModeEnabled" -Expected 0
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "HideFirstRunExperience" -Expected 1
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "HubsSidebarEnabled" -Expected 0
    }

    if (-not $SkipConsumerContent) {
        Write-RegDwordCheck -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Expected 0
        Write-RegDwordCheck -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Expected 0
        Write-RegDwordCheck -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SoftLandingEnabled" -Expected 0
        Write-RegDwordCheck -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Expected 0
        Write-RegDwordCheck -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Expected 0
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Expected 1
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableTailoredExperiencesWithDiagnosticData" -Expected 1
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Expected 1
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Expected 0
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Expected 0
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Expected 0
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Expected 0
    }

    if ($DisableWindowsAI) {
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "AllowRecallEnablement" -Expected 0
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Expected 1
        Write-RegDwordCheck -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Expected 1
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableClickToDo" -Expected 1
        Write-RegDwordCheck -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableClickToDo" -Expected 1
        Write-RegDwordCheck -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableSettingsAgent" -Expected 1
        Write-RegDwordCheck -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Paint" -Name "DisableCocreator" -Expected 1
        Write-RegDwordCheck -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Paint" -Name "DisableGenerativeFill" -Expected 1
        Write-RegDwordCheck -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Paint" -Name "DisableImageCreator" -Expected 1
    }
} else {
    Write-Log "INFO: Registry policy checks skipped in dry run."
}

Write-Log ""
if (-not $Apply) {
    Write-Log "Dry run complete. Re-run with -Apply to make changes."
} else {
    Remove-MicrosludgeOldLogs `
        -LogRoot $logRoot `
        -KeepMostRecent 20 `
        -OlderThanDays 90 `
        -ExcludePath $logPath `
        -Logger { param($Message) Write-Log $Message }

    Write-Log "Apply run complete. Reboot recommended."
}

