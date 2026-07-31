<#
.SYNOPSIS
Creates desktop VS Code shortcuts for Tier 3 projects and assigns project icons.

.DESCRIPTION
For each entry in $projects, this script creates a desktop .lnk shortcut that opens
the remote project folder in VS Code using --folder-uri.

It also creates a Start Menu alias shortcut in shell:Programs\Tier 3 Shortcuts
named with initials (for example, "RS - rig-status"), so searching by initials
from the Windows key surfaces the right project.

If icons/<project-name>.ico does not exist, the script runs icon-creator.ps1 with
the configured initials and saves the generated icon for that project.

.USAGE
From this folder:
pwsh -ExecutionPolicy Bypass -File .\generate-tier-3-shortcuts.ps1

.CONFIGURE
Edit these variables near the top of the script:
- $vscode: path to Code.exe
- $folderUriBase: base remote folder URI
- $projects: project names and icon initials

.TIPS
To open VS Code maximized, add this to your VS Code user settings (Ctrl+Shift+P > "Open User Settings JSON"):
  "window.newWindowDimensions": "maximized"
#>

$vscode = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
$folderUriBase = "vscode-remote://ssh-remote+bhaensel-dev/home/bhaensel"
$projects = @(
    @{ Name = "rig-status"; Initials = "RS" },
    @{ Name = "rig-diagnostics"; Initials = "RD" },
    @{ Name = "edrvpn-new"; Initials = "VPN" },
    @{ Name = "rig-auto-login"; Initials = "RAL" },
    @{ Name = "splunk-message-dispatcher"; Initials = "SMD" },
    @{ Name = "tool-helmerich-and-payne"; Initials = "THP" },
    @{ Name = "config-file-download"; Initials = "CFD" },
    @{ Name = "rig-info"; Initials = "RI" },
    @{ Name = "rig-info-server"; Initials = "RIS" },
    @{ Name = "deployments"; Initials = "D" },
    @{ Name = "terraform_services"; Initials = "TS" },
    $null
)

$dest = Join-Path ([System.Environment]::GetFolderPath("Desktop")) "tier-3-shortcuts"
$startMenuAliasDir = Join-Path ([System.Environment]::GetFolderPath("StartMenu")) "Programs\Tier 3 Shortcuts"
$iconsDir = Join-Path $PSScriptRoot "icons"
$iconCreatorScript = Join-Path $PSScriptRoot "icon-creator.ps1"

if (-not (Test-Path -LiteralPath $dest)) {
    New-Item -Path $dest -ItemType Directory -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $startMenuAliasDir)) {
    New-Item -Path $startMenuAliasDir -ItemType Directory -Force | Out-Null
}

$shell = New-Object -ComObject WScript.Shell

foreach ($project in $projects) {
    if (-not $project) { continue }

    $projectName = $project.Name
    $initials = $project.Initials
    $shortcutPath = Join-Path $dest "$projectName.lnk"
    $aliasShortcutPath = Join-Path $startMenuAliasDir "$initials - $projectName.lnk"
    $iconPath = Join-Path $iconsDir "$projectName.ico"

    if (-not (Test-Path -LiteralPath $iconPath)) {
        & $iconCreatorScript -Initials $initials
        Copy-Item -Path (Join-Path $iconsDir "icon.ico") -Destination $iconPath -Force
        Write-Host "Generated icon for $projectName ($initials)"
    }

    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $vscode
    $folderUri = "$folderUriBase/$projectName"
    $shortcut.Arguments = "--folder-uri `"$folderUri`""
    $shortcut.IconLocation = $iconPath
    $shortcut.Description = "Tier 3 shortcut: $projectName ($initials)"
    $shortcut.Save()

    $aliasShortcut = $shell.CreateShortcut($aliasShortcutPath)
    $aliasShortcut.TargetPath = $vscode
    $aliasShortcut.Arguments = "--folder-uri `"$folderUri`""
    $aliasShortcut.IconLocation = $iconPath
    $aliasShortcut.Description = "Alias: $initials for $projectName"
    $aliasShortcut.Save()

    Write-Host "Created shortcut for $projectName"
}

if ($PSStyle) {
    $softYellow = $PSStyle.Foreground.FromRgb(0xF0CC4A)
    Write-Host ($PSStyle.Bold + $softYellow + "Please reboot your computer to ensure everything is updated." + $PSStyle.Reset)
}
else {
    Write-Host "Please reboot your computer to ensure everything is updated." -ForegroundColor Yellow
}