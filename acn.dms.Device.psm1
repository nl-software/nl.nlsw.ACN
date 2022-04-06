#	__ _ ____ _  _ _    _ ____ ____   ____ ____ ____ ___ _  _ ____ ____ ____
#	| \| |=== |/\| |___ | |--- |===   ==== [__] |---  |  |/\| |--| |--< |===
#
# @file acn.dms.Device.psm1
# @copyright Ernst van der Pols, Licensed under the EUPL-1.2-or-later
# @date 2020-10-01
#requires -version 5
#requires -modules nl.nlsw.Document
using namespace acn.ddl
using namespace nl.nlsw.Identifiers
using namespace nl.nlsw.Items
using namespace nl.nlsw.Document

<#
.SYNOPSIS
 Device model definition.

.DESCRIPTION
 The Device Management System consists of a set of behaviors for basic types and related 
 attributes, that are mapped to a runtime typing system for C/C++ embedded applications.

 A device description written in ACN DDL using DMS can be used to generate the data model 
 of the device in C, or C++, together with a C-based runtime type information.
 The library in this namespace uses this runtime type information to provide an abstract
 application programming interface to the data (the properties) of the device.

.LINK
 https://fiware-datamodels.readthedocs.io/en/latest/index.html

.NOTES
 Since class support in PowerShell 5.0 is still limited, we use it here
 only for declaration of the static (foreign) device model specification, with various
 static operations.
#>
class DeviceModel {
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
	static DeviceModel() {
	}

	# check if the specified media type is a known MIME type
	static [bool] IsValidMediaType([string]$mediaType) {
		return [DeviceModel]::mediaTypes.contains($mediaType);
	}
	
	# Create a new (empty) ACN DDL module document
	static [void] NewDocument([acn.ddl.Writer]$writer) {
		$format = [DeviceModel]::formats['ddl2008']
		$writer.Document = New-XmlDocument
		# create the DocumentElement node and specify the default namespace
		# and use the document node as current node for inserting the module
		$attrs = [ordered]@{
			"version" = $format.version;
			"xmlns" = $format.namespace;
			"xmlns:xlink" = (Get-XmlNamespaces)['xlink']
		}
		$writer.Document | Add-XmlProcessingInstruction "xml-stylesheet" "href=`"../xsl/acn.ddl.xsl`" type=`"text/xsl`""
		$writer.CurrentNode = $writer.Document | Add-XmlElement "" "DDL" $format.namespace $attrs
	}

	# Read a line from a BoardParameters csv file and add the property (if any) to the current Device
	static [void] ReadLine([acn.ddl.Reader]$reader, [string]$line) {
		if ([string]::IsNullOrEmpty($line)) {
			# empty line, we can skip that
			return #continue
		}
		try {
			# check if we are inside a Device
			if ($reader.CurrentDevice) {
				# we store the csv header line in the CachedLines of the reader
				if (!$reader.HasCachedLines) {
					# scan for a line starting with 'L', which indicates the header line
					if ($line.StartsWith("L,")) {
						$reader.LineCache.Add($line)
						$header = $line.Split(',')
						write-verbose ("{0,16} {1}" -f "header",$line)
					}
				}
				else {
					# lines that start with 'P' contain a property
					# get the header from the cache and use it for assignment
					$header = $reader.LineCache[0]
					$fields = $line | ConvertFrom-CSV -header $header.Split(',')
					switch ($fields.L) {
					"C" { # a group
						write-verbose ("{0,16} {1}" -f "group",$fields.ID)
						break
						}
					"P" { # a property
						$name = $fields.Name
						write-verbose ("{0,16} {1}" -f "property",$fields.Name)
						$reader.CurrentDevice.NewProperty($fields.Name,$fields);
						break
						}
					}
				}							
			}
		}
		catch [System.Exception] {
			# to enhance exception traceability, the exception is wrapped with line information
			write-error $_
			$ex = [System.Exception]::New("while reading from line `"$line`"",$_.Exception)
			$ex.Data["module"] = $reader.CurrentModule;
			$ex.Data["line"] = $line;
			throw $ex
		}
	}

	<#
	.SYNOPSIS
	 Write an acn.ddl.Module object to the internal XmlDocument in ACN DDL module format.

	.DESCRIPTION
	 Write an acn.ddl.Module object to the internal XmlDocument in ACN DDL module format.

	.PARAMETER writer
	 The acn.ddl.Writer to write with.

	.PARAMETER module
	 The acn.ddl.Module to write.
	#>
	#[acn.ddl.Writer][acn.ddl.Module]
	static [void] WriteModule($writer, $module) {
		$format = [DeviceModel]::formats['ddl2008']
		# set the module
		$writer.CurrentModule = $module;
		# create the module node and use it as container
		$attrs = [ordered]@{
			"xml:id" = $module.Name;
			"date" = "2019-10-17";	# @todo date
			"UUID" = $module.ID.UUID;
			"provider" = "http://www.esta.org/ddl/draft/";
		}
		$modulename = $module.GetType().Name.ToLower();
		$writer.CurrentNode = $writer.CurrentNode | Add-XmlElement "" $modulename $format.namespace $attrs
		# add UUIDname elements for all referenced modules
		$uuid = if ($writer.PrettyFileNames) { $module.Name; } else { $module.ID.UUID; }
		$writer.CurrentNode | Add-XmlElement "" "UUIDname" $format.namespace $([ordered]@{
			"UUID" = $uuid;
			"name" = $module.Name;
		})
		# add the label
		$writer.CurrentNode | Add-XmlElement "" "label" $format.namespace $null $module.Name
		# add protocols
		$writer.CurrentNode | Add-XmlElement "" "useprotocol" $format.namespace $([ordered]@{
			"name" = "DMS";
		})
		$writer.CurrentNode | Add-XmlElement "" "useprotocol" $format.namespace $([ordered]@{
			"name" = "Modbus.CPB";
		})
		$writer.CurrentNode | Add-XmlElement "" "useprotocol" $format.namespace $([ordered]@{
			"name" = "Modbus.KMP";
		})
		#
		switch ($modulename) {
		"device" {
				[DeviceModel]::WriteDevice($writer,$module,$format)
				break
			}
		"behaviorset" {
				[DeviceModel]::WriteBehaviorSet($writer,$module,$format)
				break
			}
		"languageset" {
				[DeviceModel]::WriteLanguageSet($writer,$module,$format)
				break
			}
		}
		write-verbose ("{0,16} {1} {2}" -f "created","ACN DDL",$module.Name)
	}
	
	static [string] ConvertFromFormatToType([string]$format) {
		switch ($format) {
		"BIT" { return "type.boolean"; }
		"UINT32" { return "type.uint32"; }
		"FLOAT32" { return "type.float32"; }
		}
		return "void";
	}

	static [string] ConvertFromFormatToDdlType([string]$format) {
		switch ($format) {
		"BIT" { return "uint"; }
		"UINT32" { return "uint"; }
		"FLOAT32" { return "float"; }
		}
		return "string";
	}

	static [void] AddUserAccess($pnode, $user, $useraccess, $format) {
		switch ($useraccess) {
		"RO" {
				$pnode | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="user.Read$($user)";
				})
				break
			}
		"RW" {
				$pnode | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="user.$($user)";
				})
				break
			}
		"WO" {
				$pnode | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="user.Write$($user)";
				})
				break
			}
		}
	}

	
	static [string] CalculateModbusAddress([string]$ID, [string]$format) {
		if ($format -eq "BIT") {
			return $ID;
		}
		return (2 * [int]$ID);
	}
	
	# Write the device content in the $writer.CurrentNode
	static [void] WriteDevice([acn.ddl.Writer]$writer, [acn.ddl.Device]$device, $format) {
		foreach ($property in $device.Properties) {
			if ([string]::IsNullOrEmpty($property.Name)) {
				continue
			}
			
			$p = $writer.CurrentNode | Add-XmlElement "" "property" $format.namespace $([ordered]@{
				"xml:id" = $property.Name;
				"valuetype" = "network";	# $property.ValueType;
			})
			
			# add the label
			$p | Add-XmlElement "" "label" $format.namespace $null $property.Name
			# add the behaviors
			$p | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
				set="acn.dms.bset"; 
				name=[DeviceModel]::ConvertFromFormatToType($property.Value.Format);
			})
			if ($property.Value.Backed_up -eq "Y") {
				$p | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acnbase.bset"; name="persistent";
				})
			}
			if ($property.Value.Journalled -eq "Y") {
				$p | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="journalled";
				})
			}
			# reverse engineer dimension from unit
			switch ($property.Value.SI_Unit) {
			"sec" {
				$p | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="period";
				})
				break
				}
			"Degrees" {
				$p | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="angle.degrees";
				})
				break
				}
			"bar(g)" {
				$p | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="pressure.bar";
				})
				break
				}
			"bar(a)" {
				$p | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="pressure.bar";
				})
				break
				}
			"degC" {
				$p | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="temperature";
				})
				break
				}
			"m3" {
				$p | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="volume";
				})
				break
				}
			"m3/h" {
				$p | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="volumeFlow.per.hour";
				})
				break
				}
			"kg" {
				$p | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="mass";
				})
				break
				}
			"kg/h" {
				$p | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="massFlow.per.hour";
				})
				break
				}
			"kg/m3" {
				$p | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="density";
				})
				break
				}
			}
			[DeviceModel]::AddUserAccess($p,"Observer",$property.Value."Operator(0)",$format);
			[DeviceModel]::AddUserAccess($p,"Operator",$property.Value."Operator(0)",$format);
			[DeviceModel]::AddUserAccess($p,"Specialist",$property.Value."Metering specialist(3)",$format);
			[DeviceModel]::AddUserAccess($p,"Service",$property.Value."Service_engineer(1)",$format);
			[DeviceModel]::AddUserAccess($p,"Expert",$property.Value."Product expert(4)",$format);
			[DeviceModel]::AddUserAccess($p,"Admin",$property.Value."Factory_engineer(2)",$format);
#			[DeviceModel]::AddUserAccess($p,"system",$property.Value."System(5)",$format);
#			[DeviceModel]::AddUserAccess($p,"application",$property.Value."Application(6)",$format);
			
			# add protocols
			$p | Add-XmlElement "" "protocol" $format.namespace $([ordered]@{
				"name" = "DMS";
			})
			$protocol = $p | Add-XmlElement "" "protocol" $format.namespace $([ordered]@{
				"name" = "Modbus.CPB";
			})
			$protocol | Add-XmlElement "" "propref_Modbus" $format.namespace $([ordered]@{
				# calculate address based on "Id" and "Format"
				"type" = if ($property.Value.Format -eq "BIT") { "DO" } else { "HR" };
				"address" = [DeviceModel]::CalculateModbusAddress($property.Value.ID,$property.Value.Format);
				"size" = if ($property.Value.Format -eq "BIT") { "1" } else { "2" };
			})
			
			# add min default and max immediate subproperties (if applicable)
			$ddltype = [DeviceModel]::ConvertFromFormatToDdlType($property.Value.Format);
			if (($ddltype -ne "float") -or ($property.Value.SI_Default -ne "0") `
			-and ($ddltype -ne "uint") -or ($property.Value.SI_Default -ne "0") `
			) {
				$def = $p | Add-XmlElement "" "property" $format.namespace $([ordered]@{
					"xml:id" = $property.Name + ".Default";
					"valuetype" = "immediate";	# $property.ValueType;
				})
				# add the label
				$def | Add-XmlElement "" "label" $format.namespace $null "Default value of $($property.Value.Name)"
				# add the behaviors
				$def | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acnbase.bset"; name="initializer";
				})
				# add the value
				$def | Add-XmlElement "" "value" $format.namespace $([ordered]@{
					type=$ddltype;
				}) $property.Value.SI_Default;
			}
			# maximum of data type
			if (($ddltype -ne "float") -or ($property.Value.SI_Maximum -ne "3.40E+38") `
			-and ($ddltype -ne "uint") -or ($property.Value.SI_Maximum -ne "4294967295") `
			) {
				$max = $p | Add-XmlElement "" "property" $format.namespace $([ordered]@{
					"xml:id" = $property.Name + ".Max";
					"valuetype" = "immediate";	# $property.ValueType;
				})
				# add the label
				$max | Add-XmlElement "" "label" $format.namespace $null "Maximum value of $($property.Value.Name)"
				# add the behaviors
				$max | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acnbase.bset"; name="limitMaxInc";
				})
				# add the value
				$max | Add-XmlElement "" "value" $format.namespace $([ordered]@{
					type=$ddltype;
				}) $property.Value.SI_Maximum;
			}
			# minimum of data type
			if (($ddltype -ne "float") -or ($property.Value.SI_Minimum -ne "-3.40E+38") `
			-and ($ddltype -ne "uint") -or ($property.Value.SI_Minimum -ne "0") `
			) {
				$min = $p | Add-XmlElement "" "property" $format.namespace $([ordered]@{
					"xml:id" = $property.Name + ".Min";
					"valuetype" = "immediate";	# $property.ValueType;
				})
				# add the label
				$min | Add-XmlElement "" "label" $format.namespace $null "Minimum value of $($property.Value.Name)"
				# add the behaviors
				$min | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acnbase.bset"; name="limitMinInc";
				})
				# add the value
				$min | Add-XmlElement "" "value" $format.namespace $([ordered]@{
					type=$ddltype;
				}) $property.Value.SI_Minimum;
			}
			# add Description as label subproperty
			if ($property.Value.Human_readable_label -ne "") {
				$rem = $p | Add-XmlElement "" "property" $format.namespace $([ordered]@{
					"xml:id" = $property.Name + ".Description";
					"valuetype" = "immediate";	# $property.ValueType;
				})
				# add the behaviors
				$rem | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acn.dms.bset"; name="description";
				})
				# add the value
				$rem | Add-XmlElement "" "value" $format.namespace $([ordered]@{
					type="string";
				}) $property.Value.Human_readable_label;
			}
			# add Remark as label subproperty
			if ($property.Value.Remark -ne "") {
				$rem = $p | Add-XmlElement "" "property" $format.namespace $([ordered]@{
					"xml:id" = $property.Name + ".Remark";
					"valuetype" = "immediate";	# $property.ValueType;
				})
				# add the Remark as label
				$rem | Add-XmlElement "" "label" $format.namespace $null "$($property.Value.Name) Remark"
				# add the behaviors
				$rem | Add-XmlElement "" "behavior" $format.namespace $([ordered]@{
					set="acnbase.bset"; name="labelString";
				})
				# add the value
				$rem | Add-XmlElement "" "value" $format.namespace $([ordered]@{
					type="string";
				}) $property.Value.Remark;
			}
		}		
	}
	# [acn.ddl.Writer][acn.ddl.BehaviorSet]
	static [void] WriteBehaviorSet($writer, $module, $format) {
	}
	# [acn.ddl.Writer][acn.ddl.LanguageSet]
	static [void] WriteLanguageSet($writer, $device, $format) {
	}
}

<#
.SYNOPSIS
 Export acn.ddl.Module objects to one or more ACN DDL module files.

.DESCRIPTION
 Export acn.ddl.Module objects to one or more XML documents in the
 ACN DDL namespace.

 Use the -Path parameter to write the document(s) to file. By default,
 if -Path is $null or empty, the System.Xml.XmlDocument objects are output to the pipeline.

.PARAMETER Path
 The name of the file(s) to export. The exported files are written to 
 the pipeline as System.IO.FileInfo objects.

 By default, or if -Path is set to $null or the empty string, the module data is
 written as System.Xml.XmlDocument objects to the pipeline.
 
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

.PARAMETER Indent
 Write the XML document with non-significant line breaks and hierarchical indenting
 for easy human reading.

.PARAMETER InputObject
 A acn.ddl.Module object, or a acn.ddl.DocumentList object with the Module objects
 to export. May be piped.

.INPUTS
 acn.ddl.Module
 acn.ddl.DocumentList
 
.OUTPUTS
 System.IO.FileInfo
 System.Xml.XmlDocument

.EXAMPLE
 $module | Export-AcnModule -path ".\{uuid}{-<name}.ddl"
 
 Export the module(s) imported from "parameters.csv" to AND DDL module files 
 in the current directory:
 
	PS > $DocumentList = Import-Device -path "parameters.csv"
	PS > $DocumentList | Export-AcnModule -path ".\{uuid}{-<name}.ddl.xml"

 Note that in the -Path two macros are specified: the "uuid" property is the first component,
 the "name" is the second, prefixed with a hyphen if the name is not empty.
 
.NOTES
 @date 2019-10-17
 @author Ernst van der Pols
 @language PowerShell 5
#>
function Export-AcnModuleXML {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$false)]
		[AllowEmptyString()][AllowNull()]
		[string]$Path,
		
		[Parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[object]$InputObject,

		[Parameter(Mandatory=$false)]
		[switch]$Indent
	)
	begin {
		# create the writer
		$writer = [acn.ddl.Writer]::New()
		# register the namespaces to use
		$writer.Namespaces = Get-XmlNamespaces
		# add the ddl namespace
		$writer.Namespaces['ddl'] = [DeviceModel]::formats['ddl2008'].namespace;
		if ($Path) {
			$match = [nl.nlsw.Document.Utility]::PathMacroRegex.Match($Path);
			if ($match.Succcess -and $match.Groups['key'] -eq 'name') {
				$writer.PrettyFileNames = $true
			}
		}
	}
	process {
		# process the single module or the modules in the DocumentList (filter $null out)
		$InputObject | where-object { $_ } | foreach-object {
			try {
				$module = $_
				[DeviceModel]::NewDocument($writer)
				[DeviceModel]::WriteModule($writer, $module)
				if ($Path) {
					# resolve macros in the Path, and make the filename unique, absolute, and valid
					$filename = $Path | Expand-AcnModuleMacros $module | New-IncrementalFileName
					# write UTF8 text with BOM
					$writer.Document.PreserveWhitespace = !$Indent
					$writer.Document.Save($filename)
					write-verbose ("{0,16} {1}" -f "exported",$filename)
					# output the FileInfo object
					Get-Item $filename
				}
				else {
					$writer.Document
					write-verbose ("{0,16} {1}" -f "exported",$writer.CurrentItem.Name)
				}
				$writer.CurrentModule = $null
			}
			catch [System.Exception] {
				throw $_.Exception
			}
		}
	}
	end {
		write-verbose ("{0,16} module(s) exported" -f $writer.ItemCount)
	}
}


<#
.SYNOPSIS
 Import a device description from various sources.

.DESCRIPTION
 Import device description data from one or more files, strings, or streams with various formatted 
 device description data.

 The ACN DDL modules are returned in the pipeline in an acn.ddl.DocumentList object.

.PARAMETER Path
 The name or System.IO.FileInfo object of the file(s) to import. The file must have a suitable
 media type or filename extension.

 In stead of specifying a Path, you can also provide InputObjects via the pipeline.

.PARAMETER InputObject
 The following objects are processed for importing device description data:
 - a System.IO.FileInfo object of a file to import; the file must have a suitable media type or filename extension;
 - a System.IO.Stream object with device description data to import;
 - a text string with device description data.
 
.PARAMETER Encoding
 The text encoding of the source files. By default, UTF-8 is assumed and Unicode signatures
 (Byte-Order-Marks) are recognized.

.PARAMETER DocumentList
 An acn.ddl.DocumentList object might be provided to import the device into. By default
 a new DocumentList is created and returned in the pipeline.

.PARAMETER MediaType
 Override the automatic media type of the source file(s) and use the specified media (a.k.a. MIME) type.
 
.INPUTS
 System.IO.FileInfo
 System.IO.Stream
 System.String

.OUTPUTS
 acn.ddl.DocumentList

.EXAMPLE
 Get-Item "*.csv" | Import-DeviceDescription | Export-AcnModule "{uuid}.ddl"

 - Get all device description files in the current directory,
 - Read the device description from the files
 - Write the device description to one or more ACN DDL module files with aa UUID filename.

.NOTES
 @date 2019-10-16
 @author Ernst van der Pols
 @language PowerShell 5
#>
function Import-DeviceDescription {
	[CmdletBinding(DefaultParameterSetName="Path")]
	param (
		[Parameter(Mandatory=$true, Position=0, HelpMessage="Enter the name of the file(s) to process", ParameterSetName="Path")]
		[object]$Path,

		[Parameter(Mandatory=$false, ValueFromPipeline = $true, ParameterSetName="Pipe")]
		[object]$InputObject,

		[Parameter(Mandatory=$false)]
		[string]$Encoding = "UTF-8",

		[Parameter(Mandatory=$false)]
		[acn.ddl.DocumentList]$DocumentList,

		[Parameter(Mandatory=$false)]
		[string]$MediaType
	)
	begin {
		# declare the container for the items to import
		if ($DocumentList -eq $null) {
			$DocumentList = [acn.ddl.DocumentList]::New()
		}
		# declare the reader
		$reader = [acn.ddl.Reader]::New([System.Text.Encoding]::GetEncoding($Encoding))
		$reader.CurrentDocumentList = $DocumentList

		if ($Path) {
			$InputObject = Get-Item $Path -ErrorAction "Stop"
		}
	}
	process {
		$InputObject | foreach-object {
			$item = $_
			if ($item -is [System.IO.FileInfo]) {
				# determine the media content type of the file
				$type = if ($MediaType) { $MediaType } else { Get-MimeType($item.FullName) }
				# validate the media type
				if (![DeviceModel]::IsValidMediaType($type)) {
					if ($item.Extension -ne ".csv") {
						write-error """$($item.Name)"" has an invalid media type: $type "
						continue
					}
				}
				try {
					# switching on MimeType is useless in Windows, since .csv has same type as .xls
					switch ($item.Extension) {
					".csv"	{
							$header = $null
							$properties = @();
							# create a file stream reader to read text from the file
							$reader.FileInfo = $item
							# use the specified DefaultEncoding, or the encoding specified by the BOM
							$reader.TextReader = [System.IO.StreamReader]::new($item.FullName,$reader.DefaultEncoding)
							write-verbose ("{0,16} from {1}" -f "import",$reader.FileName)
							# add a Device module to store the data
							$reader.Stack.Push($reader.CurrentDocumentList.NewDevice($reader.FileInfo.Name))
							$reader.CurrentModule.FileInfo = $reader.FileInfo
							# read and process lines from the stream
							while (($line = $reader.TextReader.ReadLine()) -ne $null) {
								[DeviceModel]::ReadLine($reader, $line)
							}
							# it seems reading this file was successful
							$reader.FileCount++
							break
						}
					}
				}
				catch [System.Exception] {
					write-error $_ 
					throw [System.Exception]::New("while importing from file $($reader.FileName)",$_.Exception)
				}
				finally {
					$reader.TextReader.Dispose()
					$reader.TextReader = $null
				}
			}
			elseif ($item -is [System.IO.Stream]) {
				try {
					# wrap the stream in a StreamReader to read text from it
					# use the specified DefaultEncoding, or the encoding specified by the BOM
					$reader.TextReader = [System.IO.StreamReader]::new($item,$reader.DefaultEncoding)
					# let the user know what we are doing
					write-verbose ("{0,16} from {1}" -f "import",$reader.FileName)
					# read and process lines from the stream
					while (($line = $reader.TextReader.ReadLine()) -ne $null) {
						write-verbose "reading line: $line"
						[DeviceModel]::ReadLine($reader, $line)
					}
					# test for unbalanced BEGIN END
					while ($reader.Stack.Count -gt 0) {
						[DeviceModel]::PopCurrentItem($reader)
					}
					# it seems reading this stream was successful
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
			elseif ($item -is [string]) {
				try {
					# wrap the string in a StringReader to read text from it (in case the string contains multiple lines)
					$reader.TextReader = [System.IO.StringReader]::new($item)
					# read and process lines from the string
					while (($line = $reader.TextReader.ReadLine()) -ne $null) {
						[DeviceModel]::ReadLine($reader, $line)
					}
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
		# return the DocumentList in the pipeline (as single object, so use the unary array operator)
		,$DocumentList
	}
}

Export-ModuleMember -Function *
