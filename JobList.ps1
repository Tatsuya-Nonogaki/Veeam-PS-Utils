<#
 .SYNOPSIS
  Output Job List.

 .DESCRIPTION
  Output Job List to a CSV file.
  Version: 0.4.0beta

  The output CSV consists of the following fields,
  which may vary depending on the job 'Type' argument.

  *Name
    Job Name.

  *JobType
    Backup, Replica, SureBackup, etc.

  *Description
    Description field of the Job.

  *Sources / LinkedJob
    - For Backup/Replica: Source objects of backup/replication.
    - For SureBackup: Linked Job (placeholder).

  *TargetRepository, TargetDatastore, etc.
    Various properties depending on the job 'Type' argument.

  *RestorePoints
    Restore points to keep.
  
  *IsScheduleEnabled
    'FALSE' indicates the Job will not run automatically because of 'Disable' operation 
    on the Jobs list pane.
  
  *RunAutomatically
    'FALSE' indicates the Job will not run automatically because 'Run the job automatically' 
    check box is unchecked in Schedule page of the Job configuration.
  
  *DailyStartTime
    Configured start time at the 'Daily at this time' field of Schedule page of the Job 
    configuration. Usually ignorable on a Periodically scheduled Job.
  
  *Periodically
    Interval configured at 'Periodically every' field of the Schedule.
  
  *HourlyOffset
    Time offset configured at 'Start time within an hour' field of Periodical Schedule.
  
  *IsRunning
    The Job was running at the moment the list was acquired.

  *LastResult
    Result of the last job session.

  *SessionStart and SessionEnd
    Start and end time of the last job session.

  *Duration
    Duration of the last job calculated from SessionStart and SessionEnd.

 .PARAMETER Type
  (Alias -t) Mandatory. Job type. Must be one of 'backup', 'replica', 'surebackup'.

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

    if ($LastSession) {
        $SessionStart  = if ((Get-Date $LastSession.CreationTime) -gt (Get-Date 1970-01-01)) { Get-Date $LastSession.CreationTime -Format "yyyy/MM/dd HH:mm:ss" } else { $null }
        $SessionResult = if ($SessionStart) { $LastSession.Result } else { $null }
        $SessionEnd    = if ((Get-Date $LastSession.EndTime) -gt (Get-Date 1970-01-01)) { Get-Date $LastSession.EndTime -Format "yyyy/MM/dd HH:mm:ss" } else { $null }

        if ($SessionStart -and $SessionEnd) {
            $startTime = [datetime]::ParseExact($SessionStart, "yyyy/MM/dd HH:mm:ss", $null)
            $endTime = [datetime]::ParseExact($SessionEnd, "yyyy/MM/dd HH:mm:ss", $null)
            $formattedDuration = $endTime - $startTime
            $formattedDuration = $formattedDuration.ToString("hh\:mm\:ss")
        } else {
            $formattedDuration = $null
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
        DailyStartTime = if ($job.ScheduleOptions.OptionsDaily.TimeLocal) { $job.ScheduleOptions.OptionsDaily.TimeLocal | Get-Date -Format t } else { $null }
        Periodically = if ($job.ScheduleOptions.OptionsPeriodically.Enabled -eq "True") { ($job.ScheduleOptions.OptionsPeriodically -split ",")[1] -replace '^[^,]*:\s*', '' } else { $null }
        HourlyOffset = if ($job.ScheduleOptions.OptionsPeriodically.Enabled -eq "True") { $job.ScheduleOptions.OptionsPeriodically.HourlyOffset } else { $null }
    }

    $specificProps = @{
        TargetRepository = $job.GetTargetRepository().Name
        TargetCluster = $job.ViReplicaTargetOptions.ClusterName
        TargetFolder = $job.ViReplicaTargetOptions.ReplicaTargetVmFolderName
        TargetDatastore = $job.ViReplicaTargetOptions.DatastoreName
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
        [Object]$job
    )

    $LastSession = $job.FindLastSession()

    if ($LastSession) {
        $SessionStart  = if ((Get-Date $LastSession.CreationTime) -gt (Get-Date 1970-01-01)) { Get-Date $LastSession.CreationTime -Format "yyyy/MM/dd HH:mm:ss" } else { $null }
        $SessionResult = if ($SessionStart) { $LastSession.Result } else { $null }
        $SessionEnd    = if ((Get-Date $LastSession.EndTime) -gt (Get-Date 1970-01-01)) { Get-Date $LastSession.EndTime -Format "yyyy/MM/dd HH:mm:ss" } else { $null }

        if ($SessionStart -and $SessionEnd) {
            $startTime = [datetime]::ParseExact($SessionStart, "yyyy/MM/dd HH:mm:ss", $null)
            $endTime = [datetime]::ParseExact($SessionEnd, "yyyy/MM/dd HH:mm:ss", $null)
            $formattedDuration = $endTime - $startTime
            $formattedDuration = $formattedDuration.ToString("hh\:mm\:ss")
        } else {
            $formattedDuration = $null
        }
    }

    # Placeholders for SureBackup-specific fields.
    # You can update these as you explore the SureBackup job object properties.
    $props = [PSCustomObject]@{
        Name = $job.Name
        JobType = "SureBackup"
        Description = $job.Description
        LinkedJob = $job.LinkedJob.Job.Name -join ";"
        IsScheduleEnabled = $job.IsEnabled
        RunAutomatically = $job.ScheduleEnabled
        DailyStartTime = $null # Placeholder: fill with actual property if found
        Periodically = $null   # Placeholder: fill with actual property if found
        HourlyOffset = $null   # Placeholder: fill with actual property if found
    }

    if ($Stat) {
        $props | Add-Member -MemberType NoteProperty -Name "IsRunning" -Value $job.IsRunning
        $props | Add-Member -MemberType NoteProperty -Name "LastResult" -Value $SessionResult
        $props | Add-Member -MemberType NoteProperty -Name "SessionStart" -Value $SessionStart
        $props | Add-Member -MemberType NoteProperty -Name "SessionEnd" -Value $SessionEnd
        $props | Add-Member -MemberType NoteProperty -Name "Duration" -Value $formattedDuration
    }

    return $props
}

if ($Type -eq "surebackup") {
    $jobs = Get-VBRSureBackupJob
    if ($jobs) {
        $jobData = $jobs | ForEach-Object { Get-SureBackupJobData -job $_ }
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
