<#
.SYNOPSIS
Creates a circular .ico icon with initials.

.DESCRIPTION
Generates a 256x256 icon at icons/icon.ico using the initials you provide.
The icon uses a random dark/saturated background color chosen to keep strong
contrast with white foreground text.

.USAGE
With argument:
pwsh -ExecutionPolicy Bypass -File .\icon-creator.ps1 -Initials RS

Prompted input:
pwsh -ExecutionPolicy Bypass -File .\icon-creator.ps1

.CONFIGURE
Edit these variables near the top of the script:
- $iconSize
- $outputPath
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Initials
)

$iconSize = 256
$outputPath = Join-Path $PSScriptRoot "icons\icon.ico"

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Initials)) {
    $Initials = Read-Host "Enter initials (examples: RS, VPN)"
}

$Initials = $Initials.Trim().ToUpperInvariant()
if ([string]::IsNullOrWhiteSpace($Initials)) {
    throw "Initials cannot be empty."
}

Add-Type -AssemblyName System.Drawing

function Blend-Color {
    param(
        [Parameter(Mandatory = $true)]
        [System.Drawing.Color]$BaseColor,

        [Parameter(Mandatory = $true)]
        [System.Drawing.Color]$TargetColor,

        [Parameter(Mandatory = $true)]
        [double]$Amount
    )

    $r = [int][Math]::Round($BaseColor.R + (($TargetColor.R - $BaseColor.R) * $Amount))
    $g = [int][Math]::Round($BaseColor.G + (($TargetColor.G - $BaseColor.G) * $Amount))
    $b = [int][Math]::Round($BaseColor.B + (($TargetColor.B - $BaseColor.B) * $Amount))
    return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
}

function Convert-HslToColor {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Hue,

        [Parameter(Mandatory = $true)]
        [double]$Saturation,

        [Parameter(Mandatory = $true)]
        [double]$Lightness
    )

    $h = ($Hue % 360) / 360.0
    $s = [Math]::Max(0.0, [Math]::Min(1.0, $Saturation))
    $l = [Math]::Max(0.0, [Math]::Min(1.0, $Lightness))

    if ($s -eq 0) {
        $gray = [int][Math]::Round($l * 255)
        return [System.Drawing.Color]::FromArgb(255, $gray, $gray, $gray)
    }

    $q = if ($l -lt 0.5) { $l * (1 + $s) } else { $l + $s - ($l * $s) }
    $p = 2 * $l - $q

    function Get-HueChannel([double]$pValue, [double]$qValue, [double]$tValue) {
        $t = $tValue
        if ($t -lt 0) { $t += 1 }
        if ($t -gt 1) { $t -= 1 }
        if ($t -lt (1.0 / 6.0)) { return $pValue + (($qValue - $pValue) * 6 * $t) }
        if ($t -lt 0.5) { return $qValue }
        if ($t -lt (2.0 / 3.0)) { return $pValue + (($qValue - $pValue) * ((2.0 / 3.0) - $t) * 6) }
        return $pValue
    }

    $r = Get-HueChannel $p $q ($h + (1.0 / 3.0))
    $g = Get-HueChannel $p $q $h
    $b = Get-HueChannel $p $q ($h - (1.0 / 3.0))

    return [System.Drawing.Color]::FromArgb(
        255,
        [int][Math]::Round($r * 255),
        [int][Math]::Round($g * 255),
        [int][Math]::Round($b * 255)
    )
}

function Get-RelativeLuminance {
    param(
        [Parameter(Mandatory = $true)]
        [System.Drawing.Color]$Color
    )

    function Convert-Srgb([double]$channel) {
        if ($channel -le 0.04045) { return $channel / 12.92 }
        return [Math]::Pow(($channel + 0.055) / 1.055, 2.4)
    }

    $r = Convert-Srgb ($Color.R / 255.0)
    $g = Convert-Srgb ($Color.G / 255.0)
    $b = Convert-Srgb ($Color.B / 255.0)

    return (0.2126 * $r) + (0.7152 * $g) + (0.0722 * $b)
}

function Get-ContrastRatio {
    param(
        [Parameter(Mandatory = $true)]
        [System.Drawing.Color]$ColorA,

        [Parameter(Mandatory = $true)]
        [System.Drawing.Color]$ColorB
    )

    $lumA = Get-RelativeLuminance -Color $ColorA
    $lumB = Get-RelativeLuminance -Color $ColorB
    $maxLum = [Math]::Max($lumA, $lumB)
    $minLum = [Math]::Min($lumA, $lumB)
    return ($maxLum + 0.05) / ($minLum + 0.05)
}

function New-RandomBackgroundColor {
    for ($i = 0; $i -lt 50; $i++) {
        $hue = Get-Random -Minimum 0.0 -Maximum 360.0
        $saturation = Get-Random -Minimum 0.55 -Maximum 0.90
        $lightness = Get-Random -Minimum 0.22 -Maximum 0.42
        $candidate = Convert-HslToColor -Hue $hue -Saturation $saturation -Lightness $lightness

        if ((Get-ContrastRatio -ColorA $candidate -ColorB ([System.Drawing.Color]::White)) -ge 4.5) {
            return $candidate
        }
    }

    # Fallback in case random generation fails contrast checks.
    return [System.Drawing.Color]::FromArgb(255, 24, 92, 140)
}

function Write-IcoFromPng {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$PngBytes,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [int]$IconSize
    )

    $widthByte = if ($IconSize -ge 256) { [byte]0 } else { [byte]$IconSize }
    $heightByte = if ($IconSize -ge 256) { [byte]0 } else { [byte]$IconSize }

    $directory = Split-Path -Path $Path -Parent
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    $fileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    $writer = New-Object System.IO.BinaryWriter($fileStream)

    try {
        # ICONDIR
        $writer.Write([UInt16]0)  # reserved
        $writer.Write([UInt16]1)  # type = icon
        $writer.Write([UInt16]1)  # image count

        # ICONDIRENTRY
        $writer.Write($widthByte)                 # width (0 = 256)
        $writer.Write($heightByte)                # height (0 = 256)
        $writer.Write([byte]0)                    # color count
        $writer.Write([byte]0)                    # reserved
        $writer.Write([UInt16]1)                  # planes
        $writer.Write([UInt16]32)                 # bit depth
        $writer.Write([UInt32]$PngBytes.Length)   # image size
        $writer.Write([UInt32]22)                 # image offset (6 + 16)

        # Image data (PNG payload)
        $writer.Write($PngBytes)
    }
    finally {
        if ($writer) { $writer.Dispose() }
        if ($fileStream) { $fileStream.Dispose() }
    }
}

$bitmap = $null
$graphics = $null
$font = $null
$textBrush = $null
$textShadowBrush = $null
$stringFormat = $null
$memoryStream = $null
$gradientBrush = $null
$shadowBrush = $null
$outerRingPen = $null
$innerRingPen = $null

try {
    $bitmap = New-Object System.Drawing.Bitmap($iconSize, $iconSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $graphics.Clear([System.Drawing.Color]::Transparent)

    $baseColor = New-RandomBackgroundColor
    $topColor = Blend-Color -BaseColor $baseColor -TargetColor ([System.Drawing.Color]::White) -Amount 0.20
    $bottomColor = Blend-Color -BaseColor $baseColor -TargetColor ([System.Drawing.Color]::Black) -Amount 0.25

    $margin = [int][Math]::Round($iconSize * 0.09)
    $diameter = $iconSize - (2 * $margin)
    $circleRect = New-Object System.Drawing.Rectangle($margin, $margin, $diameter, $diameter)
    $shadowOffset = [int][Math]::Round($iconSize * 0.03)
    $shadowRect = New-Object System.Drawing.Rectangle(($margin + $shadowOffset), ($margin + $shadowOffset), $diameter, $diameter)

    $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55, 0, 0, 0))
    $graphics.FillEllipse($shadowBrush, $shadowRect)

    $gradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($circleRect, $topColor, $bottomColor, 45.0)
    $graphics.FillEllipse($gradientBrush, $circleRect)

    $outerRingPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80, 0, 0, 0), [Math]::Max(2, [int]($iconSize * 0.015)))
    $graphics.DrawEllipse($outerRingPen, $circleRect)

    $innerInset = [int][Math]::Round($iconSize * 0.025)
    $innerRect = New-Object System.Drawing.Rectangle(
        ($circleRect.X + $innerInset),
        ($circleRect.Y + $innerInset),
        ($circleRect.Width - (2 * $innerInset)),
        ($circleRect.Height - (2 * $innerInset))
    )
    $innerRingPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 255, 255, 255), [Math]::Max(1, [int]($iconSize * 0.01)))
    $graphics.DrawEllipse($innerRingPen, $innerRect)

    $stringFormat = New-Object System.Drawing.StringFormat
    $stringFormat.Alignment = [System.Drawing.StringAlignment]::Center
    $stringFormat.LineAlignment = [System.Drawing.StringAlignment]::Center

    $textRect = New-Object System.Drawing.RectangleF($circleRect.X, ($circleRect.Y - ($iconSize * 0.01)), $circleRect.Width, $circleRect.Height)

    $fontSize = [Math]::Floor($iconSize * 0.44)
    while ($fontSize -ge 10) {
        if ($font) { $font.Dispose() }
        $font = New-Object System.Drawing.Font("Segoe UI Semibold", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

        $textSize = $graphics.MeasureString($Initials, $font)
        if ($textSize.Width -le ($circleRect.Width * 0.74) -and $textSize.Height -le ($circleRect.Height * 0.52)) {
            break
        }

        $fontSize -= 2
    }

    $textShadowRect = New-Object System.Drawing.RectangleF(($textRect.X + 1.5), ($textRect.Y + 2), $textRect.Width, $textRect.Height)
    $textShadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(75, 0, 0, 0))
    $graphics.DrawString($Initials, $font, $textShadowBrush, $textShadowRect, $stringFormat)

    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
    $graphics.DrawString($Initials, $font, $textBrush, $textRect, $stringFormat)

    $memoryStream = New-Object System.IO.MemoryStream
    $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngBytes = $memoryStream.ToArray()

    Write-IcoFromPng -PngBytes $pngBytes -Path $outputPath -IconSize $iconSize

    Write-Host "Created icon: $outputPath"
}
finally {
    if ($memoryStream) { $memoryStream.Dispose() }
    if ($textBrush) { $textBrush.Dispose() }
    if ($textShadowBrush) { $textShadowBrush.Dispose() }
    if ($font) { $font.Dispose() }
    if ($stringFormat) { $stringFormat.Dispose() }
    if ($innerRingPen) { $innerRingPen.Dispose() }
    if ($outerRingPen) { $outerRingPen.Dispose() }
    if ($gradientBrush) { $gradientBrush.Dispose() }
    if ($shadowBrush) { $shadowBrush.Dispose() }
    if ($graphics) { $graphics.Dispose() }
    if ($bitmap) { $bitmap.Dispose() }
}
