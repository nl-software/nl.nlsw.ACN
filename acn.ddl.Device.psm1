#	__ _ ____ _  _ _    _ ____ ____   ____ ____ ____ ___ _  _ ____ ____ ____
#	| \| |=== |/\| |___ | |--- |===   ==== [__] |---  |  |/\| |--| |--< |===
#
# @file acn.ddl.Device.psm1
# @copyright Ernst van der Pols, Licensed under the EUPL-1.2-or-later
# @date 2022-04-06
# Processing of ANSI E1.17 Architecture for Control Networks Device Description Language documents.
#
#requires -version 5
#requires -modules nl.nlsw.Document

using namespace acn.ddl
using namespace nl.nlsw.Identifiers
using namespace nl.nlsw.Items

# compile the C# types to a DLL library
if ((test-path "$PSScriptRoot\bin\Debug\netstandard2.0\nl.nlsw.ACN.dll")) {
	# import the library
	Add-Type -Path "$PSScriptRoot\bin\Debug\netstandard2.0\nl.nlsw.ACN.dll"
}
else {
	if (!(test-path "$PSScriptRoot\nl.nlsw.ACN.dll")) {
		# compile the C# types to a DLL library
		Add-Type -Path "$PSScriptRoot\source\acn.ddl.Device.cs","$PSScriptRoot\source\acn.ddl.1.1.xsd.cs",`
			"$PSScriptRoot\source\acn.CANopen.cs","$PSScriptRoot\source\acn.dms.Device.cs" `
			-ReferencedAssemblies "System.Xml.dll","$PSScriptRoot\..\nl.nlsw.Document\nl.nlsw.Document.dll" `
			-OutputAssembly "$PSScriptRoot\nl.nlsw.ACN.dll" -OutputType Library
	}
	# import the library
	Add-Type -Path "$PSScriptRoot\nl.nlsw.ACN.dll"
}

<#
.SYNOPSIS
 ACN Module class.

.DESCRIPTION
 The AcnModule class provides data and operations for processing ACN DDL module documents.
 
 This class implements/supports the PowerShell functions declared in this module.

.LINK
 https://fiware-datamodels.readthedocs.io/en/latest/index.html

.NOTES
 Since class support in PowerShell 5.0 is still limited, we use it here
 only for declaration of the static (foreign) device model specification, with various
 static operations.
#>
class AcnModule {
	# default version supported
	static [string]$version = "4.0";
	# known media-types to contain a data models
	static [string[]]$mediaTypes = @(
		"application/vnd.ms-excel",
		"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
		"application/vnd.ms-excel.sheet.macroEnabled.12",
		"application/xml"
	);
	# known file name extensions
	static [string[]] $extension = @(
		"xls", "xlsx", "csv",
		"ddl","xml"
	);
	static [hashtable] $formats = @{
	"ddl2008" = [PSCustomObject]@{
			version = "1.1";
			namespace = "http://www.esta.org/acn/namespace/ddl/2008/"
		}
	};

	# static constructor
	static AcnModule() {
	}
	
	static [void] Write([nl.nlsw.Items.Writer]$writer) {
	}
}

<#
.SYNOPSIS
 Create a new ACN DDL BehaviorSet Document.
  
.DESCRIPTION
 Creates a new ACN DDL document containing a ddl:behaviorset module.

.PARAMETER DocumentList
 An acn.ddl.DocumentList object might be provided to add the new document to. By default a new DocumentList is created.

.PARAMETER Name
 The (formal) name or textual identifier of the module. This should be a so-called non-colon name
 (NCName), conforming to the rules for the xml:id attribute. This means, only a limited set of characters is allowed. The name is case-sensitive, used for ID/IDREF matching. It may be piped.

 Use the label element of the module to specify a display name of the module.

.PARAMETER Provider
 The URI of the provider of the ACN DDL document.

 The provider attribute shall unambiguously indicate the organization that created and maintains the ACN DDL document. This is not necessarily the same as the organization that produces the equipment (for example a definition may be reused). The preferred form for the provider attribute is a URL that clearly identifies the organization and the appropriate department or section.

.INPUTS
 System.String

.OUTPUTS
 acn.ddl.Document

.EXAMPLE
 PS> $document = 'com.example.Behaviors' | New-AcnBehaviorSet -provider 'http://www.example.com'
 PS> $document.RootNode.label.Value = "Example's Behavior Set"
 PS> $document | Export-AcnModule "{name}.ddl.xml"
 
 - Create a new document for the description of the 'com.example.Behaviors' behavior set. The provider of the
   description has the URL 'http://www.example.com'. The document is added to a new acn.ddl.DocumentList.
 - A display name is specified for the module in the label element.
 - The created document is than saved to 'com.example.Behaviors.dd.xml' in the current
   folder of the file system, using the NAME-macro in the specified filename.
 
.EXAMPLE
 PS> $DocumentList = New-AcnDocumentList
 PS> $document = New-AcnBehaviorSet $DocumentList 'com.example.Behaviors' 'http://www.example.com' 
 PS> $DocumentList | Export-AcnModule "{name}.ddl.xml"
 
 - A new document for the description of the 'com.example.Behaviors' behavior set is added to the $DocumentList.
 - All documents of the $DocumentList are saved to file, with the Name of the modules as filename.
#>
function New-AcnBehaviorSet {
	[CmdletBinding()]
	[OutputType([acn.ddl.Document])]	# only for documentation
	param(
		[Parameter(Mandatory=$false)][AllowNull()][Alias("d","dir")]
		[acn.ddl.DocumentList]$DocumentList = $null,

		[Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="Enter the formal name (xml:id) of the behaviorset module")]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter(Mandatory=$true, HelpMessage="Enter the URL of the module provider")]
		[ValidateNotNullOrEmpty()]
		[System.Uri]$Provider
	)
	begin {
		# declare the container for the document to create
		if ($DocumentList -eq $null) {
			$DocumentList = [acn.ddl.DocumentList]::New()
		}
	}
	process {
		$result = $DocumentList.NewBehaviorSet($Name)
		$result.RootNode.Module.provider = $Provider
		$result
	}
}

<#
.SYNOPSIS
 Create a new ACN DDL Device Document.
  
.DESCRIPTION
 Creates a new ACN DDL document containing a ddl:device description module.

.PARAMETER DocumentList
 An acn.ddl.DocumentList object might be provided to add the new document to. By default a new DocumentList is created.

.PARAMETER Name
 The (formal) name or textual identifier of the module. This should be a so-called non-colon name
 (NCName), conforming to the rules for the xml:id attribute. This means, only a limited set of characters is allowed. The name is case-sensitive, used for ID/IDREF matching. It may be piped.

 Use the label element of the module to specify a display name of the device.

.PARAMETER Provider
 The URI of the provider of the ACN DDL document.

 The provider attribute shall unambiguously indicate the organization that created and maintains the ACN DDL document. This is not necessarily the same as the organization that produces the equipment (for example a definition may be reused). The preferred form for the provider attribute is a URL that clearly identifies the organization and the appropriate department or section.

.INPUTS
 System.String

.OUTPUTS
 acn.ddl.Document

.EXAMPLE
 PS> $document = New-AcnDevice $null 'com.example.Device' 'http://www.example.com'
 PS> $document.RootNode.label.Value = "Example's First Device"
 PS> $document | Export-AcnModule "{name}.ddl.xml"
 
 - Create a new document for the description of the 'com.example.Device' device. The provider of the
   description has the URL 'http://www.example.com'. The document is added to a new
   acn.ddl.DocumentList.
 - A display name is specified for the device in the label element.
 - The created document is than saved to 'com.example.Device.dd.xml' in the current
   folder of the file system, using the NAME-macro in the specified filename.
 
.EXAMPLE
 PS> $DocumentList = New-AcnDocumentList
 PS> $document = New-AcnDevice $DocumentList 'com.example.Device' 'http://www.example.com'
 PS> $DocumentList | Export-AcnModule "{name}.ddl.xml"
 
 - A new document for the description of the 'com.example.Device' device is added to the $DocumentList.
 - All documents of the $DocumentList are saved to file, with the Name of the modules as filename.
#>
function New-AcnDevice {
	[CmdletBinding()]
	[OutputType([acn.ddl.Document])]	# only for documentation
	param(
		[Parameter(Mandatory=$false)][AllowNull()][Alias("d","dir")]
		[acn.ddl.DocumentList]$DocumentList = $null,

		[Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="Enter the formal name (xml:id) of the device module")]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter(Mandatory=$true, HelpMessage="Enter the URL of the module provider")]
		[ValidateNotNullOrEmpty()]
		[System.Uri]$Provider
	)
	begin {
		# declare the container for the document to create
		if ($DocumentList -eq $null) {
			$DocumentList = [acn.ddl.DocumentList]::New()
		}
	}
	process {
		$result = $DocumentList.NewDevice($Name)
		$result.RootNode.Module.provider = $Provider
		$result
	}
}

<#
.SYNOPSIS
 Create a new ACN Module Document DocumentList.
  
.DESCRIPTION
 Creates a new ACN module documents DocumentList object.
 
 The DocumentList is the central container of the ACN module documents that are part of one or more device models.

.OUTPUTS
 acn.ddl.DocumentList
#>
function New-AcnDocumentList {
	[CmdletBinding()]
	[OutputType([acn.ddl.DocumentList])]	# only for documentation
	param()
	# @note New-Object feeds a single object into the return; []:New() needs the unary comma operator for that
	return new-object acn.ddl.DocumentList
}

<#
.SYNOPSIS
 Create a new ACN DDL LanguageSet Document.
  
.DESCRIPTION
 Creates a new ACN DDL document containing a ddl:languageset module.

.PARAMETER DocumentList
 An acn.ddl.DocumentList object might be provided to add the new document to. By default a new DocumentList is created.

.PARAMETER Name
 The (formal) name or textual identifier of the module. This should be a so-called non-colon name
 (NCName), conforming to the rules for the xml:id attribute. This means, only a limited set of characters is allowed. The name is case-sensitive, used for ID/IDREF matching. It may be piped.

 Use the label element of the module to specify a display name of the module.

.PARAMETER Provider
 The URI of the provider of the ACN DDL document.

 The provider attribute shall unambiguously indicate the organization that created and maintains the ACN DDL document. This is not necessarily the same as the organization that produces the equipment (for example a definition may be reused). The preferred form for the provider attribute is a URL that clearly identifies the organization and the appropriate department or section.

.INPUTS
 System.String

.OUTPUTS
 acn.ddl.Document

.EXAMPLE
 PS> $document = New-AcnLanguageSet $null 'com.example.Strings' 'http://www.example.com'
 PS> $document.RootNode.label.Value = "Example's Language Dependent Strings"
 PS> $document | Export-AcnModule "{name}.ddl.xml"
 
 - Create a new document for the description of the 'com.example.Strings' language set. The provider of the
   description has the URL 'http://www.example.com'. The document is added to a new acn.ddl.DocumentList.
 - A display name is specified for the module in the label element.
 - The created document is than saved to 'com.example.Strings.dd.xml' in the current
   folder of the file system, using the NAME-macro in the specified filename.
 
.EXAMPLE
 PS> $DocumentList = New-AcnDocumentList
 PS> $document = New-AcnlanguageSet $DocumentList 'com.example.Strings' 'http://www.example.com'
 PS> $DocumentList | Export-AcnModule "{name}.ddl.xml"
 
 - A new document for the description of the 'com.example.Strings' language set is added to the $DocumentList.
 - All documents of the $DocumentList are saved to file, with the Name of the modules as filename.
#>
function New-AcnLanguageSet {
	[CmdletBinding()]
	[OutputType([acn.ddl.Document])]	# only for documentation
	param(
		[Parameter(Mandatory=$false)][AllowNull()][Alias("d","dir")]
		[acn.ddl.DocumentList]$DocumentList = $null,

		[Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="Enter the formal name (xml:id) of the languageset module")]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter(Mandatory=$true, HelpMessage="Enter the URL of the module provider")]
		[ValidateNotNullOrEmpty()]
		[System.Uri]$Provider
	)
	begin {
		# declare the container for the document to create
		if ($DocumentList -eq $null) {
			$DocumentList = [acn.ddl.DocumentList]::New()
		}
	}
	process {
		$result = $DocumentList.NewLanguageSet($Name)
		$result.RootNode.Module.provider = $Provider;
		$result
	}
}

<#
.SYNOPSIS
 Get the "appliance" of the specified root device.
 
.DESCRIPTION
 In ACN DDL an appliance is a piece of equipment described by a root device and all its children and descendents.

 Consider the appliance as the runtime expansion of the device, as described by the ACN DDL root device.

 The appliance is attached to the root device, and therefore available for further reference from the
 acn.ddl.Device node.
 
.PARAMETER RootDevice
 ACN DDL Device module to get the appliance of. This device is the root device of the appliance.

.INPUTS
 acn.ddl.Device - the root device to construct the appliance of

.OUTPUTS
 acn.ddl.Appliance - the appliance (the expanded root device)

.EXAMPLE
 PS> $device = $DocumentList[0].Device | Get-AcnAppliance
 
 Construct the appliance from the first DDL module in the DocumentList, which contains the root device.
#>
function Get-AcnAppliance {
	[CmdletBinding()]
	param ( 
		[Parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[acn.ddl.Device]$RootDevice
	)
	begin {
	}
	process {
		if ($RootDevice) {
			$appliance = [acn.ddl.Appliance]::new($RootDevice)
			,$appliance
		}
	}
	end {
	}
}

<#
.SYNOPSIS
 Exports ACN DDL module documents from an acn.ddl.DocumentList to file(s).
 
.DESCRIPTION
 Exports ACN DDL module documents from an acn.ddl.DocumentList to XML document file
 in the ACN DDL namespace.

 Use the -Path parameter to write the documents to a specific folder. By default,
 if -Path is $null or empty, the System.Xml.XmlDocument objects are output to the
 pipeline.

 You can use macros to format the file name based on properties of the module.

.PARAMETER Path
 The path of the file(s) to export. The exported files are written to the pipeline
 as System.IO.FileInfo objects.

 By default, or if -Path is set to $null or the empty string, the module documents
 are written as System.Xml.XmlDocument objects to the pipeline.

 The Path may contain one or more macros to embed data from the context in the filename.
 The macro syntax is:
		'{' [<pre> '<'] <key> ['>' <post>] ['|' <empty>] '}'
 
 with
	<pre>	text to put in front of the macro value if the value is not empty
	<key>	the macro identifier
	<post>	text to put after the macro value if the value is not empty
	<empty>	text to output if the macro value is empty
	
 Available macro key values:
 - NAME		replaced by the name of the module
 - ID		replaced by the identifier of the module
 - UUID		replaced by the UUID of the module

 A typical use case is -Path "{name|name}.ddl.xml", which means that files
 with the name of the module are created.

.PARAMETER Changed
 Only export the document if its module IsChanged property is set.

.PARAMETER Indent
 Write the XML document with non-significant line breaks and hierarchical indenting
 for easy human reading.

.PARAMETER InputObject
 An acn.ddl.Document object, or an acn.ddl.DocumentList object with the Document objects
 to export. May be piped.

.INPUTS
 acn.ddl.Document - ACN DDL module document(s) to export
 acn.ddl.DocumentList - ACN DDL module DocumentList with document(s) to export

.OUTPUTS
 System.IO.FileInfo - exported file(s)
 System.Xml.XmlDocument - or the ACN DDL document(s)

.EXAMPLE
 PS> $DocumentList | Export-AcnModule
 
 Export the ACN DDL module documents in the $DocumentList to file.

.EXAMPLE
 $DocumentList | Export-AcnModule -path ".\{uuid>-}{name}.ddl.xml"
 
 Export the module of "Test Device" to "Test_Device.ddl.xml" in the current DocumentList:
 
	PS > $DocumentList = New-AcnDocumentList
	PS > $module = $DocumentList.NewDevice("Test Device")
	PS > $module | Export-AcnModule -path ".\{uuid>-}{name}.ddl.xml"

 Note that in the -Path two macros are specified: the "uuid" property is the first component, postfixed with a hyphen if the UUID is present in the module. The standard
 Name property is the second component of the filename.

.EXAMPLE
 $module | Export-AcnModule -path ".\{uuid}{-<name}.ddl"
 
 Export the module(s) imported from "parameters.csv" to AND DDL module files 
 in the current DocumentList:
 
	PS > $DocumentList = Import-Device -path "parameters.csv"
	PS > $DocumentList | Export-AcnModule -path ".\{uuid}{-<name}.ddl.xml"

 Note that in the -Path two macros are specified: the "uuid" property is the first component,
 the "name" is the second, prefixed with a hyphen if the name is not empty.
#>
function Export-AcnModule {
	[CmdletBinding()]
	param ( 
		[Parameter(Mandatory=$false)]
		[AllowEmptyString()][AllowNull()]
		[string]$Path,
		
		[Parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[object]$InputObject,

		[Parameter(Mandatory=$false)]
		[switch]$Changed
	)
	begin {
		# create the writer
		$writer = [acn.ddl.Writer]::New()
	}
	process {
		# process the input object(s) (filter $null out)
		$InputObject | where-object { ($_ -is [acn.ddl.Document]) -and ($_.Module.IsChanged -or !$Changed) } | foreach-object {
			try {
				$writer.CurrentDocument = $_
				$writer.WriteDocument($writer.CurrentDocument)
				if ($Path) {
					# resolve macros in the Path with current person info, and make the filename unique, absolute, and valid
					$filename = $Path | Expand-ItemObjectMacros $writer.CurrentDocument | New-IncrementalFileName
					# write UTF8 text without BOM
					$writer.FlushToFile($filename)
					
					# workaround: add processing instruction
					$lines = [System.IO.File]::ReadAllLines($filename)
					$lines = [System.Collections.Generic.List[string]]::new($lines)
					$lines.Insert(1,"<?xml-stylesheet href=`"../xsl/acn.ddl.xsl`" type=`"text/xsl`"?>");
					[System.IO.File]::WriteAllLines($filename,$lines)
					
					write-verbose ("{0,16} {1}" -f "exported",$filename)
					# output the FileInfo object
					Get-Item $filename
				}
				else {
					$writer.FlushToString()
					write-verbose ("{0,16} {1}" -f "exported",$writer.CurrentDocument.Name)
				}
				$writer.CurrentDocument = $null
			}
			catch [System.Exception] {
				throw $_.Exception
			}
		}
	}
	end {
	}
}

<#
.SYNOPSIS
 Imports one or more ACN DDL module documents into an acn.ddl.DocumentList.

.DESCRIPTION
 Imports one or more ACN DDL module documents into an acn.ddl.DocumentList.

.PARAMETER Path
 The path of the file(s) to import. Wildcards accepted.

 Instead of specifying a Path, you can also provide InputObjects via the pipeline.
 If you need to process a LiteralPath, pipe the output of a Get-Item -LiteralPath call.

.PARAMETER InputObject
 ACN DDL module document(s) to import into a DocumentList. May be piped.

.PARAMETER DocumentList
 An acn.ddl.DocumentList object might be provided to import the modules into. By default
 a new DocumentList is created. The DocumentList is returned in the pipeline.

.PARAMETER Encoding
 The text encoding of the source files. By default, UTF-8 is assumed and Unicode signatures
 (Byte-Order-Marks) are recognized.

.PARAMETER ModulePath
 One or more paths of folders that contain the ACN DDL module repository.

.INPUTS
 System.String - string containing an ACN DDL module document to import
 System.IO.FileInfo - ACN DDL module document file to import
 System.IO.DirectoryInfo - ACN DDL module document file directory to import files from
 System.IO.Stream - stream with an ACN DDL module document to import

.OUTPUTS
 acn.ddl.DocumentList

.EXAMPLE
 PS> $DocumentList = Import-AcnModule "*.ddl.xml"
 
 Import ACN DDL modules in a DocumentList.
 
.EXAMPLE
 PS> $DocumentList = Import-AcnModule
 
 Import ACN DDL module documents from "*.ddl.xml" files in the current folder.

.EXAMPLE
 PS> $DocumentList = Get-Item -LiteralPath 'device[5].ddl.xml' | Import-AcnModule
 
 Import ACN DDL module document from a file that has PowerShell wildchar characters in its filename.
#>
function Import-AcnModule {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[SupportsWildcards()]
		[string[]]$Path = "*.ddl.xml",

		[Parameter(Mandatory=$false, ValueFromPipeline = $true)]
		[object[]]$InputObject,

		[Parameter(Mandatory=$false)][AllowNull()][Alias("d","dir")]
		[acn.ddl.DocumentList]$DocumentList,

		[Parameter(Mandatory=$false)]
		[string]$Encoding = "UTF-8",

		[Parameter(Mandatory=$false)][AllowNull()][Alias("mp")]
		[string[]]$ModulePath
	)
	begin {
		# declare the container for the documents to process
		if ($DocumentList -eq $null) {
			$DocumentList = [acn.ddl.DocumentList]::New()
		}
		# declare the document reader
		$reader = [acn.ddl.Reader]::New([System.Text.Encoding]::GetEncoding($Encoding))
		$reader.CurrentDocumentList = $DocumentList
		if ($ModulePath) {
			$DocumentList.ModuleFolders.Clear();
			$DocumentList.ModuleFolders.AddRange($ModulePath);
		}
	}
	process {
		if (!$InputObject -and $Path) {
			$InputObject = Get-Item $Path -ErrorAction "Stop"
		}
		# process the input object(s) (filter $null out)
		$InputObject | where-object { $_ } | foreach-object {
			$item = $_
			if ($item -is [System.IO.FileInfo]) {
				# filter non-ACN DDL modules out
				if ($item.Name -notmatch '(.ddl|.ddl.xml)$') {
					write-warning "   skipping $item"
					# return from this script-block to the next item in the pipeline
					return
				}
				try {
					# wrap the file in a StreamReader to read text from it
					# use the specified DefaultEncoding, or the encoding specified by the BOM
					$reader.TextReader = [System.IO.StreamReader]::new($item.FullName,$reader.DefaultEncoding)
					# let the user know what we are doing
					write-verbose ("{0,16} {1}" -f "importing",$reader.FileName)
					$doc = $reader.ImportDocument($reader.TextReader)
					$doc.FileInfo = $item
					$reader.FileCount++
				}
				catch [System.Exception] {
					write-error $_ 
					throw [System.Exception]::New("while importing from file $($reader.FileName)",$_.Exception)
				}
				finally {
					# dispose of the stream
					$reader.TextReader.Dispose()
					$reader.TextReader = $null
				}
			}
			elseif ($item -is [System.IO.DirectoryInfo]) {
				$files = get-childitem $item -ErrorAction "Stop"
				foreach ($file in $files) {
					if ($file -isnot [System.IO.FileInfo]) {
						write-warning " wrong type $($file.GetType().Name)"
						continue
					}
					# filter non-ACN DDL modules out
					if ($file.Name -notmatch '(.ddl|.ddl.xml)$') {
						write-warning ("{0,16} {1}" -f "skipping",$file.FullName)
						continue
					}
					try {
						# wrap the file in a StreamReader to read text from it
						# use the specified DefaultEncoding, or the encoding specified by the BOM
						$reader.TextReader = [System.IO.StreamReader]::new($file.FullName,$reader.DefaultEncoding)
						# let the user know what we are doing
						write-verbose ("{0,16} {1}" -f "importing",$reader.FileName)
						$doc = $reader.ImportDocument($reader.TextReader)
						$doc.FileInfo = $file
						$reader.FileCount++
					}
					catch [System.Exception] {
						write-error $_ 
						throw [System.Exception]::New("while importing from file $($reader.FileName)",$_.Exception)
					}
					finally {
						# dispose of the stream
						$reader.TextReader.Dispose()
						$reader.TextReader = $null
					}
				}
			}
			elseif ($item -is [System.IO.Stream]) {
				try {
					# wrap the stream in a StreamReader to read text from it
					# use the specified DefaultEncoding, or the encoding specified by the BOM
					$reader.TextReader = [System.IO.StreamReader]::new($item,$reader.DefaultEncoding)
					# let the user know what we are doing
					write-verbose ("{0,16} {1}" -f "importing",$reader.FileName)
					$doc = $reader.ImportDocument($reader.TextReader)
				}
				catch [System.Exception] {
					write-error $_ 
					throw [System.Exception]::New("while importing from file $($reader.FileName)",$_.Exception)
				}
				finally {
					# dispose of the stream
					$reader.TextReader.Dispose()
					$reader.TextReader = $null
				}
			}
			elseif ($item -is [string]) {
				try {
					# wrap the string in a StringReader to read text from it (in case the string contains multiple lines)
					$reader.TextReader = [System.IO.StringReader]::new($item)
					# let the user know what we are doing
					write-verbose ("{0,16} {1}" -f "importing",$reader.FileName)
					$doc = $reader.ImportDocument($reader.TextReader)
				}
				catch [System.Exception] {
					write-error $_ 
					throw [System.Exception]::New("while importing from source $($reader.FileName)",$_.Exception)
				}
				finally {
					# dispose of the stream
					$reader.TextReader.Dispose()
					$reader.TextReader = $null
				}
			}
		}
	}
	end {
		,$DocumentList
	}
}

Export-ModuleMember -Function *
