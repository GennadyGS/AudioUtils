#Requires -Version 5.1
<#
.SYNOPSIS
Removes the embedded Title tag from an MP3 without renaming it.
.DESCRIPTION
Uses TagLibSharp to clear Title while retaining other metadata and audio.
Creates a .bak copy before saving unless -SkipBackup is supplied; an existing
backup is never overwritten. Supports -WhatIf and -Confirm.

Requires TagLibSharp.dll alongside this script, or a custom DLL location
supplied with -TagLibPath.
.EXAMPLE
.\Remove-Mp3Title.ps1 -Path 'C:\Music\song.mp3' -WhatIf
.EXAMPLE
.\Remove-Mp3Title.ps1 -Path 'C:\Music\song.mp3' -SkipBackup
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string] $Path,

    [switch] $SkipBackup,

    [string] $TagLibPath = (Join-Path $PSScriptRoot 'TagLibSharp.dll')
)

$ErrorActionPreference = 'Stop'

$mp3 = Get-Item -LiteralPath $Path
if ($mp3.PSIsContainer -or $mp3.Extension -ine '.mp3') {
    throw "Path must refer to an existing MP3 file: $Path"
}

if (-not (Test-Path -LiteralPath $TagLibPath -PathType Leaf)) {
    throw "TagLibSharp.dll was not found at '$TagLibPath'. Supply its location with -TagLibPath."
}
Add-Type -Path (Resolve-Path -LiteralPath $TagLibPath).ProviderPath

$audio = [TagLib.File]::Create($mp3.FullName)
try {
    if ([string]::IsNullOrEmpty($audio.Tag.Title)) {
        Write-Verbose "No Title tag to remove: $($mp3.FullName)"
        return
    }

    $action = 'Back up the file and remove its Title tag'
    if ($SkipBackup) { $action = 'Remove the Title tag without a backup' }
    if ($PSCmdlet.ShouldProcess($mp3.FullName, $action)) {
        $backupPath = $null
        if (-not $SkipBackup) {
            $backupPath = $mp3.FullName + '.bak'
            [System.IO.File]::Copy($mp3.FullName, $backupPath, $false)
        }
        $audio.Tag.Title = $null
        $audio.Save()

        [pscustomobject]@{
            Path = $mp3.FullName
            BackupPath = $backupPath
            TitleRemoved = $true
        }
    }
}
finally {
    $audio.Dispose()
}
