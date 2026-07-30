$vscode = "C:\Users\bhaensel\AppData\Local\Programs\Microsoft VS Code\Code.exe"
$dest = [System.Environment]::GetFolderPath("Desktop")

$projects = @(
    "rig-status",
    "rig-diagnostics",
    "edrvpn-new",
    "rig-info",
    "rig-info-server"
)

$shell = New-Object -ComObject WScript.Shell

foreach ($project in $projects) {
    $shortcutPath = Join-Path $dest "$project.lnk"

    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $vscode
    $shortcut.Arguments = "--folder-uri `"vscode-remote://ssh-remote+bhaensel-dev/home/bhaensel/$project`""
    $shortcut.IconLocation = "$vscode,0"
    $shortcut.Save()

    Write-Host "Created $project"
}
