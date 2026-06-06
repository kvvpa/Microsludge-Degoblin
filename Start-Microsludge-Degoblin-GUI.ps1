<#
Graphical launcher for Microsludge Degoblin.

The GUI is a front end only. It reads options, shows reports, and delegates the
actual changes to the existing scripts.
#>

param(
    [switch]$NoSplash
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$helpers = Join-Path $scriptRoot "Microsludge-Degoblin.Helpers.ps1"
$mainScript = Join-Path $scriptRoot "Microsludge-Degoblin.ps1"
$installerScript = Join-Path $scriptRoot "Install-Microsludge-DegoblinTask.ps1"
$uninstallerScript = Join-Path $scriptRoot "Uninstall-Microsludge-DegoblinTask.ps1"
$logRoot = Join-Path $scriptRoot "Logs"
$assetRoot = Join-Path $scriptRoot "Assets"
$headerImagePath = Join-Path $assetRoot "microsludge-degoblin-9000-header.png"
$splashImagePath = Join-Path $assetRoot "microsludge-degoblin-9000-splash.png"

if (-not (Test-Path -LiteralPath $helpers)) {
    throw "Helper script not found: $helpers"
}

. $helpers

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function New-MicrosludgeBitmap {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit()
    $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmap.UriSource = New-Object System.Uri($resolvedPath)
    $bitmap.EndInit()
    $bitmap.Freeze()
    return $bitmap
}

function Show-MicrosludgeSplash {
    param([string]$Path)

    $bitmap = New-MicrosludgeBitmap -Path $Path
    if (-not $bitmap) {
        return
    }

    $image = New-Object System.Windows.Controls.Image
    $image.Source = $bitmap
    $image.Width = 760
    $image.Stretch = [System.Windows.Media.Stretch]::Uniform

    $border = New-Object System.Windows.Controls.Border
    $border.Background = [System.Windows.Media.Brushes]::Black
    $border.CornerRadius = New-Object System.Windows.CornerRadius(6)
    $border.Child = $image

    $window = New-Object System.Windows.Window
    $window.Title = "Microsludge Degoblin 9000"
    $window.WindowStyle = [System.Windows.WindowStyle]::None
    $window.ResizeMode = [System.Windows.ResizeMode]::NoResize
    $window.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
    $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
    $window.ShowInTaskbar = $false
    $window.Topmost = $true
    $window.Content = $border
    $null = $window.Show()
    Start-Sleep -Milliseconds 1100
    $window.Close()
}

function Format-GuiCommandLine {
    param(
        [string]$ScriptPath,
        [string[]]$ExtraArgs
    )

    $parts = @(
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ('"{0}"' -f $ScriptPath)
    ) + $ExtraArgs

    return $parts -join " "
}

if (-not $NoSplash) {
    Show-MicrosludgeSplash -Path $splashImagePath
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Microsludge Degoblin 9000"
        Width="1060"
        Height="760"
        MinWidth="900"
        MinHeight="680"
        WindowStartupLocation="CenterScreen"
        Background="#101416"
        FontFamily="Segoe UI">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#0B0E10" BorderBrush="#263237" BorderThickness="1" CornerRadius="6" Padding="12">
            <Image x:Name="HeaderImage" Height="150" Stretch="Uniform" HorizontalAlignment="Center"/>
        </Border>

        <Grid Grid.Row="1" Margin="0,12,0,12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="AdminStatusText"
                       Grid.Column="0"
                       Foreground="#DDE7E1"
                       FontSize="14"
                       VerticalAlignment="Center"
                       Text="Checking admin status..."/>
            <Button x:Name="ElevateButton"
                    Grid.Column="1"
                    Width="170"
                    Height="34"
                    Margin="12,0,0,0"
                    Content="Relaunch as admin"/>
        </Grid>

        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="360"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Background="#151B1E" BorderBrush="#2A363B" BorderThickness="1" CornerRadius="6" Padding="14">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel>
                        <TextBlock Text="Targets" Foreground="#F4F7F2" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,8"/>
                        <CheckBox x:Name="CheckCopilot" Content="Copilot cleanup" IsChecked="True" Foreground="#EAF1EC" Margin="0,6,0,0"/>
                        <CheckBox x:Name="CheckOneDrive" Content="OneDrive startup cleanup" IsChecked="True" Foreground="#EAF1EC" Margin="0,6,0,0"/>
                        <CheckBox x:Name="CheckEdge" Content="Edge background cleanup" IsChecked="True" Foreground="#EAF1EC" Margin="0,6,0,0"/>
                        <CheckBox x:Name="CheckOutlook" Content="New Outlook cleanup" IsChecked="True" Foreground="#EAF1EC" Margin="0,6,0,0"/>
                        <CheckBox x:Name="CheckConsumerContent" Content="Ads, suggestions, widgets" IsChecked="True" Foreground="#EAF1EC" Margin="0,6,0,0"/>

                        <Separator Margin="0,14,0,14" Background="#2A363B"/>

                        <TextBlock Text="Stronger Options" Foreground="#F4F7F2" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,8"/>
                        <CheckBox x:Name="CheckBlockOneDrive" Content="Block OneDrive file sync" Foreground="#EAF1EC" Margin="0,6,0,0"/>
                        <CheckBox x:Name="CheckRemoveOneDrive" Content="Uninstall OneDrive" Foreground="#EAF1EC" Margin="0,6,0,0"/>
                        <CheckBox x:Name="CheckDisableEdgeUpdates" Content="Disable Edge updates" Foreground="#EAF1EC" Margin="0,6,0,0"/>
                        <CheckBox x:Name="CheckWindowsAI" Content="Windows AI cleanup: run report first" Foreground="#EAF1EC" IsEnabled="False" Margin="0,6,0,0"/>

                        <Separator Margin="0,14,0,14" Background="#2A363B"/>

                        <TextBlock Text="Scheduled Task" Foreground="#F4F7F2" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,8"/>
                        <CheckBox x:Name="CheckAlwaysApply" Content="Run at every logon" Foreground="#EAF1EC" Margin="0,6,0,0"/>
                        <TextBlock Text="Unchecked means the task waits for Windows Update evidence."
                                   TextWrapping="Wrap"
                                   Foreground="#96A59C"
                                   Margin="22,4,0,0"/>

                        <Separator Margin="0,14,0,14" Background="#2A363B"/>

                        <TextBlock Text="Current Selection" Foreground="#F4F7F2" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,8"/>
                        <TextBlock x:Name="OptionSummaryText"
                                   Text="default"
                                   TextWrapping="Wrap"
                                   Foreground="#B7F7C1"
                                   FontFamily="Consolas"/>
                    </StackPanel>
                </ScrollViewer>
            </Border>

            <Grid Grid.Column="1" Margin="12,0,0,0">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <WrapPanel Grid.Row="0" Margin="0,0,0,10">
                    <Button x:Name="RunReportButton" Content="Run AI report" Width="125" Height="34" Margin="0,0,8,8"/>
                    <Button x:Name="DryRunButton" Content="Dry run" Width="100" Height="34" Margin="0,0,8,8"/>
                    <Button x:Name="ApplyButton" Content="Apply" Width="100" Height="34" Margin="0,0,8,8"/>
                    <Button x:Name="InstallTaskButton" Content="Install task" Width="110" Height="34" Margin="0,0,8,8"/>
                    <Button x:Name="UninstallTaskButton" Content="Uninstall task" Width="120" Height="34" Margin="0,0,8,8"/>
                    <Button x:Name="OpenLogsButton" Content="Open logs" Width="100" Height="34" Margin="0,0,8,8"/>
                    <Button x:Name="ShowSplashButton" Content="Splash" Width="80" Height="34" Margin="0,0,8,8"/>
                </WrapPanel>

                <TextBox x:Name="OutputBox"
                         Grid.Row="1"
                         Background="#070A0C"
                         Foreground="#D7FFE3"
                         BorderBrush="#2A363B"
                         FontFamily="Consolas"
                         FontSize="12"
                         IsReadOnly="True"
                         TextWrapping="Wrap"
                         AcceptsReturn="True"
                         VerticalScrollBarVisibility="Auto"
                         HorizontalScrollBarVisibility="Auto"/>
            </Grid>
        </Grid>

        <TextBlock Grid.Row="3"
                   Margin="0,12,0,0"
                   Foreground="#7F8D86"
                   Text="Dry run reports only. Apply and scheduled-task actions require Administrator."
                   HorizontalAlignment="Center"/>
    </Grid>
</Window>
'@

$xml = [xml]$xaml
$reader = New-Object System.Xml.XmlNodeReader $xml
$window = [Windows.Markup.XamlReader]::Load($reader)

$HeaderImage = $window.FindName("HeaderImage")
$AdminStatusText = $window.FindName("AdminStatusText")
$ElevateButton = $window.FindName("ElevateButton")
$CheckCopilot = $window.FindName("CheckCopilot")
$CheckOneDrive = $window.FindName("CheckOneDrive")
$CheckEdge = $window.FindName("CheckEdge")
$CheckOutlook = $window.FindName("CheckOutlook")
$CheckConsumerContent = $window.FindName("CheckConsumerContent")
$CheckBlockOneDrive = $window.FindName("CheckBlockOneDrive")
$CheckRemoveOneDrive = $window.FindName("CheckRemoveOneDrive")
$CheckDisableEdgeUpdates = $window.FindName("CheckDisableEdgeUpdates")
$CheckWindowsAI = $window.FindName("CheckWindowsAI")
$CheckAlwaysApply = $window.FindName("CheckAlwaysApply")
$OptionSummaryText = $window.FindName("OptionSummaryText")
$RunReportButton = $window.FindName("RunReportButton")
$DryRunButton = $window.FindName("DryRunButton")
$ApplyButton = $window.FindName("ApplyButton")
$InstallTaskButton = $window.FindName("InstallTaskButton")
$UninstallTaskButton = $window.FindName("UninstallTaskButton")
$OpenLogsButton = $window.FindName("OpenLogsButton")
$ShowSplashButton = $window.FindName("ShowSplashButton")
$OutputBox = $window.FindName("OutputBox")

$headerBitmap = New-MicrosludgeBitmap -Path $headerImagePath
if ($headerBitmap) {
    $HeaderImage.Source = $headerBitmap
}

$script:Busy = $false
$script:WindowsAITargetFound = $false
$script:AdminOnlyButtons = @(
    $RunReportButton,
    $DryRunButton,
    $ApplyButton,
    $InstallTaskButton,
    $UninstallTaskButton
)

function Add-GuiLog {
    param([string]$Message)

    $time = Get-Date -Format "HH:mm:ss"
    $OutputBox.AppendText("[{0}] {1}`r`n" -f $time, $Message)
    $OutputBox.ScrollToEnd()
}

function Show-GuiMessage {
    param(
        [string]$Message,
        [string]$Title = "Microsludge Degoblin 9000",
        [System.Windows.MessageBoxImage]$Icon = [System.Windows.MessageBoxImage]::Information
    )

    [System.Windows.MessageBox]::Show($window, $Message, $Title, [System.Windows.MessageBoxButton]::OK, $Icon) | Out-Null
}

function Confirm-GuiAction {
    param(
        [string]$Message,
        [string]$Title = "Confirm"
    )

    $result = [System.Windows.MessageBox]::Show($window, $Message, $Title, [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    return $result -eq [System.Windows.MessageBoxResult]::Yes
}

function Get-GuiSwitchValues {
    return @{
        AlwaysApply = [bool]$CheckAlwaysApply.IsChecked
        BlockOneDrive = [bool]$CheckBlockOneDrive.IsChecked
        RemoveOneDrive = [bool]$CheckRemoveOneDrive.IsChecked
        DisableEdgeUpdates = [bool]$CheckDisableEdgeUpdates.IsChecked
        DisableWindowsAI = ($CheckWindowsAI.IsEnabled -and [bool]$CheckWindowsAI.IsChecked)
        SkipCopilot = -not [bool]$CheckCopilot.IsChecked
        SkipOneDrive = -not [bool]$CheckOneDrive.IsChecked
        SkipEdge = -not [bool]$CheckEdge.IsChecked
        SkipOutlook = -not [bool]$CheckOutlook.IsChecked
        SkipConsumerContent = -not [bool]$CheckConsumerContent.IsChecked
    }
}

function Get-GuiCleanupArgs {
    $values = Get-GuiSwitchValues
    return @(Get-MicrosludgeSwitchArgumentList -Values $values -Names (Get-MicrosludgeCleanupSwitchNames))
}

function Get-GuiWrapperArgs {
    $values = Get-GuiSwitchValues
    return @(Get-MicrosludgeSwitchArgumentList -Values $values -Names (Get-MicrosludgeWrapperSwitchNames))
}

function Update-GuiSummary {
    $values = Get-GuiSwitchValues
    $OptionSummaryText.Text = Get-MicrosludgeOptionSummary -Values $values -Names (Get-MicrosludgeWrapperSwitchNames)
}

function Update-GuiState {
    $isAdmin = Test-MicrosludgeIsAdmin
    if ($isAdmin) {
        $AdminStatusText.Text = "Administrator: yes. The degoblinator is armed, politely."
        $AdminStatusText.Foreground = [System.Windows.Media.Brushes]::LightGreen
        $ElevateButton.Visibility = [System.Windows.Visibility]::Collapsed
    } else {
        $AdminStatusText.Text = "Administrator: no. Relaunch elevated before running reports or changes."
        $AdminStatusText.Foreground = [System.Windows.Media.Brushes]::Khaki
        $ElevateButton.Visibility = [System.Windows.Visibility]::Visible
    }

    foreach ($button in $script:AdminOnlyButtons) {
        $button.IsEnabled = ($isAdmin -and -not $script:Busy)
    }

    $OpenLogsButton.IsEnabled = -not $script:Busy
    $ShowSplashButton.IsEnabled = -not $script:Busy
    $ElevateButton.IsEnabled = (-not $isAdmin -and -not $script:Busy)
    $CheckWindowsAI.IsEnabled = ($isAdmin -and -not $script:Busy -and $script:WindowsAITargetFound)
}

function Set-GuiBusy {
    param([bool]$Busy)

    $script:Busy = $Busy
    if ($Busy) {
        $window.Cursor = [System.Windows.Input.Cursors]::Wait
    } else {
        $window.Cursor = $null
    }

    Update-GuiState
}

function Assert-GuiAdmin {
    if (Test-MicrosludgeIsAdmin) {
        return $true
    }

    Show-GuiMessage -Message "Relaunch as Administrator first. Windows blocks the report and cleanup paths without elevation." -Icon Warning
    return $false
}

function Invoke-GuiScript {
    param(
        [string]$Label,
        [string]$ScriptPath,
        [string[]]$ExtraArgs
    )

    if (-not (Assert-GuiAdmin)) {
        return
    }

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        Add-GuiLog "Missing script: $ScriptPath"
        Show-GuiMessage -Message "Missing script: $ScriptPath" -Icon Error
        return
    }

    $commandLine = Format-GuiCommandLine -ScriptPath $ScriptPath -ExtraArgs $ExtraArgs
    Add-GuiLog ""
    Add-GuiLog $Label
    Add-GuiLog $commandLine

    Set-GuiBusy $true
    try {
        $runArgs = @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $ScriptPath
        ) + $ExtraArgs

        & powershell.exe @runArgs *>&1 |
            ForEach-Object {
                Add-GuiLog "$_"
            }

        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) {
            $exitCode = 0
        }

        Add-GuiLog "Exit code: $exitCode"
    } catch {
        Add-GuiLog "ERROR: $($_.Exception.Message)"
        Show-GuiMessage -Message $_.Exception.Message -Icon Error
    } finally {
        Set-GuiBusy $false
    }
}

$optionControls = @(
    $CheckCopilot,
    $CheckOneDrive,
    $CheckEdge,
    $CheckOutlook,
    $CheckConsumerContent,
    $CheckBlockOneDrive,
    $CheckRemoveOneDrive,
    $CheckDisableEdgeUpdates,
    $CheckWindowsAI,
    $CheckAlwaysApply
)

foreach ($control in $optionControls) {
    $control.Add_Checked({ Update-GuiSummary })
    $control.Add_Unchecked({ Update-GuiSummary })
}

$ElevateButton.Add_Click({
    $argList = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ('"{0}"' -f $PSCommandPath)
    )

    Start-Process -FilePath "powershell.exe" -ArgumentList ($argList -join " ") -Verb RunAs
    $window.Close()
})

$RunReportButton.Add_Click({
    if (-not (Assert-GuiAdmin)) {
        return
    }

    Add-GuiLog ""
    Add-GuiLog "Running Windows AI detection report."
    Set-GuiBusy $true
    try {
        $reportLines = New-Object System.Collections.Generic.List[string]
        $detection = Get-MicrosludgeWindowsAIDetection
        Write-MicrosludgeWindowsAIReport -Detection $detection -Writer {
            param([string]$Message)
            $reportLines.Add($Message)
        }

        foreach ($line in $reportLines) {
            Add-GuiLog $line
        }

        $script:WindowsAITargetFound = Test-MicrosludgeWindowsAITargetFound -Detection $detection
        if ($script:WindowsAITargetFound) {
            $CheckWindowsAI.Content = "Windows AI cleanup: available"
            Add-GuiLog "Windows AI cleanup option enabled."
        } else {
            $CheckWindowsAI.IsChecked = $false
            $CheckWindowsAI.Content = "Windows AI cleanup: omitted, no targets found"
            Add-GuiLog "Windows AI cleanup option omitted because no targets were found."
        }
    } catch {
        Add-GuiLog "ERROR: $($_.Exception.Message)"
        Show-GuiMessage -Message $_.Exception.Message -Icon Error
    } finally {
        Set-GuiBusy $false
        Update-GuiSummary
    }
})

$DryRunButton.Add_Click({
    $args = Get-GuiCleanupArgs
    Invoke-GuiScript -Label "Running dry run." -ScriptPath $mainScript -ExtraArgs $args
})

$ApplyButton.Add_Click({
    $args = @("-Apply") + (Get-GuiCleanupArgs)
    $message = "Apply the selected cleanup now?"
    if ([bool]$CheckRemoveOneDrive.IsChecked) {
        $message += "`r`n`r`nOneDrive uninstall is selected."
    }

    if (Confirm-GuiAction -Message $message -Title "Apply cleanup") {
        Invoke-GuiScript -Label "Applying selected cleanup." -ScriptPath $mainScript -ExtraArgs $args
    }
})

$InstallTaskButton.Add_Click({
    $args = Get-GuiWrapperArgs
    $message = "Install the scheduled task with the selected options?"
    if ([bool]$CheckAlwaysApply.IsChecked) {
        $message += "`r`n`r`nIt will run at every logon."
    } else {
        $message += "`r`n`r`nIt will run only when Windows Update evidence is found."
    }

    if ([bool]$CheckRemoveOneDrive.IsChecked) {
        $message += "`r`n`r`nOneDrive uninstall is selected for future task runs."
    }

    if (Confirm-GuiAction -Message $message -Title "Install scheduled task") {
        Invoke-GuiScript -Label "Installing scheduled task." -ScriptPath $installerScript -ExtraArgs $args
    }
})

$UninstallTaskButton.Add_Click({
    if (Confirm-GuiAction -Message "Remove the Microsludge Degoblin scheduled task?" -Title "Uninstall scheduled task") {
        Invoke-GuiScript -Label "Removing scheduled task." -ScriptPath $uninstallerScript -ExtraArgs @()
    }
})

$OpenLogsButton.Add_Click({
    if (-not (Test-Path -LiteralPath $logRoot)) {
        New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
    }

    Start-Process explorer.exe -ArgumentList ('"{0}"' -f $logRoot)
})

$ShowSplashButton.Add_Click({
    Show-MicrosludgeSplash -Path $splashImagePath
})

$window.Add_ContentRendered({
    Add-GuiLog "Microsludge Degoblin GUI ready."
    Add-GuiLog "Run the AI report before enabling Windows AI cleanup."
    Update-GuiState
    Update-GuiSummary
})

Update-GuiState
Update-GuiSummary
$window.ShowDialog() | Out-Null
