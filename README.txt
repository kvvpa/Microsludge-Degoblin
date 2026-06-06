Microsludge Degoblin

Purpose:
  Re-check and correct common Microsoft app, startup, and policy resurrections after
  Windows Updates or feature upgrades.

Default targets:
  - Copilot Appx packages and provisioned packages
  - Copilot off policies for current user and machine
  - OneDrive running process and startup resurrection entries
  - Microsoft.OutlookForWindows app/provisioned package
  - Microsoft.Edge.GameAssist app/provisioned package
  - Edge browser background mode, startup boost, first-run, and sidebar policies
  - Microsoft consumer content, ads, suggestions, tailored experiences, activity upload
  - Widgets/news taskbar policy and user setting
  - SoftLanding, creative, and deferral scheduled tasks

Default non-targets:
  - Does not move Documents or other shell folders
  - Does not disable third-party startup items
  - Does not remove Edge browser itself
  - Does not remove or block WebView2
  - Does not remove Xbox, Windows Security, Realtek, printer, VPN, backup, or vendor tools
  - Does not uninstall OneDrive unless -RemoveOneDrive is explicitly passed
  - Does not disable Edge update services/tasks unless -DisableEdgeUpdates is explicitly passed

Usage:
  1. Open PowerShell as Administrator.

  2. Guided walkthrough:
       powershell -ExecutionPolicy Bypass -File .\Start-Microsludge-Degoblin-Walkthrough.ps1

  3. Dry run first:
       powershell -ExecutionPolicy Bypass -File .\Microsludge-Degoblin.ps1

  4. Apply default Microsoft cleanup:
       powershell -ExecutionPolicy Bypass -File .\Microsludge-Degoblin.ps1 -Apply

  5. Apply stronger cleanup:
       powershell -ExecutionPolicy Bypass -File .\Microsludge-Degoblin.ps1 -Apply -BlockOneDrive -DisableEdgeUpdates

  6. Uninstall OneDrive too:
       powershell -ExecutionPolicy Bypass -File .\Microsludge-Degoblin.ps1 -Apply -RemoveOneDrive

Skip switches:
  -SkipCopilot
  -SkipOneDrive
  -SkipEdge
  -SkipOutlook
  -SkipConsumerContent

Optional stronger switches:
  -BlockOneDrive
      Sets the Windows policy that blocks OneDrive file sync.

  -RemoveOneDrive
      Runs OneDriveSetup.exe /uninstall when a local OneDrive installer is found.

  -DisableEdgeUpdates
      Disables MicrosoftEdgeUpdate scheduled tasks and edgeupdate/edgeupdatem services.
      This can also affect WebView2 update freshness, so it is opt-in.

Scheduled task:
  Install the Windows Update-aware scheduled task:
       powershell -ExecutionPolicy Bypass -File .\Install-Microsludge-DegoblinTask.ps1

  Install it with stronger options:
       powershell -ExecutionPolicy Bypass -File .\Install-Microsludge-DegoblinTask.ps1 -BlockOneDrive -DisableEdgeUpdates

  The task runs at logon, waits two minutes, and only applies cleanup when the last
  reboot appears tied to Windows Update activity.

Logs:
  Logs are written to:
       .\Logs

Walkthrough:
  See:
       .\WALKTHROUGH.txt

License:
  MIT License. See:
       .\LICENSE

