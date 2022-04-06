#
# @file nl.nlsw.ACN.psd1
#
# The nl.nlsw.ACN module provides PowerShell ACN DDL processing support.
#
@{
	# Script module or binary module file associated with this manifest.
	# RootModule = ".\acn.ddl.Device.psm1"

	# Version number of this module.
	ModuleVersion = "0.0.0.4"

	# Supported PSEditions
	# CompatiblePSEditions = @()

	# ID used to uniquely identify this module
	GUID = "de14dd6d-62a4-452a-9e7a-c58e8651c4f3"

	# Author of this module
	Author = "Ernst van der Pols"

	# Company or vendor of this module
	CompanyName = "NewLife Software"

	# Copyright statement for this module
	Copyright = "(c) Ernst van der Pols. All rights reserved."

	# Description of the functionality provided by this module
	Description = "A PowerShell utility module for processing ACN DDL documents."

	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = "5.1"

	# Name of the Windows PowerShell host required by this module
	# PowerShellHostName = ''

	# Minimum version of the Windows PowerShell host required by this module
	# PowerShellHostVersion = ''

	# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
	DotNetFrameworkVersion = "4.5"

	# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
	CLRVersion = "4.0"

	# Processor architecture (None, X86, Amd64) required by this module
	# ProcessorArchitecture = ''

	# Modules that must be imported into the global environment prior to importing this module
	RequiredModules = @(
		"nl.nlsw.Document"
	)

	# Assemblies that must be loaded prior to importing this module
	# RequiredAssemblies = @()

	# Script files (.ps1) that are run in the caller's environment prior to importing this module.
	# ScriptsToProcess = @()

	# Type files (.ps1xml) to be loaded when importing this module
	# TypesToProcess = @()

	# Format files (.ps1xml) to be loaded when importing this module
	# FormatsToProcess = @()

	# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
	NestedModules = @(
		# @note Add-Type before module with types used in ps class
		".\acn.ddl.Device.psm1",
		".\acn.ddl.Html.psm1",
		".\acn.dms.Device.psm1",
		".\acn.CANopen.psm1"
	)

	# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
	FunctionsToExport = @(
		"New-AcnBehaviorSet","New-AcnDevice","New-AcnDocumentList","New-AcnLanguageSet",
		"Convert-AcnModuleToHtml","Get-AcnAppliance",
		"Import-AcnModule","Export-AcnModule","Import-DeviceDescription",
		"Export-AcnToCANopen","Export-AcnToEmotasCDD","Import-CANopenToAcn"
	)

	# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
	CmdletsToExport = @()

	# Variables to export from this module
	VariablesToExport = @()

	# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
	AliasesToExport = @()

	# DSC resources to export from this module
	# DscResourcesToExport = @()

	# List of all modules packaged with this module
	# ModuleList = @()

	# List of all files packaged with this module
	FileList = @(
		".\source\acn.ddl.Device.cs",
		".\source\acn.ddl.Device.cs",
		".\source\acn.dms.Device.cs",
		".\source\acn.CANopen.cs",
		".\tests\Test-nl.nlsw.ACN.ps1",
		".\acn.ddl.Device.psm1",
		".\acn.ddl.Html.psm1",
		".\acn.dms.Device.psm1",
		".\acn.CANopen.psm1",
		".\nl.nlsw.ACN.csproj",
		".\readme.md",
		".\en\about_ACN.help.txt",
		".\en\about_nl.nlsw.ACN.help.txt",
		".\schema\ACN-DDL-1.1.dtd",
		".\schema\ACN-DDL-1.1.xsd",
		".\xsl\acn.ddl-to-html.xsl",
		".\xsl\acn.ddl.core.xsl",
		".\xsl\acn.ddl.xsl",
		".\xsl\site.util.xsl",
		".\ddl\acn.dms.bset.ddl.xml",
		".\ddl\acn.dms.Device.ddl.xml",
		".\ddl\acn.dms.DIO.ddl.xml",
		".\ddl\acn.dms.lset.ddl.xml",
		".\ddl\acnbase.bset.ddl.xml",
		".\ddl\acnbase.lset.ddl.xml",
		".\ddl\CANopen.301.DataTypes.ddl.xml",
		".\ddl\CANopen.301.ddl.xml",
		".\ddl\CANopen.302.ddl.xml",
		".\ddl\CANopen.404.ddl.xml",
		".\ddl\CANopen.447.DataTypes.ddl.xml",
		".\ddl\CANopen.bset.ddl.xml",
		".\ddl\CANopen.ddl.xml",
		".\ddl\CANopen.lset.ddl.xml"
	)

	# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData = @{
	
		PSData = @{
	
			# Tags applied to this module. These help with module discovery in online galleries.
			Tags = @('ACN','DDL','device')
	
			# A URL to the license for this module.
			LicenseUri = 'https://spdx.org/licenses/EUPL-1.2.html'
	
			# A URL to the main website for this project.
			ProjectUri = 'https://github.com/nl-software/nl.nlsw.ACN'
	
			# A URL to an icon representing this module.
			# IconUri = ''
	
			# ReleaseNotes of this module
			# ReleaseNotes = ''
	
		} # End of PSData hashtable
	
	} # End of PrivateData hashtable

	# HelpInfo URI of this module
	# HelpInfoUri = ''

	# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
	# DefaultCommandPrefix = ''
}
