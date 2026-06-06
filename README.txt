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
  - Does not move user folders or change shell-folder mappings
  - Does not disable third-party startup items
  - Does not remove Edge browser itself
  - Does not remove or block WebView2
  - Does not touch unrelated system components, device drivers, security tools, sync tools, or vendor utilities
  - Does not uninstall OneDrive unless -RemoveOneDrive is explicitly passed
  - Does not disable Edge update services/tasks unless -DisableEdgeUpdates is explicitly passed

Usage:
  1. Open PowerShell as Administrator.
     Admin is required for dry run, apply, the wizard, and scheduled-task install.
     The launcher and cleanup scripts stop if they are not elevated.

  2. Guided wizard:
       powershell -ExecutionPolicy Bypass -File .\Start-Microsludge-Degoblin-Walkthrough.ps1 -Wizard

  3. Quick walkthrough menu:
       powershell -ExecutionPolicy Bypass -File .\Start-Microsludge-Degoblin-Walkthrough.ps1

  4. Dry run first:
       powershell -ExecutionPolicy Bypass -File .\Microsludge-Degoblin.ps1

  5. Test for Windows AI targets:
       powershell -ExecutionPolicy Bypass -File .\Test-Microsludge-WindowsAI.ps1

  6. Apply default Microsoft cleanup:
       powershell -ExecutionPolicy Bypass -File .\Microsludge-Degoblin.ps1 -Apply

  7. Apply stronger cleanup:
       powershell -ExecutionPolicy Bypass -File .\Microsludge-Degoblin.ps1 -Apply -BlockOneDrive -DisableEdgeUpdates

  8. Uninstall OneDrive too:
       powershell -ExecutionPolicy Bypass -File .\Microsludge-Degoblin.ps1 -Apply -RemoveOneDrive

Windows AI detection:
  Detection-only command:
       powershell -ExecutionPolicy Bypass -File .\Test-Microsludge-WindowsAI.ps1

  This reports:
  - WindowsAI policy registry paths
  - Recall, Click to Do, Settings AI agent, and Paint AI policy values
  - Recall optional feature state, when queryable
  - related Appx packages
  - related running processes

  It does not change registry values, packages, features, services, tasks, or processes.

  In wizard mode, this report runs as a preflight. The wizard only asks about
  Windows AI cleanup when the report finds related targets.

Skip switches:
  -SkipCopilot
  -SkipOneDrive
  -SkipEdge
  -SkipOutlook
  -SkipConsumerContent

  These work with the main cleanup script and with the scheduled-task installer.

Optional stronger switches:
  -AlwaysApply
      Scheduled-task installer/wrapper option. Runs cleanup at every scheduled
      logon launch instead of only after Windows Update reboot evidence.

  -BlockOneDrive
      Sets the Windows policy that blocks OneDrive file sync.

  -RemoveOneDrive
      Runs OneDriveSetup.exe /uninstall when a local OneDrive installer is found.

  -DisableEdgeUpdates
      Disables MicrosoftEdgeUpdate scheduled tasks and edgeupdate/edgeupdatem services.
      This can also affect WebView2 update freshness, so it is opt-in.

  -DisableWindowsAI
      Applies source-backed Windows AI policies for Recall availability/snapshots,
      Click to Do, Settings AI agent, and Paint AI features. This does not remove
      the Recall optional feature bits.

Scheduled task:
  Install the Windows Update-aware scheduled task:
       powershell -ExecutionPolicy Bypass -File .\Install-Microsludge-DegoblinTask.ps1

  Install an every-logon scheduled task:
       powershell -ExecutionPolicy Bypass -File .\Install-Microsludge-DegoblinTask.ps1 -AlwaysApply

  Install it with stronger options:
       powershell -ExecutionPolicy Bypass -File .\Install-Microsludge-DegoblinTask.ps1 -BlockOneDrive -DisableEdgeUpdates

  Remove the scheduled task:
       powershell -ExecutionPolicy Bypass -File .\Uninstall-Microsludge-DegoblinTask.ps1

  By default, the task runs at logon, waits two minutes, and only applies cleanup
  when the last reboot appears tied to Windows Update activity. With -AlwaysApply,
  it skips that Windows Update evidence gate.

Logs:
  Logs are written to:
       .\Logs

  Automated wrapper runs prune old logs:
       keep the 20 most recent logs and remove logs older than 90 days

Walkthrough:
  See:
       .\WALKTHROUGH.txt

License:
  MIT License. See:
       .\LICENSE

