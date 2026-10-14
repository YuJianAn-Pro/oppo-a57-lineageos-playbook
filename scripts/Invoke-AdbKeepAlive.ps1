<#
.SYNOPSIS
  Keeps an authorized ADB session warm so USB debugging does not time out
  during long flashing operations.

.DESCRIPTION
  Periodically runs a harmless `adb shell echo` against every connected,
  authorized device. Logs state transitions (connected / unauthorized /
  offline / waiting) to a log file next to the script.

  Requires adb on PATH, or pass -AdbPath. Stop with Ctrl+C.

.EXAMPLE
  ./Invoke-AdbKeepAlive.ps1
  ./Invoke-AdbKeepAlive.ps1 -AdbPath C:\platform-tools\adb.exe -IntervalSeconds 20
#>
param(
    [ValidateRange(5, 300)]
    [int]$IntervalSeconds = 20,

    [string]$AdbPath = 'adb'
)

$ErrorActionPreference = 'Continue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logPath = Join-Path $scriptDir 'adb-keepalive.log'
$pidPath = Join-Path $scriptDir 'adb-keepalive.pid'

$createdNew = $false
$mutex = [Threading.Mutex]::new($true, 'Global\AdbUsbKeepAlive', [ref]$createdNew)
if (-not $createdNew) {
    Write-Output 'Another keepalive instance is already running; exiting.'
    exit 2
}

function Write-KeepAliveLog {
    param([string]$Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding utf8
    Write-Output $line
}

try {
    Set-Content -LiteralPath $pidPath -Value $PID -Encoding ascii
    Write-KeepAliveLog "[start] PID=$PID interval=${IntervalSeconds}s adb=$AdbPath"
    & $AdbPath start-server 2>&1 | Out-Null

    $lastState = ''
    $lastHeartbeat = [datetime]::MinValue

    while ($true) {
        $raw = @(& $AdbPath devices 2>&1)
        $entries = @()
        foreach ($line in $raw) {
            $text = [string]$line
            if ($text -match '^([^\s]+)\s+(device|unauthorized|offline)\s*$') {
                $entries += [pscustomobject]@{ Serial = $Matches[1]; State = $Matches[2] }
            }
        }

        $ready = @($entries | Where-Object State -eq 'device')
        $unauthorized = @($entries | Where-Object State -eq 'unauthorized')
        $offline = @($entries | Where-Object State -eq 'offline')

        if ($ready.Count -gt 0) {
            $state = 'device:' + (($ready.Serial | Sort-Object) -join ',')
            foreach ($entry in $ready) {
                # Harmless no-op; proves the link is alive and resets idle timers.
                & $AdbPath -s $entry.Serial shell 'echo __adb_keepalive__' 2>&1 | Out-Null
            }
            if ($state -ne $lastState) {
                Write-KeepAliveLog "[connected] authorized: $($ready.Serial -join ', ')"
                $lastState = $state
            }
            if (((Get-Date) - $lastHeartbeat).TotalMinutes -ge 5) {
                Write-KeepAliveLog "[heartbeat] ok: $($ready.Serial -join ', ')"
                $lastHeartbeat = Get-Date
            }
        }
        elseif ($unauthorized.Count -gt 0) {
            $state = 'unauthorized:' + (($unauthorized.Serial | Sort-Object) -join ',')
            if ($state -ne $lastState) {
                Write-KeepAliveLog "[action] device unauthorized - tick 'always allow' on the phone"
                $lastState = $state
            }
        }
        elseif ($offline.Count -gt 0) {
            $state = 'offline:' + (($offline.Serial | Sort-Object) -join ',')
            if ($state -ne $lastState) {
                Write-KeepAliveLog '[warning] device offline'
                $lastState = $state
            }
        }
        else {
            if ($lastState -ne 'waiting') {
                Write-KeepAliveLog '[waiting] no device with USB debugging connected'
                $lastState = 'waiting'
            }
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
}
finally {
    Write-KeepAliveLog '[stop] keepalive stopped.'
    Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
    if ($mutex) {
        try { $mutex.ReleaseMutex() } catch {}
        $mutex.Dispose()
    }
}
