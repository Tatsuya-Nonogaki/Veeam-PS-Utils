<#
 .SYNOPSIS
  Disable or enable Jobs according to the list from a file.

 .DESCRIPTION
  Disable or enable Jobs according to the list from a file.
  Version: 0.1.0

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
  (Alias -d) Specifies the intended action is enabling. Mutually exclusive with 
  -Disable.
#>
[CmdletBinding()]
Param(
  [Parameter()]
  [Alias("f")]
  [string]$ListFile,

  [Parameter()]
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

    # Default list file path
    $defaultListFile = "${scriptdir}\joblist.txt"

    # Arguments validation
    if ($PSBoundParameters.Count -eq 0) {
        Get-Help $MyInvocation.InvocationName
        exit
    }

    # --Validations here--
    if (-not $PSBoundParameters.ContainsKey('MemorySize')) {
        throw "Error: -MemorySize is a mandatory parameter and must be specified."
    }

    if ($PSBoundParameters.ContainsKey('Offline')) {
        if (-not $PSBoundParameters.ContainsKey('DiskSize')) {
            throw "Error: -DiskSize must be specified when using -Offline."
        }
    } else {
        if (-not $PSBoundParameters.ContainsKey('VmName')) {
            throw "Error: -VmName is a mandatory parameter unless -Offline is specified."
        }
    }

    if ($Enable) {
        $Mode = "Enable"
    } else {
        $Mode = "Disable"
    }
}

process {

    import-module Veeam.Backup.PowerShell -warningaction silentlycontinue

    $jobs = Get-VBRJob
    if (! $jobs) {
        Write-Host "No matching Jobs found"
        Exit 1
    }

    # Filter Jobs by Type
    if ($Type) {
        $jobs | Where-Object { $_.JobType -eq (#-- capitalize $Type --) }
        if (! $jobs) {
            Write-Host "No matching Jobs found"
            Exit 1
        }
    }

    Switch ($Mode) {
        "Disable" { $jobs | Disable-VBRJob }
        "Enable"  { $jobs | Enable-VBRJob }
    }

}
