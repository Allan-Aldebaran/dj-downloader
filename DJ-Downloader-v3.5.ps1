# DJ Downloader v3.5 - Windows PowerShell 5.1+
# Uses installed spotDL. Does not modify system configuration.
$ErrorActionPreference = 'Stop'
try {
    Add-Type -AssemblyName System.Windows.Forms
} catch {
    Write-Host "Windows Forms could not initialize: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}

function Read-Choice([string]$Prompt, [string[]]$Allowed, [string]$Default) {
    while ($true) {
        $value = (Read-Host "$Prompt [$Default]").Trim().ToLowerInvariant()
        if (-not $value) { return $Default }
        if ($Allowed -contains $value) { return $value }
        Write-Host "Choose: $($Allowed -join ', ')" -ForegroundColor Yellow
    }
}
function Pick-Folder {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    try {
        $dialog.Description = 'Choose the folder for DJ tracks'
        $dialog.ShowNewFolderButton = $true
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.SelectedPath }
        return $null
    } finally { $dialog.Dispose() }
}
function Pick-ErrorFile {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    try {
        $dialog.Title = 'Choose a spotDL error report'
        $dialog.Filter = 'Text reports (*.txt)|*.txt|All files (*.*)|*.*'
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.FileName }
        return $null
    } finally { $dialog.Dispose() }
}
function Quote-WindowsArgument([string]$Value) {
    # Windows command-line quoting, including embedded quotes and trailing backslashes.
    if ($Value -notmatch '[\s"]') { return $Value }
    $result = '"'
    $slashes = 0
    foreach ($char in $Value.ToCharArray()) {
        if ($char -eq [char]92) { $slashes++; continue }
        if ($char -eq [char]34) {
            $result += ('\' * ($slashes * 2 + 1)) + '"'
            $slashes = 0
            continue
        }
        $result += ('\' * $slashes) + $char
        $slashes = 0
    }
    return ($result + ('\' * ($slashes * 2)) + '"')
}
function Show-Dashboard([int]$Done, [int]$Total, [string]$Current, [string]$Status, [string]$Elapsed, [int]$NewFiles = -1) {
    $known = $Total -gt 0
    if ($known) {
        $ratio = [math]::Min(1, [math]::Max(0, $Done / [double]$Total))
        $filled = [int][math]::Floor(24 * $ratio)
        $bar = ('=' * $filled) + ('-' * (24 - $filled))
        $progress = ('[{0}] {1}%  {2}/{3}' -f $bar, [int][math]::Floor(100*$ratio), $Done, $Total)
    } else {
        $offset = [int]([DateTime]::UtcNow.Ticks / 10000000 % 20)
        $bar = ('-' * $offset) + ('====') + ('-' * (20-$offset))
        $progress = ('[{0}] Working' -f $bar)
    }
    $mode = if ($known) { 'RETRY FAILED TRACKS' } else { 'DOWNLOAD SPOTIFY' }
    $lines = @(
        '  DJ DOWNLOADER  /  v3.5',
        '  ----------------------------------------',
        ('  {0}' -f $mode),
        '',
        ('  {0}' -f $progress),
        '',
        ('  Track   {0}' -f $Current),
        ('  Status  {0}' -f $Status),
        ('  Time    {0}' -f $Elapsed)
    )
    if ($NewFiles -ge 0) { $lines += ('  New MP3 {0}' -f $NewFiles) }
    if ($null -eq $script:dashboardTop) { $script:dashboardTop = [Console]::CursorTop }
    try {
        $width = [math]::Max(20, [Console]::WindowWidth - 1)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            [Console]::SetCursorPosition(0, $script:dashboardTop + $i)
            $line = [string]$lines[$i]
            if ($line.Length -gt $width) { $line = $line.Substring(0, $width) }
            [Console]::Write($line.PadRight($width))
        }
        [Console]::SetCursorPosition(0, $script:dashboardTop + $lines.Count)
    } catch [System.ArgumentOutOfRangeException] {
        Clear-Host
        $script:dashboardTop = 0
    }
}

function Count-Mp3([string]$Folder) {
    return @(Get-ChildItem -LiteralPath $Folder -File -Filter '*.mp3' -ErrorAction SilentlyContinue).Count
}
function Get-SpotdlStatus([string]$OutFile, [string]$ErrFile, [string]$Previous) {
    $recent = @()
    foreach ($file in @($OutFile, $ErrFile)) {
        if (Test-Path -LiteralPath $file) {
            $recent += @(Get-Content -LiteralPath $file -Tail 6 -ErrorAction SilentlyContinue)
        }
    }
    $line = ($recent | Where-Object { $_ -and $_.Trim() } | Select-Object -Last 1)
    if (-not $line) { return $Previous }
    if ($line -match 'download|\d+(?:\.\d+)?%') { return 'Downloading / processing audio...' }
    if ($line -match 'search|matching|results') { return 'Searching audio providers...' }
    if ($line -match 'convert|ffmpeg') { return 'Converting audio...' }
    if ($line -match 'error|failed') { return 'Provider error; checking next result...' }
    return $Previous
}
function Test-AuthenticatedMode {
    $missing = @()
    foreach ($name in @('deno','ffmpeg')) {
        if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { $missing += $name }
    }
    if ($missing.Count -gt 0) {
        Write-Host "Firefox authentication requires: $($missing -join ', ')." -ForegroundColor Yellow
        return $false
    }
    # Do not read or persist cookies in this script. yt-dlp reads Firefox's profile directly.
    return $true
}
function Invoke-Spotdl([string]$Url, [string]$Folder, [string]$Bitrate, [string]$ErrorPath, [string[]]$Sources, [string]$SearchQuery = '', [int]$Done = -1, [int]$Total = 0, [string]$Track = '', [bool]$UseFirefox = $true) {
    $argsList = @('download', $Url, '--audio') + $Sources + @(
        '--format', 'mp3', '--bitrate', $Bitrate,
        '--output', (Join-Path $Folder '{artist} - {title}.{output-ext}'),
        '--overwrite', 'skip', '--save-errors', $ErrorPath
    )
    if ($SearchQuery) { $argsList += @('--search-query', $SearchQuery) }
    if ($UseFirefox) {
        # Forward options to yt-dlp during the FIRST spotDL pass, not only recovery.
        # Firefox cookies are used by yt-dlp; they are never written to our reports.
        $argsList += @('--yt-dlp-args', '--cookies-from-browser firefox --js-runtimes deno --remote-components ejs:github')
    }
    $stdout = Join-Path $env:TEMP ('dj-spotdl-' + [guid]::NewGuid().ToString('N') + '.out.log')
    $stderr = Join-Path $env:TEMP ('dj-spotdl-' + [guid]::NewGuid().ToString('N') + '.err.log')
    $proc = $null
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $status = 'Starting spotDL...'
    $isPlaylistMode = $Done -lt 0
    $initialFiles = if ($isPlaylistMode) { Count-Mp3 $Folder } else { 0 }
    $lastFileCheck = [DateTime]::MinValue
    $newFiles = 0
    $displayTrack = if ($isPlaylistMode) { 'Spotify URL' } else { $Track }
    try {
        $argString = ($argsList | ForEach-Object { Quote-WindowsArgument ([string]$_) }) -join ' '
        $proc = Start-Process -FilePath $script:spotdl.Source -ArgumentList $argString -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -NoNewWindow
        $script:dashboardTop = $null
        Show-Dashboard ([math]::Max(0,$Done)) $Total $displayTrack $status '00:00:00' $(if ($isPlaylistMode) { 0 } else { -1 })
        while (-not $proc.HasExited) {
            Start-Sleep -Milliseconds 800
            $proc.Refresh()
            $newStatus = Get-SpotdlStatus $stdout $stderr $status
            if ($newStatus -ne $status) {
                $status = $newStatus

            }
            if ($isPlaylistMode -and (([DateTime]::UtcNow - $lastFileCheck).TotalSeconds -ge 3)) {
                $newFiles = [math]::Max(0, (Count-Mp3 $Folder) - $initialFiles)
                $lastFileCheck = [DateTime]::UtcNow
            }
            Show-Dashboard ([math]::Max(0,$Done)) $Total $displayTrack $status $timer.Elapsed.ToString('hh\:mm\:ss') $(if ($isPlaylistMode) { $newFiles } else { -1 })
        }
        $proc.WaitForExit()
        if ($isPlaylistMode) {
            $newFiles = [math]::Max(0, (Count-Mp3 $Folder) - $initialFiles)
            Show-Dashboard 0 0 $displayTrack 'Finished (check report for failed tracks)' $timer.Elapsed.ToString('hh\:mm\:ss') $newFiles
        }
        return [int]$proc.ExitCode
    } finally {
        if ($proc) {
            $proc.Refresh()
            if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
            $proc.Dispose()
        }
        foreach ($file in @($stdout, $stderr)) { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
    }
}

function Read-Failures([string]$Path) {
    $entries = @()
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        if ($line -match '^(https://open\.spotify\.com/track/[A-Za-z0-9]+)\s+-\s+([^:]+):\s*(.*)$') {
            $url = $Matches[1]; $kind = $Matches[2]; $detail = $Matches[3]
            $name = ''
            if ($detail -match '^No results found for song:\s*(.+)$') { $name = $Matches[1] }
            $category = if ($kind -eq 'LookupError') { 'lookup' } elseif ($detail -match 'Sign in|Please sign in') { 'authentication' } elseif ($detail -match 'YT-DLP download error') { 'provider' } else { 'other' }
            $entries += [pscustomobject]@{ Url=$url; Kind=$kind; Category=$category; Name=$name; Detail=$detail }
        }
    }
    return @($entries | Sort-Object Url -Unique)
}
function Recover-Failures {
    $report = Pick-ErrorFile
    if (-not $report) { return }
    $items = @(Read-Failures $report)
    if ($items.Count -eq 0) { Write-Host 'No recognized Spotify track errors in this report.' -ForegroundColor Yellow; return }
    $folder = Pick-Folder
    if (-not $folder) { return }
    $bitrate = '320k'
    $useFirefox = $true
    if (-not (Test-AuthenticatedMode)) { return }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $csv = Join-Path $folder "spotdl-recovery-$stamp.csv"
    $results = @()
    Write-Host "Retrying $($items.Count) failed tracks..."
    Clear-Host
    $index = 0
    $script:dashboardTop = 0
    foreach ($item in $items) {
        $index++
        $trackLabel = if ($item.Name) { $item.Name } else { $item.Url }
        $retryError = Join-Path $folder "spotdl-retry-$stamp-$index.txt"
        $code = Invoke-Spotdl $item.Url $folder $bitrate $retryError @('youtube-music','youtube') '' ($index - 1) $items.Count $trackLabel $useFirefox
        $status = if ($code -eq 0 -and -not (Test-Path -LiteralPath $retryError)) { 'possible-success' } else { 'unresolved' }
        # spotDL's exit code alone does not prove a correct match or downloaded file.
        $search = if ($item.Name) { $item.Name } else { $item.Url }
        $results += [pscustomobject]@{
            SpotifyUrl=$item.Url; Track=$item.Name; OriginalError=$item.Kind;
            Category=$item.Category; Status=$status; SearchTerm=$search;
            SearchUrl=('https://www.youtube.com/results?search_query=' + [uri]::EscapeDataString($search));
            RetryLog=$(if (Test-Path -LiteralPath $retryError) { $retryError } else { '' })
        }
        $results | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8
        Show-Dashboard $index $items.Count $trackLabel "Attempt finished: $status" "--:--:--"
    }
    $script:dashboardTop = $null
    Write-Host "`nRecovery complete: $($items.Count)/$($items.Count) attempts processed." -ForegroundColor Green
    Write-Host "Recovery report: $csv" -ForegroundColor Green
    Write-Host 'Review possible-success tracks in Rekordbox: title, duration, version and audio quality.'
    Write-Host 'For unresolved tracks, the CSV includes a YouTube search link for manual matching.'
    Write-Host 'Manual match syntax: spotdl download "YOUTUBE_URL|SPOTIFY_URL" --format mp3 --bitrate 320k'
}

try { $script:spotdl = Get-Command spotdl -ErrorAction Stop }
catch {
    Write-Host 'spotDL not found on PATH.' -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}
function Show-Menu {
    Clear-Host
    Write-Host ''
    Write-Host '  DJ DOWNLOADER' -ForegroundColor Cyan
    Write-Host '  ----------------------------------------' -ForegroundColor DarkGray
    Write-Host '  1   Download new Spotify list'
    Write-Host '  2   Retry failed tracks'
    Write-Host '  0   Exit'
    Write-Host ''
    Write-Host '  MP3 320k  |  Firefox + Deno  |  Auto skip duplicates' -ForegroundColor DarkGray
    Write-Host ''
}

# Prerequisites are checked before each action; no hidden fallback to unauthenticated mode.
while ($true) {
    Show-Menu
    $choice = Read-Choice '  Select' @('0','1','2') '1'
    if ($choice -eq '0') { break }
    if (-not (Test-AuthenticatedMode)) {
        Read-Host 'Press Enter to return to menu' | Out-Null
        continue
    }
    if ($choice -eq '2') {
        try { Recover-Failures }
        catch { Write-Host "Recovery error: $($_.Exception.Message)" -ForegroundColor Red }
        Read-Host 'Press Enter to return to menu' | Out-Null
        continue
    }
    $url = (Read-Host 'Spotify track, album or playlist URL').Trim()
    if ($url -notmatch '^https://open\.spotify\.com/(track|album|playlist)/[A-Za-z0-9]+(?:\?.*)?$') {
        Write-Host 'Invalid Spotify URL.' -ForegroundColor Yellow
        Read-Host 'Press Enter to return to menu' | Out-Null
        continue
    }
    $folder = Pick-Folder
    if (-not $folder) { continue }
    $errorPath = Join-Path $folder ("spotdl-errors-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
    Clear-Host
    try {
        $code = Invoke-Spotdl $url $folder '320k' $errorPath @('youtube-music','youtube','soundcloud') '' -1 0 '' $true
        $script:dashboardTop = $null
        Write-Host "`n  Completed with exit code: $code"
        Write-Host "  Folder: $folder"
        if (Test-Path -LiteralPath $errorPath) { Write-Host "  Review errors: $errorPath" -ForegroundColor Yellow }
        if ($code -ne 0) { Write-Host '  Download did not finish successfully.' -ForegroundColor Yellow }
    } catch {
        $script:dashboardTop = $null
        Write-Host "Download error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host 'Press Enter to return to menu' | Out-Null
}
