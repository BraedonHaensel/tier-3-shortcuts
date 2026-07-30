$vscode = "C:\Users\bhaensel\AppData\Local\Programs\Microsoft VS Code\Code.exe"
$folderUriBase = "vscode-remote://ssh-remote+bhaensel-dev/home/bhaensel"
$dest = [System.Environment]::GetFolderPath("Desktop")
$iconsDir = Join-Path $PSScriptRoot "icons"
$iconCreatorScript = Join-Path $PSScriptRoot "icon-creator.ps1"

$projects = @(
    @{ Name = "rig-status"; Initials = "RS" },
    @{ Name = "rig-diagnostics"; Initials = "RD" },
    @{ Name = "edrvpn-new"; Initials = "VPN" },
    @{ Name = "rig-info"; Initials = "RI" },
    @{ Name = "rig-info-server"; Initials = "RIS" },
    @{ Name = "deployments"; Initials = "D" },
    @{ Name = "terraform_services"; Initials = "TS" }
)

$shell = New-Object -ComObject WScript.Shell

foreach ($project in $projects) {
    $projectName = $project.Name
    $initials = $project.Initials
    $shortcutPath = Join-Path $dest "$projectName.lnk"
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
    $shortcut.Save()

    Write-Host "Created shortcut for $projectName"
}

Write-Host "Reboot your computer to refresh the shortcut icons."