<#
.SYNOPSIS
 Test the functionality of the PowerShell module nl.nlsw.ACN.
  
.DESCRIPTION
 Runs functional tests of the functions and classes in the nl.nlsw.ACN module.
 
.PARAMETER Quiet
 No output to the host

.NOTES
 @date 2022-04-06
 @author Ernst van der Pols
#>
#
# @file Test-nl.nlsw.ACN.ps1
# @copyright Ernst van der Pols, Licensed under the EUPL-1.2-or-later
# @note this file must be UTF8-with-BOM, otherwise Windows PS does not consider it Unicode.
#
#requires -version 5.1
#requires -modules nl.nlsw.TestSuite
using namespace acn.ddl
using namespace acn.dms

[CmdletBinding()]
param ( 
	[Parameter(Mandatory=$false)]
	[switch]$Quiet
)
begin {
	# log the tests
	$suite = New-TestSuite "Module nl.nlsw.ACN" -quiet:$Quiet
	# create a folder for the resulting files of this test
#		$folder = new-item -itemtype directory -name $(New-IncrementalFileName "Device.Test" | split-path -leaf)
}
process {
	$suite | test-case "Module manifest nl.nlsw.ACN.psd1" { Test-ModuleManifest "$PSScriptRoot/../nl.nlsw.ACN.psd1" | out-null; $? } $true

	$module = $( $suite | test-case "Import module nl.nlsw.ACN" { Import-Module "nl.nlsw.ACN" -passThru } ([System.Management.Automation.PSModuleInfo]) -passThru).output
	$suite | test-case "`$module.Name == 'nl.nlsw.ACN'" { $module.Name } "nl.nlsw.ACN"

	# create a new acn.ddl.DocumentList and test the initial state
	$dir = $( $suite | test-case "`$dir = New-AcnDocumentList" { New-AcnDocumentList } ([acn.ddl.DocumentList]) -passThru ).output
	$suite | test-case "acn.ddl.DocumentList initial state" { $dir.Count -eq 0 } $true

	# create a new Device
	$doc = $( $suite | test-case "`$doc = New-AcnDevice `$dir 'com.example.Device' 'http://www.example.com'" {
		New-AcnDevice $dir 'com.example.Device' 'http://www.example.com'
	} ([acn.ddl.Document]) -passThru ).output
	$suite | test-case "`$dir.Count == 1" { $dir.Count } 1
	$suite | test-case "`$dir[0].Identifier (index and Document.Identifier test)" { $dir[0].Identifier } $doc.Identifier
	$suite | test-case "`$dir[`$doc.Identifier].Identifier == `$doc.Identifier (lookup test)" { $dir[$doc.Identifier.ToString()].Identifier } $doc.Identifier
	$suite | test-case "`$dir.GetDocumentByModuleName('com.example.Device') == `$dir" { $dir.GetDocumentByModuleName('com.example.Device').Equals($doc) } $true
	# test Document interface
	$suite | test-case "`$doc.DocumentList" { $dir.Equals($doc.DocumentList) } $true
	$suite | test-case "`$doc.Name == 'com.example.Device'" { $doc.Name } 'com.example.Device'
	$suite | test-case "`$doc.Identifier is [nl.nlsw.Identifiers.UrnUri]" { $doc.Identifier } ([nl.nlsw.Identifiers.UrnUri])
	# Document.Property not used (yet)
	$suite | test-case "`$doc.HasProperties" { $doc.HasProperties } $false
	# test Document.RootNode (== acn.ddl.DDLDocument) interface
	$suite | test-case "`$doc.RootNode" { $doc.RootNode } ([acn.ddl.DDLDocument])
	$suite | test-case "`$doc.RootNode.version = '1.1'" { $doc.RootNode.version } "1.1"
	# test Document.RootNode.Module (== acn.ddl.Device) interface
	$suite | test-case "`$doc.RootNode.Module" { $doc.RootNode.Module } ([acn.ddl.Device])
	# test shortcut interface Document.Device (== acn.ddl.Device)
	$suite | test-case "`$doc.Device == `$doc.RootNode.Module" { $doc.Device.Equals($doc.RootNode.Module) } $true
	$suite | test-case "`$doc.BehaviorSet invalid interface access (exception)" { $doc.BehaviorSet.GetUUIDname($doc.Name) } ([System.Exception])
	$suite | test-case "`$doc.LanguageSet invalid interface access (exception)" { $doc.LanguageSet.GetUUIDname($doc.Name) } ([System.Exception])
	$suite | test-case "`$doc.Device.id == 'com.example.Device'" { $doc.Device.id } $doc.Name
	$suite | test-case "`$doc.Device.date == <today>" { $doc.Device.date } ([DateTime]::Now.ToString("yyyy-MM-dd"))
	$suite | test-case "`$doc.Device.UUID == `$doc.Identifier.UUID" { $doc.Device.UUID } ($doc.Identifier.UUID)
	# test creation of UUIDname for the module itself
	$suite | test-case "`$doc.Device.GetUUIDname(`$doc.Name).UUID == `$doc.Device.UUID" { $doc.Device.GetUUIDname($doc.Name).UUID } ($doc.Device.UUID)


	# create a new BehaviorSet
	$doc = $( $suite | test-case "`$doc = New-AcnBehaviorSet `$dir 'com.example.Behaviors' 'http://www.example.com'" {
		New-AcnBehaviorSet $dir 'com.example.Behaviors' 'http://www.example.com'
	} ([acn.ddl.Document]) -passThru ).output
	$suite | test-case "`$dir.Count == 2" { $dir.Count } 2
	$suite | test-case "`$dir[1].Identifier (index and Document.Identifier test)" { $dir[1].Identifier } $doc.Identifier
	$suite | test-case "`$dir[`$doc.Identifier].Identifier == `$doc.Identifier (lookup test)" { $dir[$doc.Identifier.ToString()].Identifier } $doc.Identifier
	# test Document interface
	$suite | test-case "`$doc.DocumentList" { $dir.Equals($doc.DocumentList) } $true
	$suite | test-case "`$doc.Name == 'com.example.Behaviors'" { $doc.Name } 'com.example.Behaviors'
	$suite | test-case "`$doc.Identifier is [nl.nlsw.Identifiers.UrnUri]" { $doc.Identifier } ([nl.nlsw.Identifiers.UrnUri])
	# Document.Property not used (yet)
	$suite | test-case "`$doc.HasProperties" { $doc.HasProperties } $false
	# test Document.RootNode (== acn.ddl.DDLDocument) interface
	$suite | test-case "`$doc.RootNode" { $doc.RootNode } ([acn.ddl.DDLDocument])
	$suite | test-case "`$doc.RootNode.version = '1.1'" { $doc.RootNode.version } "1.1"
	# test Document.RootNode.Module (== acn.ddl.BehaviorSet) interface
	$suite | test-case "`$doc.RootNode.Module" { $doc.RootNode.Module } ([acn.ddl.BehaviorSet])
	# test shortcut interface Document.Device (== acn.ddl.BehaviorSet)
	$suite | test-case "`$doc.BehaviorSet == `$doc.RootNode.Module" { $doc.BehaviorSet.Equals($doc.RootNode.Module) } $true
	$suite | test-case "`$doc.Device invalid interface access (exception)" { $doc.Device.GetUUIDname($doc.Name) } ([System.Exception])
	$suite | test-case "`$doc.LanguageSet invalid interface access (exception)" { $doc.LanguageSet.GetUUIDname($doc.Name) } ([System.Exception])
	$suite | test-case "`$doc.BehaviorSet.id == 'com.example.Behaviors'" { $doc.BehaviorSet.id } $doc.Name
	$suite | test-case "`$doc.BehaviorSet.date == <today>" { $doc.BehaviorSet.date } ([DateTime]::Now.ToString("yyyy-MM-dd"))
	$suite | test-case "`$doc.BehaviorSet.UUID == `$doc.Identifier.UUID" { $doc.BehaviorSet.UUID } ($doc.Identifier.UUID)
	# test creation of UUIDname for the module itself
	$suite | test-case "`$doc.BehaviorSet.GetUUIDname(`$doc.Name).UUID == `$doc.BehaviorSet.UUID" { $doc.BehaviorSet.GetUUIDname($doc.Name).UUID } ($doc.BehaviorSet.UUID)

	# create a new LanguageSet
	$doc = $( $suite | test-case "`$doc = New-AcnLanguageSet `$dir 'com.example.Strings' 'http://www.example.com'" {
		New-AcnLanguageSet $dir 'com.example.Strings' 'http://www.example.com'
	} ([acn.ddl.Document]) -passThru ).output
	$suite | test-case "`$dir.Count == 3" { $dir.Count } 3
	$suite | test-case "`$dir[2].Identifier (index and Document.Identifier test)" { $dir[2].Identifier } $doc.Identifier
	$suite | test-case "`$dir[`$doc.Identifier].Identifier == `$doc.Identifier (lookup test)" { $dir[$doc.Identifier.ToString()].Identifier } $doc.Identifier
	# test Document interface
	$suite | test-case "`$doc.DocumentList" { $dir.Equals($doc.DocumentList) } $true
	$suite | test-case "`$doc.Name == 'com.example.Strings'" { $doc.Name } 'com.example.Strings'
	$suite | test-case "`$doc.Identifier is [nl.nlsw.Identifiers.UrnUri]" { $doc.Identifier } ([nl.nlsw.Identifiers.UrnUri])
	# Document.Property not used (yet)
	$suite | test-case "`$doc.HasProperties" { $doc.HasProperties } $false
	# test Document.RootNode (== acn.ddl.DDLDocument) interface
	$suite | test-case "`$doc.RootNode" { $doc.RootNode } ([acn.ddl.DDLDocument])
	$suite | test-case "`$doc.RootNode.version = '1.1'" { $doc.RootNode.version } "1.1"
	# test Document.RootNode.Module (== acn.ddl.LanguageSet) interface
	$suite | test-case "`$doc.RootNode.Module" { $doc.RootNode.Module } ([acn.ddl.LanguageSet])
	# test shortcut interface Document.Device (== acn.ddl.LanguageSet)
	$suite | test-case "`$doc.LanguageSet == `$doc.RootNode.Module" { $doc.LanguageSet.Equals($doc.RootNode.Module) } $true
	$suite | test-case "`$doc.Device invalid interface access (exception)" { $doc.Device.GetUUIDname($doc.Name) } ([System.Exception])
	$suite | test-case "`$doc.BehaviorSet invalid interface access (exception)" { $doc.BehaviorSet.GetUUIDname($doc.Name) } ([System.Exception])
	$suite | test-case "`$doc.LanguageSet.id == 'com.example.Behaviors'" { $doc.LanguageSet.id } $doc.Name
	$suite | test-case "`$doc.LanguageSet.date == <today>" { $doc.LanguageSet.date } ([DateTime]::Now.ToString("yyyy-MM-dd"))
	$suite | test-case "`$doc.LanguageSet.UUID == `$doc.Identifier.UUID" { $doc.LanguageSet.UUID } ($doc.Identifier.UUID)
	# test creation of UUIDname for the module itself
	$suite | test-case "`$doc.LanguageSet.GetUUIDname(`$doc.Name).UUID == `$doc.LanguageSet.UUID" { $doc.LanguageSet.GetUUIDname($doc.Name).UUID } ($doc.LanguageSet.UUID)

	# test deserializing of an ACN DDL module with the XSD generated C# classes
	$ser = [System.Xml.Serialization.XmlSerializer]::new([acn.ddl.DDLDocument])
	$fs = [System.IO.File]::OpenRead("$PSScriptRoot/../ddl/acn.dms.Device.ddl.xml")
	$ddl = $( $suite | test-case "`$ddl = deserialize 'acn.dms.Device.ddl.xml'" { $ser.Deserialize($fs) } ([acn.ddl.DDLDocument]) -passThru ).output
	$suite | test-case "`$ddl.version == 1.1" { $ddl.version } "1.1"
	
	$device = $( $suite | test-case "`$device = `$ddl.Module" { $ddl.Module } ([acn.ddl.Device]) -passThru ).output
	$suite | test-case "$device.id == 'acn.dms.Device'" { $device.id } "acn.dms.Device"
	# @todo make it a Guid compare
	$suite | test-case "$device.UUID == 'b547e8d5-cfbe-4592-8b8e-97d6beb3bd91'" { $device.UUID } "b547e8d5-cfbe-4592-8b8e-97d6beb3bd91"
	$suite | test-case "$device.provider == 'http://www.esta.org/ddl/draft/'" { $device.provider } "http://www.esta.org/ddl/draft/"
	$suite | test-case "$device.date == '2021-06-03'" { $device.date } "2021-06-03"
	$suite | test-case "device invalid interface access (exception)" { $device.Properties[0].GetFormattedName() } ([System.Exception])

	# test Import-AcnModule
	$dir = $( $suite | test-case "`$dir = Import-AcnModule 'acn.dms.Device.ddl.xml'" { Import-AcnModule "$PSScriptRoot/../ddl/acn.dms.Device.ddl.xml" -verbose } ([acn.ddl.DocumentList]) -passThru ).output
	$suite | test-case "`$dir.Count == 1" { $dir.Count } 1
	$doc = $( $suite | test-case "`$doc = `$dir[0]" { $dir[0] } ([acn.ddl.Document]) -passThru ).output
	$ddl = $( $suite | test-case "`$ddl = `$doc.RootNode" { $doc.RootNode } ([acn.ddl.DDLDocument]) -passThru ).output
	$suite | test-case "`$ddl.version == 1.1" { $ddl.version } "1.1"
	$suite | test-case "`$ddl.DocumentList.Equals(`$dir)" { $dir[0].DocumentList.Equals($dir) } $true
	$suite | test-case "`$ddl.HasProperties == false" { $dir[0].HasProperties } $false
	$suite | test-case "`$ddl.Name == 'acn.dms.Device'" { $dir[0].Name } "acn.dms.Device"
	$device = $( $suite | test-case "`$device = `$ddl.Module" { $ddl.Module } ([acn.ddl.Device]) -passThru ).output
	$suite | test-case "`$device.id == 'acn.dms.Device'" { $device.id } "acn.dms.Device"
	# @todo make it a Guid compare
	$suite | test-case "`$device.UUID == 'b547e8d5-cfbe-4592-8b8e-97d6beb3bd91'" { $device.UUID } "b547e8d5-cfbe-4592-8b8e-97d6beb3bd91"
	$suite | test-case "`$device.provider == 'http://www.esta.org/ddl/draft/'" { $device.provider } "http://www.esta.org/ddl/draft/"
	$suite | test-case "`$device.date == '2021-06-03'" { $device.date } "2021-06-03"
	$suite | test-case "device invalid interface access (exception)" { $device.Properties[0].GetFormattedName() } ([System.Exception])

}
end {
	# return the tests in the pipeline
	$suite | Write-TestResult -passThru
}
