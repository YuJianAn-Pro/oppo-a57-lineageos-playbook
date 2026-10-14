<#
.SYNOPSIS
  Verifies a flashed partition by hashing it on-device and comparing against
  the expected image hash.

.DESCRIPTION
  A flasher reporting "Success" is not verification. This script reads the
  on-device partition (via adb shell su) and compares its SHA-256 against a
  locally computed value, so offset errors and short writes are caught
  before reboot.

  Compare modes:
    - Full    : hash the whole block device (best for zero-padded writes)
    - Prefix  : hash only the first <ImageSize> bytes (for non-padded images)

.EXAMPLE
  ./Compare-PartitionHash.ps1 -Partition /dev/block/by-name/boot -Image .\magisk_padded_boot.img -Mode Full

.EXAMPLE
  ./Compare-PartitionHash.ps1 -Partition /dev/block/by-name/recovery -Image .\twrp.img -Mode Prefix
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Partition,

    [Parameter(Mandatory = $true)]
    [string]$Image,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Full', 'Prefix')]
    [string]$Mode,

    [string]$AdbPath = 'adb',
    [string]$Serial
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Image)) { throw "Image not found: $Image" }

$adbArgs = @()
if ($Serial) { $adbArgs += @('-s', $Serial) }

function Get-LocalPrefixHash {
    param([string]$FilePath, [int64]$Length)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fs = [System.IO.File]::OpenRead($FilePath)
    try {
        $buffer = New-Object byte[] (1MB)
        $remaining = $Length
        while ($remaining -gt 0) {
            $want = [Math]::Min($buffer.Length, $remaining)
            $read = $fs.Read($buffer, 0, $want)
            if ($read -le 0) { throw "Unexpected EOF reading $FilePath" }
            $sha.TransformBlock($buffer, 0, $read, $buffer, 0) | Out-Null
            $remaining -= $read
        }
        $sha.TransformFinalBlock(@(), 0, 0) | Out-Null
        return ($sha.Hash | ForEach-Object { $_.ToString('x2') }) -join ''
    }
    finally { $fs.Dispose(); $sha.Dispose() }
}

if ($Mode -eq 'Full') {
    $localHash = (Get-FileHash -LiteralPath $Image -Algorithm SHA256).Hash.ToLower()
    # Reads the whole block device; requires root on the device side.
    $remoteHash = (& $AdbPath @adbArgs shell "su -c 'sha256sum $Partition'").Trim().Split()[0].ToLower()
}
else {
    $localHash = Get-LocalPrefixHash -FilePath $Image -Length (Get-Item -LiteralPath $Image).Length
    $size = (Get-Item -LiteralPath $Image).Length
    $remoteHash = (& $AdbPath @adbArgs shell "su -c 'dd if=$Partition bs=$size count=1 2>/dev/null | sha256sum'").Trim().Split()[0].ToLower()
}

$result = [ordered]@{
    Partition      = $Partition
    Mode           = $Mode
    ImageBytes     = (Get-Item -LiteralPath $Image).Length
    LocalSHA256    = $localHash
    DeviceSHA256   = $remoteHash
    Match          = ($localHash -eq $remoteHash)
    CheckedAtUtc   = (Get-Date).ToUniversalTime().ToString('o')
}
$result | ConvertTo-Json

if (-not $result.Match) {
    Write-Error "HASH MISMATCH on $Partition - do NOT reboot. Restore the partition from your verified backup in the same session."
    exit 1
}
Write-Output "Verified: $Partition matches $Image"
