function Uninstall-VisualStudioVsixExtension
{
<#
.SYNOPSIS
Uninstalls a Visual Studio VSIX extension.

.DESCRIPTION
This function uninstalls a Visual Studio VSIX extension by invoking
the Visual Studio extension installer (VSIXInstaller.exe).
The latest installer version found on the machine is used.
The extension is uninstalled from all Visual Studio instances present on the
machine the extension is compatible with.

.PARAMETER PackageName
The name of the package - while this is an arbitrary value, it's
recommended that it matches the package id.
Alias: Name

.PARAMETER VsixId
The Identification of the extension to be uninstalled.
Typically located inside a vsixmanifest file in the software source
repository, or found in the vsix installer after extracting it.
Alias: Id

.PARAMETER VsVersion
NOT USED. The newest available VSIXInstaller.exe program
will be used and the extension will be installed in all supported
Visual Studio products present on the machine.
Alias: VisualStudioVersion
#>
    [CmdletBinding()]
    Param
    (
        [Alias('Name')] [string] $PackageName,
        [Alias('Id')] [string] $VsixId,
        [Alias('VisualStudioVersion')] [int] $VsVersion
    )

    if ($Env:ChocolateyPackageDebug -ne $null) {
        $VerbosePreference = 'Continue'
        $DebugPreference = 'Continue'
        Write-Warning "VerbosePreference and DebugPreference set to continue due to the presence of ChocolateyPackageDebug environment variable"
    }
    Write-Debug "Running 'Uninstall-VisualStudioVsixExtension' for $PackageName with VsixId:'$VsixId' VsVersion:$VsVersion"

    # We need to source a few extension files since they aren't automatically exported
  $extensionDir = Split-Path -Parent ${function:Install-VisualStudioVsixExtension}.File
  @('Parse-Parameters'; 'Merge-AdditionalArguments';'Remove-NegatedArguments';'ConvertTo-ArgumentString';'Start-VSChocolateyProcessAsAdmin') | % {
    . "$extensionDir\$_.ps1"
  }

    $packageParameters = Parse-Parameters $env:chocolateyPackageParameters

    if ($VsVersion -ne 0) {
        Write-Warning "VsVersion is not supported yet. The extension will be uninstalled in all compatible Visual Studio instances present."
    }

    $vsixInstaller = Get-VisualStudioVsixInstaller -Latest
    Write-Verbose ('Found VSIXInstaller version {0}: {1}' -f $vsixInstaller.Version, $vsixInstaller.Path)

    $logFileName = 'VSIXInstaller_{0}_{1:yyyyMMddHHmmss}.log' -f $PackageName, (Get-Date)
    $argumentSet = @{
        'uninstall' = $VsixId
        'quiet' = $null
        'admin' = $null
        'logFile' = $logFileName
    }

    Merge-AdditionalArguments -Arguments $argumentSet -AdditionalArguments $packageParameters
    Remove-NegatedArguments -Arguments $argumentSet -RemoveNegativeSwitches
    $exeArgsAsString = ConvertTo-ArgumentString -Arguments $argumentSet -Syntax 'VSIXInstaller'

    Write-Host ('Uninstalling {0} using VSIXInstaller version {1}' -f $PackageName, $vsixInstaller.Version)
    $validExitCodes = @(0, 1002, 2003)
    $exitCode = Start-VSChocolateyProcessAsAdmin -statements $exeArgsAsString -exeToRun $vsixInstaller.Path -validExitCodes $validExitCodes
    if ($exitCode -eq 1002 -or $exitCode -eq 2003) # 1002 is returned by VSIX in VS 2017, and 2003 in earlier versions
    {
        Write-Host "Visual Studio extension '${PackageName}' is already uninstalled."
    }
    else
    {
        Write-Host "Visual Studio extension '${PackageName}' has been uninstalled from all supported Visual Studio instances."
    }
}