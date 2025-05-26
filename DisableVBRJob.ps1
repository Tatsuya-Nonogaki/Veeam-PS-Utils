<#
 .SYNOPSIS
  Disable or enable Veeam jobs by list, type, or direct job name.

 .DESCRIPTION
  Disable or enable Veeam jobs, or check their enable/disable status.
  Version: 0.3.2

  Selection of target jobs requires the -Type parameter (mandatory).
  - If -Type "classic" is used, all non-SureBackup jobs (backup, replica, etc.) are selected.
  - If -Type "surebackup" is used, only SureBackup jobs are selected.
  - If a specific classic type is used (e.g. "backup", "replica", "backupcopy"), only those jobs are selected.

  You may further specify job(s) by name (-JobName) or by list file (-ListFile).
  When -ListFile is used, only the jobs with names in the file (AND with the specified -Type) will be acted upon.
  When -JobName is used, only the job with that name (AND -Type) will be acted upon.

 .PARAMETER ListFile
  (Alias -f) Path to a file containing job names (one per line). If "default", uses joblist.txt in the script directory.
  Cannot be combined with -JobName.

 .PARAMETER JobName
  (Alias -n) Name of a single job. Cannot be combined with -ListFile.

 .PARAMETER Type
  (Alias -t) Mandatory. Must be "classic", "surebackup", or a specific classic job type ("backup", "replica", "backupcopy").
  - "classic": all non-SureBackup jobs (backup, replica, etc.)
  - "surebackup": SureBackup jobs only
  - Specific type: only jobs of that type (e.g. "backup", "replica", "backupcopy").

 .PARAMETER Disable
  (Alias -d) Disable selected jobs. Mutually exclusive with -Enable and -Status.
  This is the default action if none of -Disable, -Enable, or -Status are specified.

 .PARAMETER Enable
  (Alias -e) Enable selected jobs. Mutually exclusive with -Disable and -Status.

 .PARAMETER Status
  (Alias -s) Show enable/disable status. Mutually exclusive with -Enable and -Disable.
#>
[CmdletBinding()]
Param(
  [Parameter()]
  [Alias("f")]
  [string]$ListFile,

  [Parameter()]
  [Alias("n")]
  [string]$JobName,

  [Parameter()]
  [Alias("t")]
  [string]$Type,

  [Parameter()]
  [Alias("d")]
  [switch]$Disable,

  [Parameter()]
  [Alias("e")]
  [switch]$Enable,

  [Parameter()]
  [Alias("s")]
  [switch]$Status
)

begin {
    $scriptdir = Split-Path -Path $myInvocation.MyCommand.Path -Parent
    $defaultListFile = Join-Path $scriptdir "joblist.txt"

    # --- MANDATORY: -Type ---
    $validTypes = @("classic", "surebackup", "backup", "replica", "backupcopy")
    if (-not $Type) {
        throw "Error: -Type is mandatory. Must be one of: $($validTypes -join ', ')."
    }
    $typeNorm = $Type.ToLower()
    if ($validTypes -notcontains $typeNorm) {
        throw "Error: Invalid -Type '$Type'. Must be one of: $($validTypes -join ', ')."
    }

    # --- Mutually exclusive: selection methods ---
    if ($ListFile -and $JobName) {
        throw "Error: -ListFile and -JobName cannot be specified together."
    }

    # --- Mutually exclusive: actions ---
    $switchCount = @($Disable, $Enable, $Status) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
    if ($switchCount -gt 1) {
        throw "Error: -Disable, -Enable, and -Status are mutually exclusive. Specify only one."
    }

    if ($ListFile -eq "default") {
        $ListFilePath = $defaultListFile
    } elseif ($ListFile) {
        $ListFilePath = $ListFile
    } else {
        $ListFilePath = $null
    }

    $JobNamesFromFile = @()
    if ($ListFilePath) {
        if (-not (Test-Path $ListFilePath)) {
            throw "Error: List file not found: $ListFilePath"
        }
        $JobNamesFromFile = Get-Content $ListFilePath | Where-Object { $_ -and $_.Trim() -ne "" }
        if ($JobNamesFromFile.Count -eq 0) {
            throw "Error: No job names found in list file: $ListFilePath"
        }
    }
}

process {
    Import-Module Veeam.Backup.PowerShell -WarningAction SilentlyContinue -ErrorAction Stop

    $AllJobs = @()
    $IsSureBackupMode = $false

    if ($typeNorm -eq "surebackup") {
        $IsSureBackupMode = $true
        $AllJobs = Get-VBRSureBackupJob
        if (!$AllJobs) {
            Write-Host "No SureBackup jobs found in Veeam." -ForegroundColor Yellow
            exit 1
        }
    } else {
        $AllJobs = Get-VBRJob
        if (!$AllJobs) {
            Write-Host "No classic jobs found in Veeam." -ForegroundColor Yellow
            exit 1
        }
        if ($typeNorm -ne "classic") {
            # Specific classic type (backup, replica, backupcopy)
            $AllJobs = $AllJobs | Where-Object { $_.JobType.ToString().ToLower() -eq $typeNorm }
            if (!$AllJobs) {
                Write-Host "No jobs of type '$Type' found in Veeam." -ForegroundColor Yellow
                exit 1
            }
        }
    }

    $TargetJobs = $AllJobs

    # --- Apply -ListFile filter if specified ---
    if ($JobNamesFromFile.Count -gt 0) {
        foreach ($name in $JobNamesFromFile) {
        # Print notice about non-existent job names
            if (-not ($AllJobs | Where-Object { $_.Name -eq $name })) {
                Write-Host "- No such job with the name: $name" -ForegroundColor Yellow
            }
        }
        $TargetJobs = $TargetJobs | Where-Object { $JobNamesFromFile -contains $_.Name }
        if ($TargetJobs.Count -eq 0) {
            Write-Host "No '$Type' type jobs matching the names in '$ListFilePath'." -ForegroundColor Yellow
            exit 1
        }
    }

    # --- Apply -JobName filter if specified ---
    if ($JobName) {
        $TargetJobs = $TargetJobs | Where-Object { $_.Name -eq $JobName }
        if ($TargetJobs.Count -eq 0) {
            Write-Host "No '$Type' type job with the name '$JobName'." -ForegroundColor Yellow
            exit 1
        }
    }

    if ($TargetJobs.Count -eq 0) {
        Write-Host "No matching jobs found for the given criteria." -ForegroundColor Yellow
        exit 1
    }

    # --- Determine action ---
    if ($Status) {
        $Mode = "Status"
    } elseif ($Enable) {
        $Mode = "Enable"
    } else {
        $Mode = "Disable"
    }

    # --- SureBackup-specific logic ---
    if ($IsSureBackupMode) {
        switch ($Mode) {
            "Status" {
                Write-Host "Status of the SureBackup job(s):"
                $TargetJobs | ForEach-Object {
                    $jobStatus = if ($_.IsEnabled) { "Enabled" } else { "Disabled" }
                    Write-Host ("- {0}`t{1}" -f $_.Name, $jobStatus)
                }
            }
            "Disable" {
                Write-Host "Disable the following SureBackup job(s):"
                $TargetJobs | ForEach-Object { Write-Host "- $($_.Name)" }
                $Confirm = Read-Host "Proceed to Disable these SureBackup job(s)? (Y/N)"
                if ($Confirm -notin @("Y", "y")) {
                    Write-Host "Operation cancelled." -ForegroundColor Yellow
                    exit 0
                }
                $TargetJobs | ForEach-Object {
                    if (!$_.ScheduleEnabled) {
                        Write-Host ("Skipping '{0}': cannot {1}; 'Run automatically' is unchecked in Schedule." -f $_.Name, $Mode) -ForegroundColor Yellow
                        return
                    }
                    try {
                        Disable-VBRSureBackupJob -Job $_ -ErrorAction Stop | Out-Null
                        Write-Host "Disabled: $($_.Name)"
                    } catch {
                        Write-Warning "Failed to disable: $($_.Name) - $_"
                    }
                }
            }
            "Enable" {
                Write-Host "Enable the following SureBackup job(s):"
                $TargetJobs | ForEach-Object { Write-Host "- $($_.Name)" }
                $Confirm = Read-Host "Proceed to Enable these SureBackup job(s)? (Y/N)"
                if ($Confirm -notin @("Y", "y")) {
                    Write-Host "Operation cancelled." -ForegroundColor Yellow
                    exit 0
                }
                $TargetJobs | ForEach-Object {
                    if (!$_.ScheduleEnabled) {
                        Write-Host ("Skipping '{0}': cannot {1}; 'Run automatically' is unchecked in Schedule." -f $_.Name, $Mode) -ForegroundColor Yellow
                        return
                    }
                    try {
                        Enable-VBRSureBackupJob -Job $_ -ErrorAction Stop | Out-Null
                        Write-Host "Enabled: $($_.Name)"
                    } catch {
                        Write-Warning "Failed to enable: $($_.Name) - $_"
                    }
                }
            }
        }
        return
    }

    # --- Classic job action logic (includes "classic", "backup", "replica", "backupcopy") ---
    switch ($Mode) {
        "Status" {
            Write-Host "Status of the job(s):"
            $TargetJobs | ForEach-Object {
                $jobStatus = if ($_.IsScheduleEnabled) { "Enabled" } else { "Disabled" }
                Write-Host ("- {0}`t{1}" -f $_.Name, $jobStatus)
            }
        }
        "Disable" {
            Write-Host "Disable the following job(s):"
            $TargetJobs | ForEach-Object { Write-Host "- $($_.Name)" }
            $Confirm = Read-Host "Proceed to Disable these job(s)? (Y/N)"
            if ($Confirm -notin @("Y", "y")) {
                Write-Host "Operation cancelled." -ForegroundColor Yellow
                exit 0
            }
            $TargetJobs | ForEach-Object {
                if ($_.Options.JobOptions.RunManually) {
                    Write-Host ("Skipping '{0}': cannot {1}; 'Run automatically' is unchecked in Schedule." -f $_.Name, $Mode) -ForegroundColor Yellow
                    return
                }
                try {
                    Disable-VBRJob -Job $_ -ErrorAction Stop | Out-Null
                    Write-Host "Disabled: $($_.Name)"
                } catch {
                    Write-Warning "Failed to disable: $($_.Name) - $_"
                }
            }
        }
        "Enable" {
            Write-Host "Enable the following job(s):"
            $TargetJobs | ForEach-Object { Write-Host "- $($_.Name)" }
            $Confirm = Read-Host "Proceed to Enable these job(s)? (Y/N)"
            if ($Confirm -notin @("Y", "y")) {
                Write-Host "Operation cancelled." -ForegroundColor Yellow
                exit 0
            }
            $TargetJobs | ForEach-Object {
                if ($_.Options.JobOptions.RunManually) {
                    Write-Host ("Skipping '{0}': cannot {1}; 'Run automatically' is unchecked in Schedule." -f $_.Name, $Mode) -ForegroundColor Yellow
                    return
                }
                try {
                    Enable-VBRJob -Job $_ -ErrorAction Stop | Out-Null
                    Write-Host "Enabled: $($_.Name)"
                } catch {
                    Write-Warning "Failed to enable: $($_.Name) - $_"
                }
            }
        }
    }
}
