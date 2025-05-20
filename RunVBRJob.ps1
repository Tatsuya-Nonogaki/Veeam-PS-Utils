<#
 .SYNOPSIS
  Runs the specified VBR Job and returns its result.

 .DESCRIPTION
  Runs the specified VBR Job. The job status can be obtained via log file 
  and/or exit code of the script.
  Version: 0.5.3

  Exit codes:
       0: Job finished with Success status.
       1: Job finished with Failed status.
       2: Job finished with Warning.
       4: No job record is available or pending ("None" status).
       8: Unknown.
       *: Other errors. ie: non-existent JobName, syntax errors, etc.

 .PARAMETER JobName
  (Alias -j) Mandatory. The definition name of Job.

 .PARAMETER Config
  (Alias -c) Read global configurations from this alternative file. If it 
  doesn't contain '\', it is assumed to be in the script dir. Defaults to 
  settings.ps1 in the same directory as this script.

 .PARAMETER VBRJobOpt
  (Alias -o) You can pass cmdlet options to Start-VBRJob through this, 
  enclosing them with quotes, e.g., -VBRJobOpt "-FullBackup -RetryBackup"

 .PARAMETER Log
  (Alias -l) Append logs to this file. This overrides $Set_Log parameter in 
  config file. If it doesn't contain '\', it is assumed in the script dir. 
  No logging is done if neither Log nor Set_Log are set.

 .PARAMETER NoLog
  Disable logging, even if a log file is specified.

 .PARAMETER NoExec
  (Alias -n) Do not execute Job but only return the result of last session.

 .PARAMETER Quiet
  (Alias -q) Suppress console output. Result can still be grasped through 
  log file and/or exit code.
#>
[CmdletBinding()]
Param(
  [Parameter(Position=0)]
  [Alias("j")]
  [string]$JobName,

  [Parameter()]
  [Alias("c")]
  [string]$Config,

  [Parameter()]
  [Alias("o")]
  [string]$VBRJobOpt,

  [Parameter()]
  [Alias("l")]
  [string]$Log,

  [Parameter()]
  [switch]$NoLog,

  [Parameter()]
  [Alias("n")]
  [switch]$NoExec,

  [Parameter()]
  [Alias("q")]
  [switch]$Quiet
)

$scriptdir = Split-Path -Path $myInvocation.MyCommand.Path -Parent

import-module Veeam.Backup.PowerShell -warningaction silentlycontinue -ErrorAction Stop

# Read config file in.
if ($Config) {
    if ($Config.contains('\')) {
        $conffile = $Config
    } else {
        $conffile = $scriptdir + '\' + $Config
    }
} else {
    $conffile = $scriptdir + "\settings.ps1"
}

if (Test-Path $conffile) {
    . $conffile
} else {
    Write-Error "No such Config file `"$conffile`""
    Exit 254
}

if ($Jobname.length -eq 0) {
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
        '{0}	[{1}] {2}' -f $(Get-Date -Format "yyyy/MM/dd HH:mm:ss"), $JobName, $Msg | Out-File -FilePath $logfile -Encoding UTF8 -Append
    }
}

$jobPropertySet = @{}
if ($VBRJobOpt) {
    $options = $VBRJobOpt -split '\s(?=--|\-)'

    foreach ($option in $options) {
        # If the option contains an '=', treat it as a key-value pair
        if ($option -match '--?(?<Key>[^\s=]+)=(?<Value>.+)') {
            $jobPropertySet[$matches['Key']] = $matches['Value']
        }
        # If the option contains a space (e.g., "-key value"), treat it as a key-value pair
        elseif ($option -match '--?(?<Key>[^\s]+)\s+(?<Value>.+)') {
            $jobPropertySet[$matches['Key']] = $matches['Value']
        }
        # Otherwise, treat it as a simple switch
        elseif ($option -match '--?(?<Key>[^\s]+)') {
            $jobPropertySet[$matches['Key']] = $true
        }
    }
}

$job = Get-VBRJob -Name $JobName
if (!$job) {
    WriteMsg "No such Job by that name or unable to talk to VBR Server"
    Exit 254
}

if (!$NoExec) {
    WriteMsg "Job $JobName started with options '${VBRJobOpt}'"
    if ($Quiet) {
        try {
            Start-VBRJob -Job $job @jobPropertySet -ErrorAction Stop *> $null
        } catch {
            WriteMsg "Failed to start job $JobName Error: $_"
            exit 254
        }
    } else {
        try {
            Start-VBRJob -Job $job @jobPropertySet -ErrorAction Stop
        } catch {
            WriteMsg "Failed to start job $JobName Error: $_"
            Write-Error "Failed to start job $JobName Error: $_"
            exit 254
        }
    }
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
