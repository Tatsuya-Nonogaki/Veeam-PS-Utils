<#
 .SYNOPSIS
  Disable or enable Jobs according to the list from a file.

 .DESCRIPTION
  Disable or enable Jobs according to the list from a file.
  Version: 0.1.1

 .PARAMETER ListFile
  (Alias -f) A list file from which the target Job names are read. If special keyword 
  'default' is specified, the default file defined by $defaultListFile in the script 
  is used. Either this or -Type or both must be specified.

 .PARAMETER Type
  (Alias -t) Job type. Must be one of 'backup', 'replica' or another VBR job type.
  Either this or -ListFile or both must be specified.

 .PARAMETER Disable
  (Alias -d) Specifies the intended action is disabling the Jobs. Mutually exclusive 
  with -Enable. If neither -Disable nor -Enable is specified, This is the default.

 .PARAMETER Enable
  (Alias -e) Specifies the intended action is enabling. Mutually exclusive with 
  -Disable.
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
  [switch]$Enable
)

begin {
    $scriptdir = Split-Path -Path $myInvocation.MyCommand.Path -Parent
    $defaultListFile = Join-Path $scriptdir "joblist.txt"

    # Show help if no parameters specified
    if ($PSBoundParameters.Count -eq 0) {
        Get-Help $MyInvocation.InvocationName
        exit 1
    }

    # Validate mutually exclusive switches
    if ($Disable -and $Enable) {
        throw "Error: -Disable and -Enable cannot be specified together."
    }

    # Set default mode to Disable
    if ($Enable) {
        $Mode = "Enable"
    } else {
        $Mode = "Disable"
    }

    # Validate at least one of ListFile or Type is provided
    if (-not $ListFile -and -not $Type) {
        throw "Error: Either -ListFile or -Type (or both) must be specified."
    }

    if ($Type) {
        $Type = (Get-Culture).TextInfo.ToTitleCase($Type.ToLower())
    }

    # Resolve list file path
    if ($ListFile -eq "default") {
        $ListFilePath = $defaultListFile
    } elseif ($ListFile) {
        $ListFilePath = $ListFile
    } else {
        $ListFilePath = $null
    }

    # Load job names from file if specified
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

    Import-Module Veeam.Backup.PowerShell -ErrorAction Stop

    # Get all jobs
    $AllJobs = Get-VBRJob
    if (!$AllJobs) {
        Write-Host "No jobs found in Veeam."
        exit 1
    }

    $TargetJobs = $AllJobs

    # Filter by Type if specified
    if ($Type) {
        $TargetJobs = $TargetJobs | Where-Object { $_.JobType -eq $Type }
        if ($TargetJobs.Count -eq 0) {
            Write-Host "No jobs found matching type '$Type'."
            exit 1
        }
    }

    # Filter by names from file if specified
    if ($JobNamesFromFile.Count -gt 0) {
        $TargetJobs = $TargetJobs | Where-Object { $JobNamesFromFile -contains $_.Name }
        if ($TargetJobs.Count -eq 0) {
            Write-Host "No jobs found matching the names in '$ListFilePath'."
            exit 1
        }
    }

    if ($TargetJobs.Count -eq 0) {
        Write-Host "No matching jobs found for the given criteria."
        exit 1
    }

    # Show what will be done
    Write-Host "$Mode the following job(s):"
    $TargetJobs | ForEach-Object { Write-Host "- $($_.Name)" }

    # Confirm before making changes
    $Confirm = Read-Host "Proceed to $Mode these job(s)? (Y/N)"
    if ($Confirm -notin @("Y", "y")) {
        Write-Host "Operation cancelled."
        exit 0
    }

    # Perform action
    switch ($Mode) {
        "Disable" {
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
