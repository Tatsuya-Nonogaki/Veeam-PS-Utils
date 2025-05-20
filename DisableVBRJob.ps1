<#
 .SYNOPSIS
  Disable or enable Veeam jobs by list, type, or direct job name.

 .DESCRIPTION
  Disable or enable Veeam jobs. Optionally, you can check the current status.
  Version: 0.1.8a

  You can specify target jobs in three ways:
   - By providing a file of job names with -ListFile.
   - By specifying a single job directly with -JobName.
   - By specifying a job type with -Type.
  At least one of the selection methods must be provided.
  Method -JobName is mutually exclusive with -ListFile.
  If more than one selection method is provided, they are combined (AND logic).
  If only -Type is used, all jobs of that type will be selected.

 .PARAMETER ListFile
  (Alias -f) A list file containing the target job names, one per line. If special keyword 
  'default' is specified, the default file defined by $defaultListFile in this script is 
  used. Cannot be combined with -JobName. Either this, -Type, or -JobName must be specified.

 .PARAMETER JobName
  (Alias -n) Specify the name of a single job directly. Cannot be combined with -ListFile.
  Either this, -ListFile, or -Type must be specified.

 .PARAMETER Type
  (Alias -t) Job type. Must be one of 'backup', 'replica', or another VBR job type.
  Either this, -ListFile, or -JobName must be specified.

 .PARAMETER Disable
  (Alias -d) Specifies the intended action is disabling the jobs. Mutually exclusive with 
  -Enable and -Status. If neither -Disable, -Enable, nor -Status is specified, this is the 
  default action.

 .PARAMETER Enable
  (Alias -e) Specifies the intended action is enabling. Mutually exclusive with -Disable 
  and -Status.

 .PARAMETER Status
  (Alias -s) Can be used to check the status, i.e., enabled/disabled. Mutually exclusive 
  with -Enable and -Disable.
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

    if ($PSBoundParameters.Count -eq 0) {
        Get-Help $MyInvocation.InvocationName
        exit 1
    }

    $switchCount = @($Disable, $Enable, $Status) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
    if ($switchCount -gt 1) {
        throw "Error: -Disable, -Enable, and -Status are mutually exclusive. Specify only one."
    }

    if (-not $ListFile -and -not $Type -and -not $JobName) {
        throw "Error: At least one of -ListFile, -Type, or -JobName must be specified."
    }

    if ($ListFile -and $JobName) {
        throw "Error: -ListFile and -JobName cannot be specified together."
    }

    # Set operation Mode
    if ($Status) {
        $Mode = "Status"
    } elseif ($Enable) {
        $Mode = "Enable"
    } else {
        $Mode = "Disable"
    }

    # Convert Type to title case for future reference.
    if ($Type) {
        $Type = (Get-Culture).TextInfo.ToTitleCase($Type.ToLower())
    }

    # Load job names from file
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
    import-module Veeam.Backup.PowerShell -warningaction silentlycontinue -ErrorAction Stop

    $AllJobs = Get-VBRJob
    if (!$AllJobs) {
        Write-Host "No jobs found in Veeam." -ForegroundColor Yellow
        exit 1
    }

    $TargetJobs = $AllJobs

    # Filter by Type
    if ($Type) {
        $TargetJobs = $TargetJobs | Where-Object { $_.JobType -eq $Type }
        if ($TargetJobs.Count -eq 0) {
            Write-Host "No jobs found matching type '$Type'." -ForegroundColor Yellow
            exit 1
        }
    }

    # Filter by JobNamesFromFile
    if ($JobNamesFromFile.Count -gt 0) {
        # Precheck non-existent job names
        foreach ($name in $JobNamesFromFile) {
            if (-not ($AllJobs | Where-Object { $_.Name -eq $name })) {
                Write-Host "- No such job: $name" -ForegroundColor Yellow
            }
        }

        $TargetJobs = $TargetJobs | Where-Object { $JobNamesFromFile -contains $_.Name }
        if ($TargetJobs.Count -eq 0) {
            Write-Host "No jobs found matching the names in '$ListFilePath'." -ForegroundColor Yellow
            exit 1
        }
    }

    # Filter by JobName
    if ($JobName) {
        $TargetJobs = $TargetJobs | Where-Object { $_.Name -eq $JobName }
        if ($TargetJobs.Count -eq 0) {
            Write-Host "No job found with the name '$JobName'." -ForegroundColor Yellow
            exit 1
        }
    }

    if ($TargetJobs.Count -eq 0) {
        Write-Host "No matching jobs found for the given criteria." -ForegroundColor Yellow
        exit 1
    }

    switch ($Mode) {
        "Status" {
            Write-Host "Status of the job(s):"
            $TargetJobs | ForEach-Object {
                $jobStatus = if ($_.IsScheduleEnabled) { "Enabled" } else { "Disabled" }
                Write-Host ("- {0}	{1}" -f $_.Name, $jobStatus)
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
                # Check if job is set to "Run automatically"
                if ($_.Options.JobOptions.RunManually) {
                    Write-Host ("Skipping job '{0}': operation is not possible because 'Run automatically' is not selected in its 'schedule' settings." -f $_.Name) -ForegroundColor Yellow
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
                # Check if job is set to "Run automatically"
                if ($_.Options.JobOptions.RunManually) {
                    Write-Host ("Skipping job '{0}': operation is not possible because 'Run automatically' is not selected in its 'schedule' settings." -f $_.Name) -ForegroundColor Yellow
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
