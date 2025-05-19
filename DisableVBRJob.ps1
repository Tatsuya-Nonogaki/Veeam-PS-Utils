<#
 .SYNOPSIS
  Provides a quick and managed way to disable or enable VBR jobs.

 .DESCRIPTION
  This script provides a quick and managed way to disable or enable VBR jobs.
  Version: 0.1.2beta

 .PARAMETER ListFile
  (Alias -f) A list file from which the target Job names are read. If special keyword 
  'default' is specified, the default file defined by $defaultListFile in the script is 
  used. Either this or -Type or both must be specified.

 .PARAMETER Type
  (Alias -t) Job type. Must be one of 'backup', 'replica' or another VBR Job type.
  Either this or -ListFile or both must be specified.

 .PARAMETER Disable
  (Alias -d) Specifies the intended action is disabling the Jobs. Mutually exclusive with 
  -Enable and -Status. If neither -Disable nor -Enable is specified, This is the default.

 .PARAMETER Enable
  (Alias -e) Specifies the intended action is enabling. Mutually exclusive with -Disable 
  and -Status.

 .PARAMETER Status
  (Alias -s) Just show the status of the matching Jobs insted of disabling/enabling. 
  Mutually exclusive with -Disable and -Enable.
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

    if ($Disable -and $Enable) {
        throw "Error: -Disable and -Enable cannot be specified together."
    }

    if ($Enable) {
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
            Write-Host "No matching Jobs found by type '$Type'."
            exit 1
        }
    }

    if ($JobNamesFromFile.Count -gt 0) {
        $TargetJobs = $TargetJobs | Where-Object { $JobNamesFromFile -contains $_.Name }
        if ($TargetJobs.Count -eq 0) {
            Write-Host "No matching Jobs found by the names."
            exit 1
        }
    }

    if ($TargetJobs.Count -eq 0) {
        Write-Host "No matching Jobs found for the given criteria."
        exit 1
    }

    Write-Host "$Mode the following Job(s):"
    $TargetJobs | ForEach-Object { Write-Host "- $($_.Name)" }

    # Confirm before making changes
    $Confirm = Read-Host "Proceed to $Mode these Job(s)? (Y/N)"
    if ($Confirm -notin @("Y", "y")) {
        Write-Host "Operation cancelled."
        exit 0
    }

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
