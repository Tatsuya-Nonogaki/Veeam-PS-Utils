<#
 .SYNOPSIS
  Provides a quick and managed way to disable or enable VBR jobs.

 .DESCRIPTION
  This script provides a quick and managed way to disable or enable VBR jobs.
  Version: 0.1.2beta

  -- draft --
  - You can disable, enable or print status of the Jobs.
  - Jobs can be filtered by one of;
    - A list file (-ListFile), in wihch target Jobs are written one per line.
    - A Job name (-JobName), mutually exclusive with -ListFile. Can be used for a sigle Job.
    - A Job type (-Type) such as `Backup', 'Replica'. If used with -ListFile or -JobName, 
      they are And'ed with this. If used alone, all Jobs of the type is to be targeted.
  -- --

 .PARAMETER ListFile
  (Alias -f) A list file from which the target Job names are read. If special keyword 
  'default' is specified, the default file defined by $defaultListFile in the script is 
  used. Either this or -JobName must be specified.

 .PARAMETER JobName
  (Alias -n) A spacific Job name. Mutually exclusive with -ListFile. Can be used insted of 
  -ListFileIf if the target to process is one single Job.

 .PARAMETER Type
  (Alias -t) Job type. Must be one of 'backup', 'replica' or another VBR Job type.

 .PARAMETER Disable
  (Alias -d) Specifies the intended action is disabling the Jobs. Mutually exclusive with 
  -Enable and -Status. If neither -Disable nor -Enable is specified, This is the default.

 .PARAMETER Enable
  (Alias -e) Specifies the intended action is enabling. Mutually exclusive with -Disable 
  and -Status.

 .PARAMETER Status
  (Alias -s) Show the enable/disable status of the Jobs. Mutually exclusive with -Enable 
  and -Disable.
#>
[CmdletBinding()]
Param(
  [Parameter(Position=0)]
  [Alias("f")]
  [string]$ListFile,

  [Parameter(Position=1)]
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

    if ($Status) {
        $Mode = "Status"
    } elseif ($Enable) {
        $Mode = "Enable"
    } else {
        $Mode = "Disable"
    }

    if (-not $ListFile -and -not $Type) {
        throw "Error: Either -ListFile or -Type (or both) must be specified."
    }

    if ($Type) {
        $Type = (Get-Culture).TextInfo.ToTitleCase($Type.ToLower())
    }

    if ($ListFile -eq "default") {
        $ListFilePath = $defaultListFile
    } elseif ($ListFile) {
        $ListFilePath = $ListFile
    } else {
        $ListFilePath = $null
    }

    # Load Job names from file if specified
    $JobNamesFromFile = @()
    if ($ListFilePath) {
        if (-not (Test-Path $ListFilePath)) {
            throw "Error: List file not found: $ListFilePath"
        }
        $JobNamesFromFile = Get-Content $ListFilePath | Where-Object { $_ -and $_.Trim() -ne "" }
        if ($JobNamesFromFile.Count -eq 0) {
            throw "Error: No Job names found in list file: $ListFilePath"
        }
    }
}

process {
    Import-Module Veeam.Backup.PowerShell -ErrorAction Stop

    $AllJobs = Get-VBRJob
    if (!$AllJobs) {
        Write-Host "No Jobs found in Veeam."
        exit 1
    }

    $TargetJobs = $AllJobs

    if ($Type) {
        $TargetJobs = $TargetJobs | Where-Object { $_.JobType -eq $Type }
        if ($TargetJobs.Count -eq 0) {
            Write-Host "No Jobs found matching type '$Type'."
            exit 1
        }
    }

    if ($JobNamesFromFile.Count -gt 0) {
        $TargetJobs = $TargetJobs | Where-Object { $JobNamesFromFile -contains $_.Name }
        if ($TargetJobs.Count -eq 0) {
            Write-Host "No Jobs found matching the names in '$ListFilePath'."
            exit 1
        }
    }

    if ($TargetJobs.Count -eq 0) {
        Write-Host "No matching Jobs found for the given criteria."
        exit 1
    }

    switch ($Mode) {
        "Status" {
            Write-Host "Status of the following job(s):"
            $TargetJobs | ForEach-Object {
                $status = if ($_.IsScheduleEnabled) { "Enabled" } else { "Disabled" }
                Write-Host ("- {0}: {1}" -f $_.Name, $status)
            }
        }
        "Disable" {
            Write-Host "Disable the following job(s):"
            $TargetJobs | ForEach-Object { Write-Host "- $($_.Name)" }
            $Confirm = Read-Host "Proceed to Disable these job(s)? (Y/N)"
            if ($Confirm -notin @("Y", "y")) {
                Write-Host "Operation cancelled."
                exit 0
            }
            $TargetJobs | ForEach-Object {
                try {
                    Disable-VBRJob -Job $_ -ErrorAction Stop
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
                Write-Host "Operation cancelled."
                exit 0
            }
            $TargetJobs | ForEach-Object {
                try {
                    Enable-VBRJob -Job $_ -ErrorAction Stop
                    Write-Host "Enabled: $($_.Name)"
                } catch {
                    Write-Warning "Failed to enable: $($_.Name) - $_"
                }
            }
        }
    }
}
