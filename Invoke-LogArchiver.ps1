<#
#>
[CmdletBinding(SupportsShouldProcess=$true,
    DefaultParameterSetName="Compress")]
Param(
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateScript({ Test-Path $_ })]
    [string[]]$Path,

    [Parameter(Mandatory=$true,Position=1)]
    [ValidateScript({ $_ -gt 0 })]
    [int]$CompressAfter,

    [Parameter(ParameterSetName="Delete",Position=2)]
    [int]$DeleteAfter,

    [Parameter(ParameterSetName="Archive",Position=2)]
    [int]$ArchiveAfter,

    [Parameter(ParameterSetName="Archive",Position=3)]
    [ValidateScript({ Test-Path $_ })]
    [string]$ArchivePath,

    [string[]]$Extension = @("log")
)

#Additional parameter validation
Switch ($PSCmdlet.ParameterSetName)
{
    "Delete"       { If ($DeleteAfter -le $CompressAfter)  { Write-Error "DeleteAfter must be greater than CompressAfter" -ErrorAction Stop } Else { $Ret = $DeleteAfter } }
    "Archive"      { If ($ArchiveAfter -le $CompressAfter) { Write-Error "ArchiveAfter must be greater than CompressAfter" -ErrorAction Stop } Else { $Ret = $ArchiveAfter } }
}

#Set variables
$ValidExt = $Extension -join "|"

#Loop through all paths and add files to archive file
ForEach ($LogPath in $Path)
{
    $Files = Get-ChildItem $Path\* -Recurse -File | Where Extension -Match $ValidExt | Where LastWriteTime -lt (Get-Date).AddDays(-$CompressAfter) | ForEach 
    {
        $ArchiveFilePath = Join-Path -Path $_.Directory -ChildPath "Archive-$(Get-Date -Format 'MM-dd-yyyy').zip"
        $CompressSplat = @{
            Path             = $_.FullName
            DestinationPath  = $ArchiveFilePath
            CompressionLevel = "Optimal"
            WhatIf           = $WhatIfPreference
        }

        If (Test-Path -Path $ArchiveFilePath)
        {
            $CompressSplat.Add("Update",$true)
        }
        Compress-Archive @CompressSplat
        Remove-Item $_.FullName -Force -WhatIf
    }
}

#Clean up archive files
If ($DeleteAfter -or $ArchiveAfter)
{
    ForEach ($LogPath in $Path)
    {
        $ArchiveFiles = Get-ChildItem $LogPath\*.zip -File -Recurse | Where LastWriteTime -lt (Get-Date).AddDays(-$Ret)
        ForEach ($AF in $ArchiveFiles)
        {
            Switch ($PSCmdlet.ParameterSetName)
            {
                "Delete"   { Remove-Item -Path $AF.FullName -Force -WhatIf }
                "Archive"  { Move-Item -Path $AF.FullName -Destination $ArchivePath -WhatIf }
            }
        }
    }
}

