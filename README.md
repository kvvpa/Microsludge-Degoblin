![Microsludge Degoblin 9000](Assets/microsludge-degoblin-9000-readme-banner.png)

# Microsludge Degoblin

Microsludge Degoblin is a Windows cleanup tool for Microsoft components that keep coming back after updates.

It targets things like Copilot, OneDrive startup entries, new Outlook, Edge background behavior, widgets, ads, suggestions, and optional Windows AI policies. It can run once, do a dry run first, or install a scheduled task that re-checks after Windows Update activity.

It has both a PowerShell console walkthrough and a GUI with guided setup, so users do not have to memorize which switches do what.

## Default Targets

- Copilot Appx packages and provisioned packages
- Copilot off policies for current user and machine
- OneDrive running process and startup resurrection entries
- Microsoft.OutlookForWindows app/provisioned package
- Microsoft.Edge.GameAssist app/provisioned package
- Edge browser background mode, startup boost, first-run, and sidebar policies
- Microsoft consumer content, ads, suggestions, tailored experiences, activity upload
- Widgets/news taskbar policy and user setting
- SoftLanding, creative, and deferral scheduled tasks

## Default Non-Targets

- Does not move user folders or change shell-folder mappings
- Does not disable third-party startup items
- Does not remove Edge browser itself
- Does not remove or block WebView2
- Does not touch unrelated system components, device drivers, security tools, sync tools, or vendor utilities
- Does not uninstall OneDrive unless `-RemoveOneDrive` is explicitly passed
- Does not disable Edge update services/tasks unless `-DisableEdgeUpdates` is explicitly passed

## Usage

Admin is required for detection reports, dry run, apply, the console wizard, and scheduled-task install. The GUI can open normally and relaunch itself elevated; console paths stop if they are not elevated.

Graphical launcher:

Double-click:

```text
Start-Microsludge-Degoblin-GUI.vbs
```

The `.vbs` launcher starts the GUI without leaving a PowerShell console window open.

PowerShell launch, useful for debugging:

```powershell
powershell -ExecutionPolicy Bypass -File .\Start-Microsludge-Degoblin-GUI.ps1
```

The GUI includes guided setup, Windows AI detection, dry run, apply, scheduled-task install/removal, and log access.

Guided console wizard:

```powershell
powershell -ExecutionPolicy Bypass -File .\Start-Microsludge-Degoblin-Walkthrough.ps1 -Wizard
```

Quick console menu:

```powershell
powershell -ExecutionPolicy Bypass -File .\Start-Microsludge-Degoblin-Walkthrough.ps1
```

Dry run first:

```powershell
powershell -ExecutionPolicy Bypass -File .\Microsludge-Degoblin.ps1
```

Apply default cleanup:

```powershell
powershell -ExecutionPolicy Bypass -File .\Microsludge-Degoblin.ps1 -Apply
```

Apply stronger cleanup:

```powershell
powershell -ExecutionPolicy Bypass -File .\Microsludge-Degoblin.ps1 -Apply -BlockOneDrive -DisableEdgeUpdates
```

Uninstall OneDrive too:

```powershell
powershell -ExecutionPolicy Bypass -File .\Microsludge-Degoblin.ps1 -Apply -RemoveOneDrive
```

## Windows AI Detection

Detection-only command:

```powershell
powershell -ExecutionPolicy Bypass -File .\Test-Microsludge-WindowsAI.ps1
```

This reports:

- WindowsAI policy registry paths
- Recall, Click to Do, Settings AI agent, and Paint AI policy values
- Recall optional feature state, when queryable
- Related Appx packages
- Related running processes

It does not change registry values, packages, features, services, tasks, or processes.

In wizard mode, this report runs as a preflight. The wizard only asks about Windows AI cleanup when the report finds related targets.

## Switches

Skip switches:

- `-SkipCopilot`
- `-SkipOneDrive`
- `-SkipEdge`
- `-SkipOutlook`
- `-SkipConsumerContent`

Optional stronger switches:

- `-AlwaysApply`: Scheduled-task installer/wrapper option. Runs cleanup at every scheduled logon launch instead of only when Windows Update evidence is found.
- `-BlockOneDrive`: Sets the Windows policy that blocks OneDrive file sync.
- `-RemoveOneDrive`: Runs `OneDriveSetup.exe /uninstall` when a local OneDrive installer is found.
- `-DisableEdgeUpdates`: Disables MicrosoftEdgeUpdate scheduled tasks and `edgeupdate` / `edgeupdatem` services. This can also affect WebView2 update freshness, so it is opt-in.
- `-DisableWindowsAI`: Applies Windows AI policies for Recall availability/snapshots, Click to Do, Settings AI agent, and Paint AI features. This does not remove the Recall optional feature bits.

## Scheduled Task

Install the Windows Update-aware scheduled task:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-Microsludge-DegoblinTask.ps1
```

Install an every-logon scheduled task:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-Microsludge-DegoblinTask.ps1 -AlwaysApply
```

Install it with stronger options:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-Microsludge-DegoblinTask.ps1 -BlockOneDrive -DisableEdgeUpdates
```

Remove the scheduled task:

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall-Microsludge-DegoblinTask.ps1
```

By default, the task runs at logon, waits two minutes, and only applies cleanup when Windows Update evidence is found. Evidence can come from restart/update event logs or the Windows Update pending-reboot registry key. With `-AlwaysApply`, it skips that evidence gate.

## Logs

Logs are written to `.\Logs`.

Apply runs and automated wrapper runs prune old logs, keeping the 20 most recent logs and removing logs older than 90 days.

## Assets

GUI and README art is stored in `.\Assets`.

## Walkthrough

See `.\WALKTHROUGH.txt`.

## Feed the Goblin

Microsludge Degoblin is free and open-source. If it saved you time or spared you a Windows-induced eye twitch, you can feed the goblin. Tips are appreciated, never required, and do not turn this into a support contract.

[Feed the goblin through GitHub Sponsors](https://github.com/sponsors/kvvpa).

## License

MIT License. See `.\LICENSE`.
