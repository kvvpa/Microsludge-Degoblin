function Test-MicrosludgeIsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-MicrosludgeCleanupSwitchNames {
    return @(
        "BlockOneDrive",
        "RemoveOneDrive",
        "DisableEdgeUpdates",
        "SkipCopilot",
        "SkipOneDrive",
        "SkipEdge",
        "SkipOutlook",
        "SkipConsumerContent"
    )
}

function Get-MicrosludgeWrapperSwitchNames {
    return @("AlwaysApply") + (Get-MicrosludgeCleanupSwitchNames)
}

function Get-MicrosludgeSwitchArgumentList {
    param(
        [hashtable]$Values,
        [string[]]$Names
    )

    $arguments = @()
    foreach ($name in $Names) {
        if ($Values.ContainsKey($name) -and [bool]$Values[$name]) {
            $arguments += "-$name"
        }
    }

    return $arguments
}

function Get-MicrosludgeOptionSummary {
    param(
        [hashtable]$Values,
        [string[]]$Names
    )

    $enabled = @()
    foreach ($name in $Names) {
        if ($Values.ContainsKey($name) -and [bool]$Values[$name]) {
            $enabled += $name
        }
    }

    if ($enabled.Count -eq 0) {
        return "default"
    }

    return $enabled -join ", "
}

function Remove-MicrosludgeOldLogs {
    param(
        [string]$LogRoot,
        [int]$KeepMostRecent = 20,
        [int]$OlderThanDays = 90,
        [string]$ExcludePath,
        [scriptblock]$Logger
    )

    if (-not (Test-Path -LiteralPath $LogRoot)) {
        return
    }

    $excludedFullName = $null
    if ($ExcludePath) {
        try {
            $excludedFullName = (Resolve-Path -LiteralPath $ExcludePath -ErrorAction SilentlyContinue).Path
        } catch {
            $excludedFullName = $null
        }
    }

    $logs = @(Get-ChildItem -LiteralPath $LogRoot -Filter "*.log" -File -ErrorAction SilentlyContinue |
        Where-Object { -not $excludedFullName -or $_.FullName -ne $excludedFullName } |
        Sort-Object LastWriteTime -Descending)

    if ($logs.Count -eq 0) {
        return
    }

    $cutoff = (Get-Date).AddDays(-1 * $OlderThanDays)
    $toRemove = New-Object System.Collections.Generic.List[object]

    foreach ($log in $logs) {
        if ($log.LastWriteTime -lt $cutoff) {
            $toRemove.Add($log)
        }
    }

    $overflow = @($logs | Select-Object -Skip $KeepMostRecent)
    foreach ($log in $overflow) {
        if (-not $toRemove.Contains($log)) {
            $toRemove.Add($log)
        }
    }

    foreach ($log in $toRemove) {
        try {
            Remove-Item -LiteralPath $log.FullName -Force -ErrorAction Stop
            if ($Logger) {
                & $Logger "Pruned old log: $($log.Name)"
            }
        } catch {
            if ($Logger) {
                & $Logger "WARNING: Could not prune old log '$($log.Name)': $($_.Exception.Message)"
            }
        }
    }
}
