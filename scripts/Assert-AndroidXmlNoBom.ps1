<#
.SYNOPSIS
  Fails if an XML file has a UTF-8 BOM or does not start with '<'.

.DESCRIPTION
  Android's SystemConfig parser reads permission/sysconfig XML via
  FileReader and does NOT skip a UTF-8 BOM. A BOM in
  privapp-permissions-*.xml silently empties the allowlist and can
  crash-loop system_server ("privileged permissions not in allowlist").

  Run this against every XML you ship in a Magisk module before flashing.

.EXAMPLE
  ./Assert-AndroidXmlNoBom.ps1 .\module\system\etc\permissions\privapp-permissions-my-module.xml

.EXAMPLE
  Get-ChildItem .\module -Recurse -Filter *.xml | ForEach-Object {
      ./Assert-AndroidXmlNoBom.ps1 $_.FullName
  }
#>
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [string]$Path
)

process {
    $ErrorActionPreference = 'Stop'
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 4) { throw "${Path}: file too small to be XML" }

    if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        throw "${Path}: UTF-8 BOM detected - Android SystemConfig will reject this file"
    }
    if ($bytes[0] -ne 0x3C) {
        throw "${Path}: first byte is not '<' (found 0x$($bytes[0].ToString('X2')))"
    }

    # Parse too; a BOM-free but malformed file is still a boot-loop.
    [xml](Get-Content -LiteralPath $Path -Raw -Encoding utf8) | Out-Null
    Write-Output "${Path}: OK (no BOM, parses as XML)"
}
