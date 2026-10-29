# LAN Messenger - local Windows crash diagnostics (does not upload data).
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\tool\windows_crash_report.ps1
#   powershell -ExecutionPolicy Bypass -File .\tool\windows_crash_report.ps1 -LookbackMinutes 1440
#   powershell -ExecutionPolicy Bypass -File .\tool\windows_crash_report.ps1 -SelfTest
#
# Reads Windows Application Error (1000) and Windows Error Reporting (1001)
# for lan_messenger.exe. Exports ONLY fault module/code/offset/timestamps.
# Never exports raw event messages, file paths, device identifiers, call
# content or crash dumps. Neither modifies registry nor sends telemetry.
[CmdletBinding()]
param(
    [ValidateRange(1,10080)][int]$LookbackMinutes = 1440,
    [string]$OutputFile = "",
    [switch]$SelfTest
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-EventField([string]$Message, [string]$Label) {
    $pattern = "(?im)^\s*" + [regex]::Escape($Label) + "\s*:\s*(.*?)\s*$"
    $match = [regex]::Match($Message, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return $null
}

function Get-PropertyOrNull($Event, [int]$Index) {
    if ($Event.Properties -and $Event.Properties.Count -gt $Index) {
        return [string]$Event.Properties[$Index].Value
    }
    return $null
}

# Windows Error Reporting signatures APPCRASH/BEX have P1=app, P4=module,
# P7=exception and P8=offset. Unrelated WER signatures have different P-fields.
function Get-WerAppCrashFields([string]$Message) {
    $kind = Get-EventField $Message "Event Name"
    if ($kind -notin @("APPCRASH", "BEX", "BEX64")) { return $null }
    if ((Get-EventField $Message "P1") -ine "lan_messenger.exe") { return $null }
    return [pscustomobject]@{
        Module = (Get-EventField $Message "P4")
        Code = (Get-EventField $Message "P7")
        Offset = (Get-EventField $Message "P8")
    }
}

# Never disclose username or disk paths from a Windows crash event.
function Get-SafeModuleName([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $base = ($Value.Trim() -split '[\\/]')[-1]
    if ($base -notmatch '^(?i:[a-z0-9_.-]{1,155}\.)(?i:dll|exe|sys)$') {
        return $null
    }
    return $base
}
function Get-SafeHex([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $hex = $Value.Trim()
    if ($hex -notmatch '^(?i:0x)?[0-9a-fA-F]{1,16}$') { return $null }
    return $hex
}

if ($SelfTest) {
    $sample = "Faulting application name: lan_messenger.exe`r`nFaulting module name: flutter_webrtc_plugin.dll`r`nException code: 0xc0000005`r`nFault offset: 0x1234"
    if ((Get-EventField $sample "Faulting module name") -ne "flutter_webrtc_plugin.dll" -or
        (Get-EventField $sample "Exception code") -ne "0xc0000005" -or
        (Get-EventField $sample "Fault offset") -ne "0x1234") {
        throw "Crash-report field parser failed synthetic contract"
    }
    $werMessage = "Event Name: APPCRASH" + [Environment]::NewLine +
        "P1: lan_messenger.exe" + [Environment]::NewLine +
        "P4: C:\Users\private\flutter_webrtc_plugin.dll" + [Environment]::NewLine +
        "P7: c0000005" + [Environment]::NewLine + "P8: 0000000000001234"
    $wer = Get-WerAppCrashFields $werMessage
    if ($null -eq $wer -or
        (Get-SafeModuleName $wer.Module) -ne "flutter_webrtc_plugin.dll" -or
        (Get-SafeHex $wer.Code) -ne "c0000005" -or
        (Get-SafeHex $wer.Offset) -ne "0000000000001234") {
        throw "WER 1001 APPCRASH parser regression"
    }
    if ($null -ne (Get-WerAppCrashFields ($werMessage.Replace("lan_messenger.exe", "other.exe"))) -or
        $null -ne (Get-WerAppCrashFields ($werMessage.Replace("APPCRASH", "OTHER"))) -or
        $null -ne (Get-SafeModuleName "C:\Users\private\notes.txt") -or
        $null -ne (Get-SafeHex "0xc0000005 extra")) {
        throw "WER app identity and privacy checks regression"
    }
    Write-Output "PASS: local Windows 1000 and WER 1001 crash-report parsers"
    exit 0
}

if ([string]::IsNullOrWhiteSpace($OutputFile)) {
    $OutputFile = Join-Path ([System.IO.Path]::GetTempPath()) "LAN-Messenger-Windows-Crash-Report.json"
}
$since = (Get-Date).AddMinutes(-$LookbackMinutes)
$events = @()
$readError = $null
try {
    $events = @(Get-WinEvent -FilterHashtable @{
        LogName = "Application"
        Id = @(1000,1001)
        StartTime = $since
    } -ErrorAction Stop)
} catch {
    $readError = $_.Exception.GetType().Name
    Write-Warning "Application Event Log unavailable or contains no matching entries. Report will explain the limitation."
}

$results = @(
    foreach ($event in $events) {
        $message = [string]$event.Message
        $appProperty = if ($event.Id -eq 1000) { Get-PropertyOrNull $event 0 } else { $null }
        if ($message -notmatch "(?i)\blan_messenger\.exe\b" -and
            $appProperty -notmatch "(?i)^lan_messenger\.exe$") { continue }

        $module = Get-EventField $message "Faulting module name"
        $code = Get-EventField $message "Exception code"
        $offset = Get-EventField $message "Fault offset"
        # Application Error 1000 has language-neutral event properties.
        if ($event.Id -eq 1000) {
            if ([string]::IsNullOrWhiteSpace($module)) { $module = Get-PropertyOrNull $event 3 }
            if ([string]::IsNullOrWhiteSpace($code)) { $code = Get-PropertyOrNull $event 6 }
            if ([string]::IsNullOrWhiteSpace($offset)) { $offset = Get-PropertyOrNull $event 7 }
        } elseif ($event.Id -eq 1001) {
            $wer = Get-WerAppCrashFields $message
            if ($null -eq $wer) { continue }
            $module = $wer.Module
            $code = $wer.Code
            $offset = $wer.Offset
        } else {
            continue
        }
        [pscustomobject]@{
            AtUtc = $event.TimeCreated.ToUniversalTime().ToString("o")
            EventId = $event.Id
            Provider = $event.ProviderName
            FaultingModule = (Get-SafeModuleName $module)
            ExceptionCode = (Get-SafeHex $code)
            FaultOffset = (Get-SafeHex $offset)
        }
    }
)
$results = @($results | Sort-Object AtUtc -Descending | Select-Object -First 20)
$report = [pscustomobject]@{
    Application = "lan_messenger.exe"
    GeneratedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    LookbackMinutes = $LookbackMinutes
    MatchedEvents = $results.Count
    EventLogReadErrorType = $readError
    Crashes = $results
    ContainsRawEventMessagesOrDumps = $false
}
$parent = Split-Path -Parent $OutputFile
if ($parent -and !(Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputFile -Encoding UTF8
Write-Output ("Crash report: " + $OutputFile)
Write-Output ("Matched LAN Messenger crash events: " + $results.Count)
if ($results.Count -eq 0) {
    Write-Output "No matching Application Error/WER event in this window. Check Reliability Monitor (perfmon /rel)."
} else {
    $results | Format-Table AtUtc,EventId,FaultingModule,ExceptionCode,FaultOffset -AutoSize | Out-String | Write-Output
}
