# DJ Downloader

**A simple, interactive music downloader for Windows, powered by spotDL, yt-dlp, FFmpeg, and PowerShell.**

DJ Downloader simplifies downloading music from Spotify playlists and recovering failed tracks through a minimal terminal interface.

Built for DJs, music enthusiasts, and anyone who wants a straightforward workflow without repeatedly configuring command-line tools.

> **Note:** Spotify is used for track discovery and metadata. Audio is obtained from supported external providers, not directly from Spotify.

## Features

- **Spotify playlist downloads** — Download tracks, albums, and playlists using a Spotify URL.
- **Failed track recovery** — Retry tracks from spotDL error reports.
- **YouTube authentication** — Support for Firefox browser cookies and Deno-based JavaScript challenge solving.
- **MP3 output** — Configured for 320 kbps MP3 encoding.
- **Interactive terminal dashboard** — Animated progress indicators, elapsed time, and download status.
- **Duplicate protection** — Skip existing files when supported by the download workflow.
- **Windows folder selection** — Choose where to save your music.
- **Simplified interface** — Two primary actions, with advanced configuration handled internally.

## Interface

```text
DJ DOWNLOADER
----------------------------------------

1   Download new Spotify list
2   Retry failed tracks
0   Exit

----------------------------------------
MP3 320k | Firefox + Deno | Skip duplicates
```

The goal is simple: select an operation, provide your input, and let the downloader handle the rest.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell
- Python with a version supported by spotDL
- [spotDL](https://github.com/spotDL/spotify-downloader)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [FFmpeg](https://ffmpeg.org/)
- [Deno](https://deno.com/)
- Mozilla Firefox with an authenticated YouTube session for restricted content

The current script targets **spotDL 4.5.2**. Other versions have not been validated.

## Installation

### 1. Install Python

Download a supported version from [python.org](https://www.python.org/downloads/).

Make sure Python and pip are available from your terminal.

### 2. Install spotDL and yt-dlp

```powershell
python -m pip install spotdl==4.5.2 yt-dlp
```

### 3. Install FFmpeg and Deno

Using Windows Package Manager:

```powershell
winget install --id Gyan.FFmpeg -e
winget install --id DenoLand.Deno -e
```

Restart PowerShell after installation.

Verify your tools:

```powershell
spotdl --version
yt-dlp --version
ffmpeg -version
deno --version
```

### 4. Download DJ Downloader

Clone the repository:

```powershell
git clone https://github.com/YOUR_USERNAME/dj-downloader.git
cd dj-downloader
```

Alternatively, download the repository as a ZIP file from GitHub.

### 5. Launch

Run:

```text
Open-DJ-Downloader-v3.5.cmd
```

The launcher starts the PowerShell interface without requiring a permanent change to your system's execution policy.

## Usage

### Download a new Spotify playlist

1. Launch DJ Downloader.
2. Select `1 — Download new Spotify list`.
3. Paste a Spotify track, album, or playlist URL.
4. Select your destination folder.
5. Follow the download progress in the terminal.

### Retry failed tracks

1. Launch DJ Downloader.
2. Select `2 — Retry failed tracks`.
3. Select a compatible spotDL error report.
4. Let the downloader retry the available tracks.
5. Review the recovery results.

Some tracks may remain unavailable because of provider restrictions, missing sources, or incorrect search matches.

## Audio Quality

DJ Downloader targets MP3 encoding at 320 kbps.

**Important:** Encoding audio at 320 kbps does not guarantee that the original source has equivalent quality.

For example, converting a 128 kbps AAC source into a 320 kbps MP3 cannot restore information already lost through compression.

Actual audio quality depends on the source provider and available formats.

## Troubleshooting

### PowerShell blocks script execution

Use the included `.cmd` launcher instead of changing the system-wide PowerShell execution policy.

### YouTube requires age verification

Sign in to YouTube using Firefox with an account authorized to access the content.

Authentication does not guarantee that every restricted video is available.

### YouTube signature or JavaScript challenge errors

Verify that Deno is installed and accessible:

```powershell
deno --version
```

Some YouTube challenges may also require supported yt-dlp JavaScript solver components.

### FFmpeg is not recognized

Install FFmpeg and restart your terminal:

```powershell
winget install --id Gyan.FFmpeg -e
```

Verify:

```powershell
ffmpeg -version
```

### A track downloads incorrectly

Automated matching is not perfect. Different edits, remixes, live performances, or full DJ sets may have similar titles.

Always verify the resulting audio before importing it into your DJ library.

## Security

- Do not commit browser cookies, authentication tokens, or credentials.
- Keep authentication information out of public logs and issue reports.
- Use an authenticated browser session only when required.
- Keep third-party dependencies updated.
- Review downloaded content before using it in a live performance.

## Project Status

**Version:** 3.5

**Platform:** Windows

**Status:** Experimental / personal-use release.

The project is under active refinement. Compatibility and end-to-end behavior should be verified in the target Windows environment before relying on it for large music collections.

## Disclaimer

DJ Downloader is an independent project and is not affiliated with, endorsed by, or sponsored by Spotify, YouTube, or their respective owners.

Users are responsible for complying with applicable copyright laws, licensing requirements, and the terms of service of the platforms they use.

Downloading music does not automatically grant permission for public performance, redistribution, or commercial use.

---

**Made for music discovery, DJ preparation, and a simpler workflow.**
