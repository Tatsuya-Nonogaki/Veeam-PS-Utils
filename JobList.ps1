<#
 .SYNOPSIS
  Output Job List.

 .DESCRIPTION
  Output Job List to a CSV file.
  Version: 0.4.1beta-surebackup04

  The output CSV consists of the following fields.
  Fields may vary depending on the job 'Type' argument.

  *Name
    Job Name.

  *JobType
    Backup, Replica, SureBackup, etc.

  *Description
    Description field of the job.

  *Sources
    Source objects for backup or replication.
    For SureBackup, this field is replaced by LinkedJob (see below).

  *LinkedJob (SureBackup only)
    Linked job(s) for the SureBackup job.

  *TargetRepository, TargetDatastore, etc.
    Various properties depending on the job 'Type' argument.

  *RestorePoints
    Number of restore points to keep.

  *IsScheduleEnabled
    'FALSE' indicates the job will not run automatically because it is disabled in the Jobs list pane.

  *RunAutomatically
    'FALSE' indicates the job will not run automatically because the "Run the job automatically" 
    checkbox is unchecked on the Schedule page of the job configuration.

  *DailyStartTime
    Configured start time in the "Daily at this time" field on the Schedule page of the job 
    configuration. Hidden values (i.e., grayed out in the GUI) will not be shown when the "Daily" 
    selector is not checked.

  *MonthlyStartTime
    Configured time in the "Monthly at this time" fields on the Schedule page, in the form, 
    e.g., '22:00 on Fourth Saturday in January;February;...'. Hidden values (i.e., grayed out in 
    the GUI) will not be shown when the "Monthly" selector is not checked.

  *Periodically (not applicable for SureBackup)
    Interval configured in the "Periodically every" field of the Schedule. Hidden values (i.e., 
    grayed out in the GUI) will not be shown when the "Periodically" selector is not checked.

  *HourlyOffset (not applicable for SureBackup)
    Time offset configured in the "Start time within an hour" field of the Periodic Schedule.

  *AfterJob
    Job configured in the "After the job" field of the Schedule. Hidden values (i.e., grayed out 
    in the GUI) will not be shown when the "After the job" selector is not checked.

  *IsRunning
    Indicates whether the job was running at the moment the list was acquired.

  *LastResult
    Result of the last job session.

  *SessionStart and SessionEnd
    Start and end times of the last job session.

  *Duration
    Duration of the last job, calculated from SessionStart and SessionEnd.

 .PARAMETER Type
  (Alias -t) Mandatory. Job type. Must be either 'backup', 'replica', or 'surebackup'.

 .PARAMETER Log
  (Alias -l) Output file path. If it doesn't contain '\', it is assumed in the script dir.
  Defaults to 'scriptdir\joblist-{Type}.csv'.

 .PARAMETER Stat
  (Alias -s) Let the output include status related columns, i.e., IsRunning, LastResult, 
  SessionStart, SessionEnd and Duration. 
#>
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [ValidateSet("backup", "replica", "surebackup")]
  [Alias("t")]
  [string]$Type,

  [Parameter()]
  [Alias("l")]
  [string]$Log,

  [Parameter()]
  [Alias("s")]
  [switch]$Stat
)

# Output file name, where the placeholder '%' is replaced by Type parameter.
$LogBaseName = 'joblist-%.csv'

$scriptdir = Split-Path -Path $myInvocation.MyCommand.Path -Parent

import-module Veeam.Backup.PowerShell -warningaction silentlycontinue -ErrorAction Stop

if ($Log) {
    $logname = $Log
} elseif ($LogBaseName) {
    $logname = $LogBaseName -replace '%', $Type.ToLower()
}

if ($logname) {
    if ($logname.contains('\')) {
        $logfile = $logname
    } else {
        $logfile = $scriptdir + '\' + $logname
    }

    $logdir = Split-Path -Path $logfile -Parent

    if (!(Test-Path $logdir)) {
        Write-Error "Log directory $logdir does not exist"
        exit 1
    }
}

function Get-JobData {
    param(
        [Parameter()]
        [Object]$job,
        [Parameter()]
        [string]$Type
    )

    $LastSession = $job.FindLastSession()

    $SessionStart = $SessionEnd = $SessionResult = $formattedDuration = $null
    if ($LastSession) {
        $SessionStart  = if ((Get-Date $LastSession.CreationTime) -gt (Get-Date 1970-01-01)) { Get-Date $LastSession.CreationTime -Format "yyyy/MM/dd HH:mm:ss" }
        $SessionResult = if ($SessionStart) { $LastSession.Result }
        $SessionEnd    = if ((Get-Date $LastSession.EndTime) -gt (Get-Date 1970-01-01)) { Get-Date $LastSession.EndTime -Format "yyyy/MM/dd HH:mm:ss" }

        if ($SessionStart -and $SessionEnd) {
            $startTime = [datetime]::ParseExact($SessionStart, "yyyy/MM/dd HH:mm:ss", $null)
            $endTime = [datetime]::ParseExact($SessionEnd, "yyyy/MM/dd HH:mm:ss", $null)
            $duration = $endTime - $startTime
            $formattedDuration = $duration.ToString("hh\:mm\:ss")
        }
    }

    $commonProps = @{
        Name = $job.Name
        JobType = $job.JobType
        Description = $job.Description
        Sources = $job.GetObjectsInJob().Name -join ";"
        RestorePoints = if ($job.BackupStorageOptions.RetentionType -eq "Cycles") { $job.BackupStorageOptions.RetainCycles, "points" -join " " } else { $job.BackupStorageOptions.RetainCycles, "days" -join " " }
        IsScheduleEnabled = $job.IsScheduleEnabled
        RunAutomatically = -not $job.Options.JobOptions.RunManually
        IsRunning = $job.IsRunning
        DailyStartTime = ""
        MonthlyStartTime = ""
        Periodically = ""
        HourlyOffset = ""
    }

    if ($job.ScheduleOptions.OptionsDaily.Enabled -eq "True") {
        $commonProps.DailyStartTime = $job.ScheduleOptions.OptionsDaily.TimeLocal | Get-Date -Format t
    }

    if ($job.ScheduleOptions.OptionsMonthly.Enabled -eq "True") {
        $mo = $job.ScheduleOptions.OptionsMonthly
        $time = $mo.TimeLocal | Get-Date -Format 't'
        $week = $mo.DayNumberInMonth
        $day = $mo.DayOfWeek
        $months = $mo.Months -join ';'
        $commonProps.MonthlyStartTime = "{0} on {1} {2} in {3}" -f $time, $week, $day, $months
    }

    if ($job.ScheduleOptions.OptionsPeriodically.Enabled -eq "True") {
        $periodSec = $job.ScheduleOptions.OptionsPeriodically.FullPeriod
        $commonProps.Periodically = "{0} min(s)" -f [int]($periodSec / 60)
        $commonProps.HourlyOffset = "{0} min(s)" -f ([int]$job.ScheduleOptions.OptionsPeriodically.HourlyOffset)
    }

    $specificProps = @{
        TargetRepository = if ($Type -eq "backup") { $job.GetTargetRepository().Name } else { $null }
        TargetCluster = if ($Type -eq "replica") { $job.ViReplicaTargetOptions.ClusterName } else { $null }
        TargetFolder = if ($Type -eq "replica") { $job.ViReplicaTargetOptions.ReplicaTargetVmFolderName } else { $null }
        TargetDatastore = if ($Type -eq "replica") { $job.ViReplicaTargetOptions.DatastoreName } else { $null }
    }

    if ($Type -eq "backup") {
        $orderedProps = [PSCustomObject]@{
            Name = $commonProps.Name
            JobType = $commonProps.JobType
            Description = $commonProps.Description
            Sources = $commonProps.Sources
            TargetRepository = $specificProps.TargetRepository
            RestorePoints = $commonProps.RestorePoints
            IsScheduleEnabled = $commonProps.IsScheduleEnabled
            RunAutomatically = $commonProps.RunAutomatically
            DailyStartTime = $commonProps.DailyStartTime
            MonthlyStartTime = $commonProps.MonthlyStartTime
            Periodically = $commonProps.Periodically
            HourlyOffset = $commonProps.HourlyOffset
        }
    } elseif ($Type -eq "replica") {
        $orderedProps = [PSCustomObject]@{
            Name = $commonProps.Name
            JobType = $commonProps.JobType
            Description = $commonProps.Description
            Sources = $commonProps.Sources
            TargetCluster = $specificProps.TargetCluster
            TargetFolder = $specificProps.TargetFolder
            TargetDatastore = $specificProps.TargetDatastore
            RestorePoints = $commonProps.RestorePoints
            IsScheduleEnabled = $commonProps.IsScheduleEnabled
            RunAutomatically = $commonProps.RunAutomatically
            DailyStartTime = $commonProps.DailyStartTime
            MonthlyStartTime = $commonProps.MonthlyStartTime
            Periodically = $commonProps.Periodically
            HourlyOffset = $commonProps.HourlyOffset
        }
    }

    if ($Stat) {
        $orderedProps | Add-Member -MemberType NoteProperty -Name "IsRunning" -Value $commonProps.IsRunning
        $orderedProps | Add-Member -MemberType NoteProperty -Name "LastResult" -Value $SessionResult
        $orderedProps | Add-Member -MemberType NoteProperty -Name "SessionStart" -Value $SessionStart
        $orderedProps | Add-Member -MemberType NoteProperty -Name "SessionEnd" -Value $SessionEnd
        $orderedProps | Add-Member -MemberType NoteProperty -Name "Duration" -Value $formattedDuration
    }

    return $orderedProps
}

function Get-SureBackupJobData {
    param(
        [Parameter()]
        [Object]$job,
        [switch]$Stat
    )

    $LinkedJob = $null
    if ($job.LinkedJob -and $job.LinkedJob.Job) {
        $LinkedJob = $job.LinkedJob.Job.Name -join ";"
    }

    $DailyStartTime = ""
    $MonthlyStartTime = ""
    $AfterJob = ""

    $scheduleType = $job.ScheduleOptions.Type

    if ($scheduleType -eq "Daily") {
        $period = $job.ScheduleOptions.DailyOptions.Period
        if ($period) {
            $DailyStartTime = (Get-Date -Hour $period.Hours -Minute $period.Minutes -Second 0).ToString('t')
        }
    }

    if ($scheduleType -eq "Monthly") {
        $mo = $job.ScheduleOptions.MonthlyOptions
        if ($mo) {
            $time = [datetime]::ParseExact($mo.Period, "HH:mm:ss", $null) | Get-Date -Format 't'
            $week = $mo.DayNumberInMonth
            $day = $mo.DayOfWeek
            $months = $mo.Months -join ';'
            $MonthlyStartTime = "{0} on {1} {2} in {3}" -f $time, $week, $day, $months
        }
    }

    if ($scheduleType -eq "AfterJob") {
        $afterJobId = $job.ScheduleOptions.AfterJobId
        if ($afterJobId) {
            $afterJobObj = Get-VBRJob | Where-Object { $_.Id -eq $afterJobId }
            if ($afterJobObj) {
                $AfterJob = $afterJobObj.Name
            }
        }
    }

    $props = [PSCustomObject]@{
        Name = $job.Name
        JobType = "SureBackup"
        Description = $job.Description
        LinkedJob = $LinkedJob
        IsScheduleEnabled = $job.IsEnabled
        RunAutomatically = $job.ScheduleEnabled
        DailyStartTime = $DailyStartTime
        MonthlyStartTime = $MonthlyStartTime
        AfterJob = $AfterJob
    }

    if ($Stat) {
        $SessionStart = $SessionEnd = $LastResult = $formattedDuration = $null
        $IsRunning = $null
        try {
            $sessions = Get-VBRSureBackupSession -Name $job.Name -ErrorAction Stop
            if ($sessions) {
                $lastSession = $sessions | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
                if ($lastSession) {
                    $SessionStart  = if ($lastSession.CreationTime) { Get-Date $lastSession.CreationTime -Format "yyyy/MM/dd HH:mm:ss" }
                    $SessionEnd = if ((Get-Date $lastSession.EndTime) -gt (Get-Date "1970-01-01")) { Get-Date $lastSession.EndTime -Format "yyyy/MM/dd HH:mm:ss" }
                    $LastResult = $lastSession.Result
                    $IsRunning = ($lastSession.State -eq "Working")
                    $formattedDuration = if ($SessionStart -and $SessionEnd) {
                        $startTime = [datetime]::ParseExact($SessionStart, "yyyy/MM/dd HH:mm:ss", $null)
                        $endTime = [datetime]::ParseExact($SessionEnd, "yyyy/MM/dd HH:mm:ss", $null)
                        ($endTime - $startTime).ToString("hh\:mm\:ss")
                    }
                }
            }
        } catch {
            # No sessions found or job never run, leave as $null
        }
        $props | Add-Member -MemberType NoteProperty -Name "IsRunning" -Value $IsRunning
        $props | Add-Member -MemberType NoteProperty -Name "LastResult" -Value $LastResult
        $props | Add-Member -MemberType NoteProperty -Name "SessionStart" -Value $SessionStart
        $props | Add-Member -MemberType NoteProperty -Name "SessionEnd" -Value $SessionEnd
        $props | Add-Member -MemberType NoteProperty -Name "Duration" -Value $formattedDuration
    }

    return $props
}

if ($Type -eq "surebackup") {
    $jobs = Get-VBRSureBackupJob
    if ($jobs) {
        $jobData = $jobs | ForEach-Object { Get-SureBackupJobData -job $_ -Stat:($Stat) }
        $jobData | Export-Csv -Path $logfile -Encoding UTF8 -NoTypeInformation
    } else {
        Write-Host "No SureBackup jobs found"
        Exit 1
    }
} else {
    $jobs = Get-VBRJob
    if ($jobs) {
        $filteredJobs = switch ($Type) {
            "backup" { $jobs | Where-Object { $_.JobType -eq "Backup" } }
            "replica" { $jobs | Where-Object { $_.JobType -eq "Replica" } }
        }

        if ($filteredJobs.Count -eq 0) {
            Write-Host "No matching jobs found"
            Exit 1
        }

        $jobData = $filteredJobs | ForEach-Object { Get-JobData -job $_ -Type $Type }
        $jobData | Export-Csv -Path $logfile -Encoding UTF8 -NoTypeInformation
    } else {
        Write-Host "No Job output"
        Exit 1
    }
}
