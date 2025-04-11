<#
 .SYNOPSIS
  Get the last result of the VBR Job.

 .DESCRIPTION
  Get the last result of specified VBR Job. The job status can be grasped 
  via log file and/or exit code of the script.
  Version: 0.7.0
  
  Exit codes:
       0: Job finished with Success status.
       1: Job finished with Failed status.
       2: Job finished with Warning.
       4: The job has never been run yet ("None" status).
       8: Unknown.
       *: Other errors. ie: non-existent JobName, syntax errors, etc.

 .PARAMETER JobName
  (Alias -j) Mandatory. The definition name of Job.

 .PARAMETER Log
  (Alias -l) Append logs to this file. This overrides $Set_Log parameter in 
  the script itself. If it doesn't contain '\', it is assumed in the script 
  dir. No logging is done if neither Log nor Set_Log are set.

 .PARAMETER NoLog
  Disable logging even if $Sset_Log parameter is set or Log option is passed.

 .PARAMETER Quiet
  (Alias -q) Suppress console output. Result can be grasped through exit 
  code or log file.
#>
[CmdletBinding()]
Param(
  [Parameter(Position=0)]
  [Alias("j")]
  [string]$JobName,

  [Parameter()]
  [Alias("l")]
  [string]$Log,

  [Parameter()]
  [switch]$NoLog,

  [Parameter()]
  [Alias("q")]
  [switch]$Quiet
)

# File to append logs to. Comment it out or keep null if no logging is required at all.
$Set_Log = 'jobstatus.log'

$scriptdir = Split-Path -Path $myInvocation.MyCommand.Path -Parent

import-module Veeam.Backup.PowerShell -warningaction silentlycontinue

if ($JobName.length -eq 0) {
    Get-Help $myInvocation.MyCommand.Path
    Exit 254
}

if ($Log) {
    $logname = $Log
} elseif ($Set_Log) {
    $logname = $Set_Log
}

if ($logname -and !$NoLog) {
    if ($logname.contains('\')) {
        $logfile = $logname
    } else {
        $logfile = $scriptdir + '\' + $logname
    }

    $logdir = Split-Path -Path $logfile -Parent

    if (Test-Path $logdir) {
        $logging = $True
    } else {
        Write-Warning "Log directory $logdir does not exist, logging is disabled"
    }
}

Function WriteMsg {
    param (
        [Parameter(Position=0)]
        [string]$Msg
    )

    if (!$Quiet) {
        Write-Host "$Msg"
    }

    if ($logging) {
        '{0}	[{1}] {2}' -f $(Get-Date -Format "yyyy/MM/dd HH:mm:ss"), $JobName, $Msg | Out-File -FilePath $logfile -Encoding Default -Append
    }
}

$job = Get-VBRJob -Name $JobName
if (!$job) {
    WriteMsg "No such Job by that name or unable to talk to VBR Server"
    Exit 254
}


$job = Get-VBRJob -Name $JobName
if ($job) { $LastSession = $job.FindLastSession() }

if ($LastSession) {
    $SessionStart  = if ((Get-Date $LastSession.CreationTime) -gt (Get-Date 1970-01-01)) { Get-Date $LastSession.CreationTime -Format "yyyy/MM/dd-HH:mm:ss" } else { $null }
    $SessionResult = if ($SessionStart) { $LastSession.Result } else { $null }
    $SessionEnd    = if ((Get-Date $LastSession.EndTime) -gt (Get-Date 1970-01-01)) { Get-Date $LastSession.EndTime -Format "yyyy/MM/dd-HH:mm:ss" } else { $null }
    $SessionMode   = if ($LastSession.IsFullMode) { "Full" } else { "NotFull" }

    if ($SessionStart -and $SessionEnd) {
        $startTime = [datetime]::ParseExact($SessionStart, "yyyy/MM/dd-HH:mm:ss", $null)
        $endTime = [datetime]::ParseExact($SessionEnd, "yyyy/MM/dd-HH:mm:ss", $null)
        $duration = $endTime - $startTime
        $formattedDuration = $duration.ToString("hh\:mm\:ss")
    } else {
        $formattedDuration = $null
    }
} else {
    WriteMsg "No Session record available"
}

$retval = 8
Switch ($SessionResult) {
  'Success' { $retval = 0 }
  'Failed'  { $retval = 1 }
  'Warning' { $retval = 2 }
  'None'    { $retval = 4 }
}

WriteMsg "Result:$SessionResult Code:$retval SessionStart:$SessionStart SessionEnd:$SessionEnd Duration:$formattedDuration Mode:$SessionMode"

Exit $retval
