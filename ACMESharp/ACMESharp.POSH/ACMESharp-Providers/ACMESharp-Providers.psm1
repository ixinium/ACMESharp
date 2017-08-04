﻿
$ErrorActionPreference = 'Stop'

function Resolve-ExtensionModule {
<#
.PARAMETER ModuleName
Required, the name of the PowerShell module that is an ACMESharp Extension Module.

.PARAMETER ModuleVersion
An optional version spec, useful if multiple version of the target Extension Module
are installed.

The spec can be an exact version string or a `-like` pattern to be matched.

.PARAMETER AcmeVersion
An optional version spec, useful if multiple versions of the core ACMESharp module is installed,
this will specify which module installation will be targeted for enabling the module.

The spec can be an exact version string or a `-like` pattern to be matched.
#>
	param(
		[Parameter(Mandatory)]
		[string]$ModuleName,
		[Parameter(Mandatory=$false)]
		[string]$ModuleVersion,

		[Parameter(Mandatory=$false)]
		[string]$AcmeVersion
	)

	## Get any modules that are resident in the current session and
	## any module versions that are available on the current system
	$acmeMods = @(Get-Module ACMESharp) + @(Get-Module -ListAvailable ACMESharp | Sort-Object -Descending Version)
	$provMods = @(Get-Module $ModuleName) + (Get-Module -ListAvailable $ModuleName | Sort-Object -Descending Version)

	if ($AcmeVersion) {
		$acmeMod = $acmeMods | Where-Object { $_.Version -like $AcmeVersion } | Select-Object -First 1
	}
	else {
		$acmeMod = $acmeMods | Select-Object -First 1
	}

	if ($ModuleVersion) {
		$provMod = $provMods | Where-Object { $_.Version -like $ModuleVersion } | Select-Object -First 1
	}
	else {
		$provMod = $provMods | Select-Object -First 1
	}

	if (-not $provMod -or -not $provMod.ModuleBase) {
		Write-Error "Cannot resolve extension module's base [$ModuleName]"
		return
	}
	if (-not $acmeMod -or -not $acmeMod.ModuleBase) {
		Write-Error "Cannot resolve ACMESharp module's own base"
		return
	}
	if (-not (Test-Path $acmeMod.ModuleBase)) {
		Write-Error "Cannot find ACMESharp module base [$($x.ModuleBase)]"
		return
	}

	$extRoot = "$($acmeMod.ModuleBase)\EXT"
	$extPath = "$($extRoot)\$($provMod.Name).extlnk"

	[ordered]@{
		acmeMod = $acmeMod
		provMod = $provMod
		extRoot = $extRoot
		extPath = $extPath
	}		
}

function Get-ExtensionModule {
<#
.PARAMETER ModuleName
Optional, the name of the PowerShell module that is an enabled ACMESharp Extension Module.  If unspecified, then all enabled Extension Modules will be returned.

.PARAMETER AcmeVersion
An optional version spec, useful if multiple versions of the core ACMESharp module is installed,
this will specify which module installation will be targeted for inspecting for enabled modules.

The spec can be an exact version string or a `-like` pattern to be matched.
#>
	param(
		[Parameter(Mandatory=$false)]
		[string]$ModuleName,

		[Parameter(Mandatory=$false)]
		[string]$AcmeVersion
	)

	## Get any modules that are resident in the current session and
	## any module versions that are available on the current system
	$acmeMods = @(Get-Module ACMESharp) + @(Get-Module -ListAvailable ACMESharp | Sort-Object -Descending Version)
	if ($AcmeVersion) {
		$acmeMod = $acmeMods | Where-Object { $_.Version -like $AcmeVersion } | Select-Object -First 1
	}
	else {
		$acmeMod = $acmeMods | Select-Object -First 1
	}
	
	if (-not $acmeMod -or -not $acmeMod.ModuleBase) {
		Write-Error "Cannot resolve ACMESharp module's own base"
		return
	}
	if (-not (Test-Path $acmeMod.ModuleBase)) {
		Write-Error "Cannot find ACMESharp module base [$($x.ModuleBase)]"
		return
	}

	$extRoot = "$($acmeMod.ModuleBase)\EXT"
	$extPath = "$($extRoot)\*.extlnk"

	$extLinks = Get-ChildItem $extPath
	if ($ModuleName) {
		$extLinks = $extLinks | Where-Object { ($_.Name -replace '\.extlnk$','') -eq $ModuleName }
	}

	$extLinks | Select-Object @{
		Name = "Name"
		Expression = { $_.Name -replace '\.extlnk$','' }
	},@{
		Name = "JSON"
		Expression = { Get-Content $_ | ConvertFrom-Json }
	} | Select-Object Name,@{
		Name = "Version"
		Expression = { $_.JSON.Version }
	},@{
		Name = "Path"
		Expression = { $_.JSON.Path }
	}
}

function Enable-ExtensionModule {
<#
.PARAMETER ModuleName
Required, the name of the PowerShell module that is an ACMESharp Extension Module.

.PARAMETER ModuleVersion
An optional version spec, useful if multiple version of the target Extension Module
are installed.

The spec can be an exact version string or a `-like` pattern to be matched.

.PARAMETER AcmeVersion
An optional version spec, useful if multiple versions of the core ACMESharp module is installed,
this will specify which module installation will be targeted for enabling the module.

The spec can be an exact version string or a `-like` pattern to be matched.
#>
	param(
		[Parameter(Mandatory)]
		[string]$ModuleName,
		[Parameter(Mandatory=$false)]
		[string]$ModuleVersion,

		[Parameter(Mandatory=$false)]
		[string]$AcmeVersion
	)
	
	$deps = Resolve-ExtensionModule -ModuleName $ModuleName -AcmeVersion $AcmeVersion
	if (-not $deps) {
		return
	}

	if (Test-Path $deps.extPath) {
		Write-Error "Extension module already enabled"
		return
	}
	mkdir -Force $deps.extRoot
	Write-Output "Installing Extension Module to [$($deps.extPath)]"
	@{
		Path = $deps.provMod.ModuleBase
		Version = $deps.provMod.Version.ToString()
	} | ConvertTo-Json > $deps.extPath
}

function Disable-ExtensionModule {
<#
.PARAMETER ModuleName
Required, the name of the PowerShell module that is an ACMESharp Extension Module.

.PARAMETER ModuleVersion
An optional version spec, useful if multiple version of the target Extension Module
are installed.

The spec can be an exact version string or a `-like` pattern to be matched.

.PARAMETER AcmeVersion
An optional version spec, useful if multiple versions of the core ACMESharp module is installed,
this will specify which module installation will be targeted for enabling the module.

The spec can be an exact version string or a `-like` pattern to be matched.
#>
	param(
		[Parameter(Mandatory)]
		[string]$ModuleName,
		[Parameter(Mandatory=$false)]
		[string]$ModuleVersion,

		[Parameter(Mandatory=$false)]
		[string]$AcmeVersion
	)
	
	$deps = Resolve-ExtensionModule -ModuleName $ModuleName -AcmeVersion $AcmeVersion
	if (-not $deps) {
		return
	}

	if (-not (Test-Path $deps.extPath)) {
		Write-Error "Extension module is not enabled"
		return
	}
	Write-Output "Removing Extension Module installed at [$($deps.extPath)]"
	Remove-Item -Confirm $deps.extPath
}
