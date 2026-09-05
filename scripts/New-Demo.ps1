# Render an illustrative terminal session. Requires Windows and ffmpeg on PATH.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$frames = Join-Path $root ('publish/demo-' + [Guid]::NewGuid().ToString('N'))
$assets = Join-Path $root 'assets'
New-Item -ItemType Directory -Path $frames, $assets -Force | Out-Null
$font = New-Object Drawing.Font('Consolas', 20, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$titleFont = New-Object Drawing.Font('Segoe UI', 23, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
$smallFont = New-Object Drawing.Font('Segoe UI', 15, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$palette = @{
    Background = '#10151d'; Panel = '#171e29'; Text = '#e5edf7'
    Muted = '#91a0b5'; Accent = '#76dfad'; Blue = '#80bfff'
}
$brushes = @{}
foreach ($key in $palette.Keys) {
    $brushes[$key] = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml($palette[$key]))
}
$scenes = @(
    @{ Title = '01 / Save a directory'; Caption = 'Give a long path a short name.'; Steps = @(
        @{ Path = 'C:\projects\my-app'; Command = 'wd add app'; Output = "Added 'app' -> C:\projects\my-app" }
        @{ Path = 'C:\projects\my-app'; Command = 'cd C:\Windows'; Output = '' }
        @{ Path = 'C:\Windows'; Command = 'wd app'; Output = '' }
        @{ Path = 'C:\projects\my-app'; Command = ''; Output = '' }
    ) }
    @{ Title = '02 / Find your bookmarks'; Caption = 'List saved directories or print one path.'; Steps = @(
        @{ Path = 'C:\projects\my-app'; Command = 'wd list'; Output = 'app  ->  C:\projects\my-app' }
        @{ Path = 'C:\projects\my-app'; Command = 'wd path app'; Output = 'C:\projects\my-app' }
        @{ Path = 'C:\projects\my-app'; Command = ''; Output = '' }
    ) }
    @{ Title = '03 / Update or remove'; Caption = 'Bookmarks stay easy to manage.'; Steps = @(
        @{ Path = 'C:\projects\my-app'; Command = 'cd src'; Output = '' }
        @{ Path = 'C:\projects\my-app\src'; Command = 'wd add! app'; Output = "Updated 'app' -> C:\projects\my-app\src" }
        @{ Path = 'C:\projects\my-app\src'; Command = 'wd rm app'; Output = "Removed 'app'" }
        @{ Path = 'C:\projects\my-app\src'; Command = ''; Output = '' }
    ) }
)
$frameIndex = 0
try {
    foreach ($scene in $scenes) {
        $lines = New-Object System.Collections.Generic.List[object]
        foreach ($step in $scene.Steps) {
            $prompt = 'PS ' + $step.Path + '> '
            $typingFrames = [Math]::Max(1, $step.Command.Length)
            for ($tick = 0; $tick -lt ($typingFrames + 14); $tick++) {
                $typed = $step.Command.Substring(0, [Math]::Min($tick + 1, $step.Command.Length))
                $complete = $tick -ge $typingFrames
                $bitmap = New-Object Drawing.Bitmap(1000, 460)
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
                $graphics.Clear([Drawing.ColorTranslator]::FromHtml($palette.Background))
                $graphics.FillRectangle($brushes.Panel, 0, 0, 1000, 62)
                $graphics.DrawString('wd / Windows', $titleFont, $brushes.Text, 26, 14)
                $graphics.DrawString('PowerShell + CMD', $smallFont, $brushes.Muted, 817, 23)
                $graphics.DrawString($scene.Title, $smallFont, $brushes.Accent, 28, 81)
                $y = 119
                foreach ($line in $lines) {
                    $graphics.DrawString($line.Text, $font, $brushes[$line.Color], 28, $y)
                    $y += 29
                }
                $graphics.DrawString($prompt, $font, $brushes.Blue, 28, $y)
                # Count trailing spaces too, so the cursor never covers the prompt.
                $cellWidth = $graphics.MeasureString('M', $font, 2000, [Drawing.StringFormat]::GenericTypographic).Width
                $width = $prompt.Length * $cellWidth
                $graphics.DrawString($typed, $font, $brushes.Text, (28 + $width), $y)
                if (-not $complete -or $step.Command.Length -eq 0) {
                    $cursorWidth = $typed.Length * $cellWidth
                    $graphics.FillRectangle($brushes.Accent, (30 + $width + $cursorWidth), ($y + 3), 9, 21)
                }
                if ($complete -and $step.Output) {
                    $graphics.DrawString($step.Output, $font, $brushes.Muted, 28, ($y + 29))
                }
                $graphics.DrawString($scene.Caption, $smallFont, $brushes.Muted, 28, 421)
                $bitmap.Save((Join-Path $frames ('{0:D5}.png' -f $frameIndex)), [Drawing.Imaging.ImageFormat]::Png)
                $graphics.Dispose()
                $bitmap.Dispose()
                $frameIndex++
            }
            $lines.Add(@{ Text = $prompt + $step.Command; Color = 'Text' })
            if ($step.Output) { $lines.Add(@{ Text = $step.Output; Color = 'Muted' }) }
        }
    }
    $gif = Join-Path $assets 'wd-demo.gif'
    & ffmpeg -hide_banner -loglevel error -y -framerate 10 -i (Join-Path $frames '%05d.png') -filter_complex '[0:v]split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=none' -loop 0 $gif
    if ($LASTEXITCODE -ne 0) { throw 'GIF encoding failed.' }
    Write-Host "Generated $gif ($frameIndex frames)"
}
finally {
    $font.Dispose()
    $titleFont.Dispose()
    $smallFont.Dispose()
    foreach ($brush in $brushes.Values) { $brush.Dispose() }
}
