#
# @file acn.CANopen.psm1
# @copyright Ernst van der Pols, Licensed under the EUPL-1.2-or-later
# @date 2022-04-15
#
# Import and export of CiA CANopen data in ANSI E1.17 Architecture for Control Networks Device Description Language documents.
#
#requires -version 5
#requires -modules nl.nlsw.Document

using namespace acn.ddl
using namespace nl.nlsw.Identifiers
using namespace nl.nlsw.Items

<#
.SYNOPSIS
 CiA CANopen class.

.DESCRIPTION
 The CANopen class provides data and operations for processing CANopen documents.

 This class implements/supports the PowerShell functions declared in this module.

.LINK
 https://github.com/smart-data-models/data-models

.NOTES
 Class support in PowerShell 5.0 is still limited.
#>
class CANopen {
	# ACN DDL module provider of CiA CANopen imported modules
	static [string] $provider = "http://www.can-cia.org"
	# behaviorsets and other referenced ACN modules
	static [hashtable] $module = @{
		"acnbase.bset" = "71576eac-e94a-11dc-b664-0017316c497d";
		"acn.dms.bset" = "2f57532c-ce79-426e-92e1-13b05ce4e005";
		"CANopen.bset" = "dc528311-650f-4b8c-ab55-788876392043";
	};
	# protocol (related) identifiers
	static [hashtable] $protocolDefinition = @{
		"CANopen" = [PSCustomObject]@{
			id = "CANopen";
			prefix = "cia";
			qname = "cia:CANopen";
			namespace = "https://www.can-cia.org/CANopen";
			DataType = @{
				"CANopen.bset:type.BOOLEAN"           = "BOOLEAN";
				"CANopen.bset:type.INTEGER8"          = "INTEGER8";
				"CANopen.bset:type.INTEGER16"         = "INTEGER16";
				"CANopen.bset:type.INTEGER32"         = "INTEGER32";
				"CANopen.bset:type.INTEGER64"         = "INTEGER64";
				"CANopen.bset:type.UNSIGNED8"         = "UNSIGNED8";
				"CANopen.bset:type.UNSIGNED16"        = "UNSIGNED16";
				"CANopen.bset:type.UNSIGNED32"        = "UNSIGNED32";
				"CANopen.bset:type.UNSIGNED64"        = "UNSIGNED64";
				"CANopen.bset:type.REAL32"            = "REAL32";
				"CANopen.bset:type.REAL64"            = "REAL64";
				"CANopen.bset:type.VISIBLE_STRING"    = "VISIBLE_STRING";
				"CANopen.bset:type.OCTET_STRING"      = "OCTET_STRING";
				"CANopen.bset:type.UNICODE_STRING"    = "UNICODE_STRING";
				"CANopen.bset:type.TIME_OF_DAY"       = "TIME_OF_DAY";
				"CANopen.bset:type.TIME_DIFFERENCE"   = "TIME_DIFFERENCE";
				"CANopen.bset:type.DOMAIN"            = "DOMAIN";
				"acn.dms.bset:type.int8"              = "INTEGER8";
				"acn.dms.bset:type.int16"             = "INTEGER16";
				"acn.dms.bset:type.int32"             = "INTEGER32";
				"acn.dms.bset:type.int64"             = "INTEGER64";
				"acn.dms.bset:type.uint8"             = "UNSIGNED8";
				"acn.dms.bset:type.bitmap8"           = "UNSIGNED8";
				"acn.dms.bset:type.uint16"            = "UNSIGNED16";
				"acn.dms.bset:type.uint32"            = "UNSIGNED32";
				"acn.dms.bset:type.bitmap32"          = "UNSIGNED32";
				"acn.dms.bset:type.uint64"            = "UNSIGNED64";
				"acn.dms.bset:type.float32"           = "REAL32";
				"acn.dms.bset:type.float64"           = "REAL64";
				"acn.dms.bset:type.string"            = "VISIBLE_STRING";
			};
			attrs = 'node','index','sub','access','pdo'
			defaultAttrValue = @{
				'node' = "0";
				'index' = $null;
				'sub' = "0";
				'access' = "rw";
				'pdo' = "no"
			}
			# Get the key for sorting the property in the list of CANopen object dictionary index
			GetKey = {
				param([acn.ddl.Property]$prop,[System.Xml.XmlElement]$attrs,[hashtable]$defaultAttrs)
				if (!$attrs) {
					return $null
				}
				if ($attrs.GetAttribute("node")) {
					$defaultAttrs['node'] = $attrs.GetAttribute("node")
				}
				$sub = if ($prop.HasArray) { $null } else { $attrs.GetAttribute("sub") }
				return [CANopen]::GetCANopenKey($defaultAttrs.node,$attrs.GetAttribute("index"),$sub)
			};
			# start at 0x4100 for automatic mapping
			startIndex = 0x4100;
		};
	};
	# EDS file format specifics
	static [hashtable] $eds = @{
		# name of the export tool
		generatorName = "Export-AcnToCANopen"
		# sections that list the objects
		objectSectionKeys = "MandatoryObjects","OptionalObjects","ManufacturerObjects";
		# the expected and generated EDS specification version
		version = "4.0";
		supportedVersions = @("4.0");
		# maximum number of characters per EDS line (actually ASCII chars)
		maxLineLength = 255;
		# maxLineLength - "-".Length
		maxLineDataLength = 254;
		DeviceInfo = [ordered]@{
			VendorName = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.string" )
			};
			VendorNumber = @{
				"refId" = "CANopen.Identity.VendorID.Default";
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.uint32" )
			};
			ProductName = @{
				"behaviors" = @( "acnbase.bset:devModelName", "acn.dms.bset:type.string" )
			};
			ProductNumber = @{
				"refId" = "CANopen.Identity.ProductCode.Default";
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.uint32" )
			};
			RevisionNumber = @{
				"refId" = "CANopen.Identity.RevisionNumber.Default";
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.uint32" )
			};
			OrderCode = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.string" )
			};
			BaudRate_10 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			BaudRate_20 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			BaudRate_50 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			BaudRate_125 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			BaudRate_250 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			BaudRate_500 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			BaudRate_800 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			BaudRate_1000 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			SimpleBootUpMaster = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			SimpleBootUpSlave = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			Granularity = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.uint8" )
			};
			DynamicChannelsSupported = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.uint8" )
				"default"="0";
			};
			GroupMessaging = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			NrOfRxPDO = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.uint16" )
			};
			NrOfTxPDO = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.uint16" )
			};
			LSS_Supported = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			}
			CANopenSafetySupported = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			}
		};
		DummyUsage = [ordered]@{
			Dummy0001 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			Dummy0002 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			Dummy0003 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			Dummy0004 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			Dummy0005 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			Dummy0006 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			};
			Dummy0007 = @{
				"behaviors" = @( "acnbase.bset:devInfoItem", "acn.dms.bset:type.boolean" )
			}
		}
		# AccessTypes (pdo value depends on PDOMapping)
		AccessType = @{
			"ro" = @{ 'access'="ro"; sdo='ro'; pdo='t'; }
			"wo" = @{ 'access'="wo"; sdo='wo'; pdo='r'; }
			"rw" = @{ 'access'="rw"; sdo='rw'; pdo='tr'; }
			"rwr" = @{ 'access'="rw"; sdo='rw'; pdo='t'; }
			"rww" = @{ 'access'="rw"; sdo='rw'; pdo='r'; }
			"const" = @{ 'access'="const"; sdo='ro'; pdo='t'; }
		};
		# behaviors of supported EDS DataTypes
		DataTypeBehavior = @{
			 "1" = "CANopen.bset:type.BOOLEAN";	# deprecated in CiA1301
			 "2" = "acn.dms.bset:type.int8";
			 "3" = "acn.dms.bset:type.int16";
			 "4" = "acn.dms.bset:type.int32";
			 "5" = "acn.dms.bset:type.uint8";
			 "6" = "acn.dms.bset:type.uint16";
			 "7" = "acn.dms.bset:type.uint32";
			 "8" = "acn.dms.bset:type.float32";
			 "9" = "acn.dms.bset:type.string";
			"10" = "CANopen.bset:type.OCTET_STRING";
			"11" = "CANopen.bset:type.UNICODE_STRING";
			"17" = "acn.dms.bset:type.float64";
			"21" = "acn.dms.bset:type.int64";
			"27" = "acn.dms.bset:type.uint64";
		};
		DataType = @{
			"BOOLEAN"           =  "1";
			"INTEGER8"          =  "2";
			"INTEGER16"         =  "3";
			"INTEGER32"         =  "4";
			"UNSIGNED8"         =  "5";
			"UNSIGNED16"        =  "6";
			"UNSIGNED32"        =  "7";
			"REAL32"            =  "8";
			"VISIBLE_STRING"    =  "9";
			"OCTET_STRING"      = "10";
			"UNICODE_STRING"    = "11";
			"TIME_OF_DAY"       = "12";
			"TIME_DIFFERENCE"   = "13";
			"DOMAIN"            = "15";
			"REAL64"            = "17";
			"INTEGER64"         = "21";
			"UNSIGNED64"        = "27";
		};
		# ObjectCode behaviors of supported EDS ObjectTypes
		ObjectTypeCode = @{
			"0" = "CANopen.bset:ObjectCode.NULL";
			"2" = "CANopen.bset:ObjectCode.DOMAIN";
			"5" = "CANopen.bset:ObjectCode.DEFTYPE";
			"6" = "CANopen.bset:ObjectCode.DEFSTRUCT";
			"7" = "CANopen.bset:ObjectCode.VAR";
			"8" = "CANopen.bset:ObjectCode.ARRAY";
			"9" = "CANopen.bset:ObjectCode.RECORD";
		};
		# (EDS) attributes of ObjectCodes
		ObjectCode = @{
			"CANopen.bset:ObjectCode.NULL" = @{
				ObjectType = "0";
			};
			"CANopen.bset:ObjectCode.DOMAIN" = @{
				mandatory = 'ParameterName'
				ObjectType = "2";
				deprecated = $true;	# no longer specified in CiA1301
			};
			"CANopen.bset:ObjectCode.DEFTYPE" = @{
				mandatory = 'ParameterName','DataType','AccessType';
				unexpected = 'SubNumber','CompactSubObj'
				ObjectType = "5";
			};
			"CANopen.bset:ObjectCode.DEFSTRUCT" = @{
				mandatory = 'ParameterName','SubNumber'
				ObjectType = "6";
				isCompound = $true;
			};
			"CANopen.bset:ObjectCode.VAR" = @{
				mandatory = 'ParameterName','DataType','AccessType';
				unexpected = 'SubNumber','CompactSubObj'
				ObjectType = "7";
				supported = $true;
			};
			"CANopen.bset:ObjectCode.ARRAY" = @{
				mandatory = 'ParameterName','SubNumber'
				ObjectType = "8";
				supported = $true;
				isCompound = $true;
			}
			"CANopen.bset:ObjectCode.RECORD" = @{
				mandatory = 'ParameterName','SubNumber'
				ObjectType = "9";
				supported = $true;
				isCompound = $true;
			}
		};
	};
	# default CANopen device modules
	static [string] $deviceModuleName = "CANopen.ddl.xml"
	static [acn.ddl.DocumentList] $deviceModules = [acn.ddl.DocumentList]::new();
	static $deviceAppliance = $null;
	# default CANopen device object dictionary (with reference properties)
	static $deviceObjects = [System.Collections.Generic.SortedDictionary[[string],[acn.ddl.Property]]]::new();
	# automatic CANopen index assignement counter
	static [int] $CANopenParameterIndex = 0x4100;
	# the path or filenname of the adjunct data file(s)
	static [System.IO.FileSystemInfo] $adjunctPath;
	# the filenname of the loaded adjunct data file
	static [System.IO.FileInfo] $adjunctFile;
	# the adjunct data that supplements the source file data for import
	# Additional Data Joining Natively Undefined Concepts Table
	static $adjunctData = $null;

	static [string]	$sourceBegin = @"
///
/// @file {0}
///
/// {1} CANopen Mapping Data
///
/// @author Generated by Export-AcnToGdc: do not edit by hand.
/// @date {2}
///

#include "{3}"

///
/// {1} CANopen data items
///
CANopenDataItem const _{4}_CANopen_DataItems[{4}_CANopen_DataItemCount] = {{
"@
	static [string]	$sourceEnd = @"
}};

///
/// {0} CANopen data items table
///
CANopenDataItems const {1}_CANopen_DataItems = {{
	{1}_CANopen_DataItemCount,
	_{1}_CANopen_DataItems
}};
"@

	static [string]	$header = @"
///
/// @file {0}
///
/// {1} CANopen Mapping Data
///
/// @author Generated by Export-AcnToGdc: do not edit by hand.
/// @date {2}
///

#ifndef {3}
#define {3}

#include <rtsc/acn/dms/CANopenData.h>

#ifdef __cplusplus
extern "C" {{
#endif

/// The number of CANopen data items specified for this device
#define {4}_CANopen_DataItemCount {5}

// CANopen data item mapping table
extern CANopenDataItems const {4}_CANopen_DataItems;

#ifdef __cplusplus
}}
#endif

#endif
"@

	# ACN DMS data type information table
	static [hashtable]$DMSDataType = @{
		'acn.dms.bset:type.uint8'   = @{ code="tcUInt8";	size="1"; min=[byte]::MinValue;		max=[byte]::MaxValue; isNumber=$true; };
		'acn.dms.bset:type.uint16'  = @{ code="tcUInt16";	size="2"; min=[System.UInt16]::MinValue;	max=[System.UInt16]::MaxValue; isNumber=$true; };
		'acn.dms.bset:type.uint32'  = @{ code="tcUInt32";	size="4"; min=[System.UInt32]::MinValue;	max=[System.UInt32]::MaxValue; isNumber=$true; };
		'acn.dms.bset:type.uint64'  = @{ code="tcUInt64";	size="8"; min=[System.UInt64]::MinValue;	max=[System.UInt64]::MaxValue; isNumber=$true; };
		'acn.dms.bset:type.int8'    = @{ code="tcInt8";		size="1"; min=[sbyte]::MinValue;		max=[sbyte]::MaxValue; isNumber=$true; };
		'acn.dms.bset:type.int16'   = @{ code="tcInt16";	size="2"; min=[System.Int16]::MinValue;	max=[System.Int16]::MaxValue; isNumber=$true; };
		'acn.dms.bset:type.int32'   = @{ code="tcInt32";	size="4"; min=[System.Int32]::MinValue;	max=[System.Int32]::MaxValue; isNumber=$true; };
		'acn.dms.bset:type.int64'   = @{ code="tcInt64";	size="8"; min=[System.Int64]::MinValue;	max=[System.Int64]::MaxValue; isNumber=$true; };
		'acn.dms.bset:type.float32' = @{ code="tcFloat32";	size="4"; min=[float]::MinValue;	max=[float]::MaxValue; isNumber=$true; };
		'acn.dms.bset:type.float64' = @{ code="tcFloat64";	size="8"; min=[double]::MinValue;	max=[double]::MaxValue; isNumber=$true; };
		'acn.dms.bset:type.bitmap8' = @{ code="tcUInt8";	size="1"; isNumber=$false; };
		'acn.dms.bset:type.bitmap32'= @{ code="tcUInt32";	size="4"; isNumber=$false; };
		'acn.dms.bset:type.string'  = @{ code="tcString";	size="";  isNumber=$false; }; # read size from MaxCodeUnits subproperty
	};

	# emotas CANopen DeviceDesigner CSV-import file header, defining the table fields
	static [string]$emotasCDDHeader = "index,sub,edsname,datatype,access,value,varname,LowLimit,UpLimit,hasDefault,hasLimit,refuseRead,refuseWrite,defaultInEDS,implementationType,size,ObjectCode,mapable,description";

	# static constructor
	static CANopen() {
		# workaround for https://github.com/PowerShell/PowerShell-RFC/pull/221 Propagate execution preferences beyond script module scope
		$vbPref = ($PsCmdlet.MyInvocation.BoundParameters['verbose'] -eq $true)
		# preload the reference CANopen device description
		$deviceModuleFolder = (join-path $PSScriptRoot "ddl")
		$deviceModule = join-path $deviceModuleFolder ([CANopen]::deviceModuleName)
		[CANopen]::deviceModules.ModuleFolders.Add($deviceModuleFolder)
		[CANopen]::deviceModules = Import-AcnModule ($deviceModule) -DocumentList ([CANopen]::deviceModules) -verbose:$vbPref
		[CANopen]::deviceAppliance = Get-AcnAppliance ([CANopen]::deviceModules[0].Device)
		[CANopen]::CollectProtocolProperties([CANopen]::deviceObjects,[CANopen]::deviceAppliance,[CANopen]::protocolDefinition.CANopen,@{})
		write-verbose ("{0,16} {1}" -f [CANopen]::deviceObjects.Count,"CANopen Object Dictionary objects")
	}

	# Add the CANopen protocol attributes to the property.
	#
	# @param $property the property to add the protocol to
	# @param $objIndex the CANopen object dictionary index of the property
	# @param $subIndex the CANopen object dictionary sub-index of the property
	# @param $addAttr [ordered] hashtable with additional attributes
	# @param $index the array property index the property (-1 means non-array property)
	# @param $verify verify rather than set the protocol attributes
	static [void] AddCANopenProtocol([acn.ddl.Property]$property, [string]$objIndex, [string]$subIndex, [object]$addAttr, [int]$index = -1, [bool]$verify = $false) {
		$attrs = [ordered]@{
			index = ("0x{0:X4}" -f [int]$objIndex);
		}
		if ($subIndex) {
			$attrs.sub = $subIndex;
		}
		$protocolDef = $([CANopen]::protocolDefinition['CANopen'])
		# add the CANopen protocol specification
		$canopen = $property.GetOrAddProtocol($protocolDef.id);
		# create an XmlElement <cia:CANopen index sub .../>
		# count existing specs
		[int]$count = $canopen.GetElementCount($protocolDef.qname);

		if ($index -ge 0) {
			# check specific array mapping for array properties
			$arr = [CANopen]::ObjectToCANopenArray($property.id)
			if ($arr) {
				$attrs.index = $arr.index
			}
			$property.AddBehavior("CANopen.bset","ObjectCode.ARRAY","ObjectCode.")
			if ($count -gt 0) {
				# determine CANopen index of the array object
				$a = [CANopen]::GetProtocolElement($property,$protocolDef)
				if ($a -and !$attrs.index) {
					# the index is already determined, use that
					$attrs.index = $a.index
				}
			}
		}
		else {
			# check for CANopen RECORD membership (and not at the same time ARRAY)
			$pg = $property.ParentNode
			if ($pg -is [acn.ddl.Property]) {
				# check if the group is mapped to a CANopen RECORD
				if ($pg.HasBehavior("CANopen.bset","ObjectType.RECORD")) {
					$record = [CANopen]::GetProtocolElement($pg,$protocolDef)
				}
				else {
					$record = [CANopen]::GroupToCANopenRecord($pg.GetFullIdentifier($pg.GetDevice()))
					if ($record) {
						$pg.AddBehavior("CANopen.bset","ObjectCode.RECORD","ObjectCode.")
						# mark the NULL property with CANopen sub=0 as RECORD indication
						$co = $pg.GetOrAddProtocol($protocolDef.id)
						$co.AddOrUpdateAttributes($protocolDef.qname,$record,$protocolDef.namespace);
					}
				}
				if ($record) {
					# make the new property a member of the group: use the index, unless the max number of subsis reached
					if ([string]::IsNullOrEmpty($attrs.index)) {
						# unless already specified, make it a member of the RECORD
						$attrs.index = $record.index
					}
					# determine the existing number of members (if a member of the RECORD)
					if ([string]::IsNullOrEmpty($attrs.sub) -and ($attrs.index -eq $record.index)) {
						# unless already specified, make it the next member of the RECORD
						$sub = [int]0 # first member of CANopen record is at subIndex 1
						# determine highest subindex number already used on previous-sibling Property nodes with valuetype 'network'
						for ($i = 0; $i -lt $pg.GetIdentifiedChildNodeCount(); $i++) {
							$node = $pg.GetIdentifiedChildNode($i);
							if (($node -is [acn.ddl.Property]) -and ($node.valuetype -eq "network")) {
								if ($node -eq $property) {
									break
								}
								$a = [CANopen]::GetProtocolElement($node,$protocolDef)
								if ($a -and ($a.index -eq $record.index)) {
									$s = [int]$a.GetAttribute('sub')
									if (($s -gt $sub) -and ($s -ne 255)) {
										$sub = $s;
									}
								}
							}
						}
						# use next available number
						$sub++
						# check valid CANopen RECORD subIndex: >0 and <255
						if ($sub -ge 255) {
							$attrs.index = ""	# alternative to exception: let the system assign an automatic new index and continue
							throw [InvalidOperationException]::new(("too many CANopen RECORD members in property '{0}', subIndex ({1}) for '{2}' must be in [1..254]" -f $property.ParentNode.id,$sub,$property.id));
						}
						$attrs.sub = [string]::Format("{0:d}",$sub);
					}
				}
			}
		}
		if (!$attrs.index) {
			# assign the index automatically
			$attrs.index = [string]::Format("0x{0:X4}",[CANopen]::CANopenParameterIndex++);
		}
		if (!$attrs.sub) {
			if ($index -ge 0) {
				# in case of an array of simple type: map to CANopen ARRAY object
				# @todo check if array is of simple type (i.e. no network subproperties, ...)
				# the CANopen array uses subIndex 0 for the length, so the subIndex of element[index] is index + 1
				$attrs.sub = [string]::Format("{0:d}",$index + 1);
			}
			else {
				#$attrs.sub = "0"
			}
		}
		# add the additional attributes
		if ($addAttr) {
			foreach ($kvp in $addAttr.GetEnumerator()) {
				$attrs[$kvp.Key] = $kvp.Value
			}
		}
		if (($count -eq 0) -and ($index -ge 0)) {
			# add the sub == 0 entry before the first real member entry (problem: conflicts with ACN DDL array strategy)
			# better solution: for CANopen array: simply specify index only, and access for the members; sub is implicit then
		#	$maxSubIndex = @{ index=$attrs.index; sub="0"; access="const"; }
		#	$canopen.AddOrUpdateAttributes([CANopen]::protocolDefinition.CANopen.qname,$maxSubIndex,[CANopen]::protocolDefinition.CANopen.namespace);
		}
		$canopen.AddOrUpdateAttributes($protocolDef.qname,$attrs,$protocolDef.namespace,$index,$verify);
	}

	# Add property-specific CANopen related behaviors to the property
	static [void] AddBehaviors([acn.ddl.Property]$property, [object]$adjunctData) {
		$behaviors = $adjunctData.behaviors
		if ($behaviors) {
			foreach ($behavior in $behaviors) {
				if ($behavior -is [string]) {
					# QName specification of the behavior
					$property.AddBehavior($behavior);
				}
				else {
					$property.AddBehavior($behavior.set,$behavior.name);
				}
			}
		}
	}

	# Recursively collect properties in the specified property-tree that have a specified protocol mapping.
	# @param $list the list of collected properties
	# @param $rootnode the rootnode of the property tree (usually an acn.ddl.Appliance)
	# @param $protocol the protocol to look for
	# @param $defaultAttrs default protocol attributes to distribute to descendant nodes 
	static [void] CollectProtocolProperties(
			[System.Collections.Generic.SortedDictionary[[string],[acn.ddl.Property]]]$list,
			[acn.ddl.Property]$rootnode,
			[psobject]$protocol,
			[hashtable]$defaultAttrs
		) {
		if ($rootnode) {
			$proto = $rootnode.GetProtocol($protocol.id)
			if ($proto) {
				$key = &$protocol.GetKey $rootnode $proto.GetElement($protocol.qname) $defaultAttrs
				if ($key) {
					# we have one!
					# write-verbose ("{0,16} {1} {2}" -f "property",$key,$rootnode.id)
					$list.Add($key,$rootnode)
				}
			}
			if ($rootnode.Items) {
				foreach ($node in $rootnode.Items) {
					if ($node -is [acn.ddl.Property]) {
						[CANopen]::CollectProtocolProperties($list,$node,$protocol,$defaultAttrs)
					}
				}
			}
		}
	}

	# Convert a (ACN DMS) property data type to a ValueDataType
	static [acn.ddl.ValueDataType] ConvertDataTypeToValueDataType([string]$dataType) {
		switch -regex ($dataType) {
			"acn\.dms\.bset:type\.int(?<size>\d+)"    {	# xsd:int
				return $(if ([int]($matches['size']) -le 32) { [acn.ddl.ValueDataType]::sint } else { [acn.ddl.ValueDataType]::string });			}
			"acn\.dms\.bset:type\.uint(?<size>\d+)"   {	# xsd:unsignedInt
				return $(if ([int]($matches['size']) -le 32) { [acn.ddl.ValueDataType]::uint } else { [acn.ddl.ValueDataType]::string });
			}
			"acn\.dms\.bset:type\.float(?<size>\d+)"  { return [acn.ddl.ValueDataType]::float }	# xsd:double
			"acn\.dms\.bset:type\.bitmap(?<size>\d+)" { return [acn.ddl.ValueDataType]::object }	# hex encoded sequence of octets
		}
		return [acn.ddl.ValueDataType]::string;	# unicode text string
	}

	# Converts a CANopen protocol attributes PSCustomObject as returned by ConvertFrom-Json
	# to an ordered hashtable, as used in this script.
	# @param $object the object to convert
	# @return the ordered hastable with key/values if present, $null if object is $null
	static [System.Collections.Specialized.OrderedDictionary] ConvertPSObjectToCANopenAttrs([PSCustomObject]$object) {
		return [CANopen]::ConvertPSObjectToOrderedHashtable($object,@('index','sub','access'));
	}

	# Converts a PSCustomObject as returned by ConvertFrom-Json to an ordered hashtable,
	#  containing the specified keys (in order).
	# @param $object the object to convert
	# @param $keys the ordered set of keys
	# @return the ordered hastable with key/values if present, $null if object is $null
	static [System.Collections.Specialized.OrderedDictionary] ConvertPSObjectToOrderedHashtable([PSCustomObject]$object,[string[]]$keys) {
		if ($object) {
			$attrs = [ordered]@{}
			# convert PSCustomObject to ordered hashtable
			foreach ($key in $keys) {
				if ($object.PSObject.Properties.Name.Contains($key)) {
					$attrs.$key = $object.$key;
				}
			}
			return $attrs;
		}
		return $null;
	}

	# Export the written data of the writer to file or (pipeline) string.
	# @param $writer the writer with the data
	# @param $path the output path
	# @param $ext the filename extension (specifying the artifact and/or file type)
	# @return FileInfo or string for the pipeline
	static [object] Export([acn.ddl.Writer]$writer, [string]$path, [string]$ext) {
		if ($path) {
			$filename = [CANopen]::GetExportFileName($writer,$path,$ext)
			# make sure the path exists / is created
			
			# make the filename unique, absolute, and valid
			$filename = $filename | New-IncrementalFileName
			# write UTF8 text without BOM
			$writer.FlushToFile($filename)

			write-verbose ("{0,16} {1}" -f "exported",$filename)
			# output the FileInfo object
			return Get-Item $filename
		}
		else {
			write-verbose ("{0,16} {1}" -f "exporting",$writer.CurrentDocument.Name)
			return $writer.FlushToString()
		}
	}
	
	# Write the iniData to the writer
	# @param $writer the text writer
	# @param $sections the ordered hashtable
	static [void] ExportIni([acn.ddl.Writer]$writer, [System.Collections.Specialized.OrderedDictionary]$sections) {
		foreach ($kvp in $sections.GetEnumerator()) {
			$key = $kvp.Key
			$writer.WriteLine(("[{0}]" -f $key))
			if ($kvp.Value) {
				foreach ($kvpi in $kvp.Value.GetEnumerator()) {
					if ($kvpi.Key.StartsWith(";Comment")) {
						$writer.WriteLine((";{0}" -f $kvpi.Value))
					}
					else {
						$writer.WriteLine(("{0}={1}" -f $kvpi.Key,$kvpi.Value))
					}
				}
			}
			$writer.WriteLine()
		}
	}


	# Export a CANopen EDS immediate data section
	# Supported sections:
	# - [DeviceInfo]
	# - [DummyUsage]
	# @param $writer the string writer
	# @param $pgroup the property that holds the immediate properties of the section
	# @param $sectionKey the key of the immediate data section
	static [object] ExportEDSImmediateObjects([acn.ddl.Writer]$writer, [acn.ddl.Appliance]$appliance, [string]$sectionKey)
	{
		$result = $null
		$pg = $appliance.GetProperty("CANopen.EDS.$sectionKey")
		if ($pg) {
			$result = [ordered]@{}
			foreach ($key in [CANopen]::eds.$sectionKey.Keys) {
				$prop = $pg.GetProperty($key)
				if ($prop) {
					$result.$key = $prop.GetValueString()
				}
				if (!$result.$key) {
					# get the value from a propertypointer ('refId')
					$refId = [CANopen]::eds.$sectionKey.$key.refId
					if ($refId) {
						write-verbose ("{0,16} {1}" -f "get",$refId)
						$prop = $appliance.GetProperty($refId)
						if ($prop) {
							$result.$key = $prop.GetValueString()
							write-verbose ("{0,16} {1}" -f "value",$result.$key)
						}
					}
				}
				if (!$result.$key) {
					# write a default value
					$default = [CANopen]::eds.$sectionKey.$key.default
					if ($default) {
						$result.$key = $default
					}
				}
			}
		}
		else {
			write-warning ("{0,16} {1}" -f "undefined","CANopen.EDS.$sectionKey")
			return $null
		}
		return $result
	}
	
	# Optionally, add a description to the EDS section of the object.
	# This is (as far as we know) an emotas CDD/CDE extension of the EDS format.
	# @param writer the EDS writer
	# @param $prop the object property
	# @param $defaultAttrs the default protocol attributes (not used)
	# @param $section the EDS section of the object
	static [void] ExportEDSObjectDescription([acn.ddl.Writer]$writer, [acn.ddl.Property]$prop,
			[hashtable]$defaultAttrs,
			[System.Collections.Specialized.OrderedDictionary]$section)
	{
		# emotas tools extension: object description as double comment in section
		$commentProp = $prop.GetPropertyWithBehavior("acn.dms.bset:description")
		if ($commentProp) {
			$comment = $commentProp.GetValueString()
			$commentLines = $comment.Split(@("`r`n", "`r", "`n"),[StringSplitOptions]::None)
			for ($i = 0; $i -lt $commentLines.Length; $i++) {
				# @todo check max line length
				$section[';Comment' + ($i+1).ToString()] = ";" + $commentLines[$i]
			}
		}
	}

	# Export a CANopen EDS compound property data section
	# @param $writer the string writer
	# @param $propGroup the compound (record or array) property
	# @param $defaultAttrs default protocol attributes
	# @param $sections the export container of EDS sections
	# @param $object the CANopen object EDS section of the compound property
	static [void] ExportEDSCompoundObjects([acn.ddl.Writer]$writer, [acn.ddl.Property]$propGroup,
		[hashtable]$defaultAttrs,
		[System.Collections.Specialized.OrderedDictionary]$sections,
		[System.Collections.Specialized.OrderedDictionary]$object)
	{
		[int]$maxSubIndex = 0
		$maxSubIndexObject = $null
		$maxSubIndexProp = $propGroup.GetPropertyWithBehavior("CANopen.bset:maxSubIndex")
		if (!$maxSubIndexProp) {
			$coa = [CANopen]::GetAttributes($propGroup,$defaultAttrs,0)
			# export the implicit sub-index 0 member
			$object.SubNumber++
			$maxSubIndexObject = [ordered]@{
				ParameterName = $propGroup.GetFullIdentifier($writer.CurrentDocument.Device.Appliance) + ".MaxSubIndex"
				ObjectType = [CANopen]::GetEDSObjectType("CANopen.bset:ObjectCode.VAR");
				DataType = [CANopen]::GetEDSDataType("CANopen.bset:type.UNSIGNED8")
				AccessType = "const"
				PDOMapping = "0"
				DefaultValue = $maxSubIndex
			}
			$sections[[CANopen]::GetCANopenEDSKey($coa.index,0)] = $maxSubIndexObject
		}
		for ($i = 0; $i -lt $propGroup.GetIdentifiedChildNodeCount(); $i++) {
			$node = $propGroup.GetIdentifiedChildNode($i);
			if (($node -is [acn.ddl.Property]) -and ($node.valuetype -eq "network")) {
				$prop = $node
				$coa = [CANopen]::GetAttributes($prop,$defaultAttrs,0)
				if ($coa -and ($coa.objectCode -eq "CANopen.bset:ObjectCode.VAR")) {
					$object.SubNumber++
					$subObject = [ordered]@{
						ParameterName = $prop.GetFullIdentifier($writer.CurrentDocument.Device.Appliance)
						ObjectType = [CANopen]::GetEDSObjectType($coa.objectCode);
					}
					[CANopen]::ExportEDSVariableObject($writer,$prop,$subObject,$coa)
					# emotas tools extension: object description as double comment in section
					[CANopen]::ExportEDSObjectDescription($writer,$prop,$defaultAttrs,$subObject)
					$sections[[CANopen]::GetCANopenEDSKey($coa.index,$coa.subIndex)] = $subObject
					# update the maxSubIndex value
					if ($coa.subIndex -eq 0) {
						if ($maxSubIndexObject.Count -gt 0) {
							throw [InvalidOperationException]::new(("subIndex 0 implicitly and explitly defined on object 0x{0:X4}" -f $coa.index))
						}
						$maxSubIndexObject = $subObject
					}
					if ($maxSubIndex -lt $coa.subIndex) {
						$maxSubIndex = $coa.subIndex
					}
				}
			}
		}
		if ($propGroup.HasArray) {
			$size = $propGroup.ArraySize
			# expand the array entries
			for ($i = 0; $i -lt $size; $i++) {
				$object.SubNumber++
				$coa = [CANopen]::GetAttributes($propGroup,$defaultAttrs,$i)
				$subObject = [ordered]@{
					ParameterName = $propGroup.GetFullIdentifier($writer.CurrentDocument.Device.Appliance) + ("[{0}]" -f $i)
					ObjectType = [CANopen]::GetEDSObjectType("CANopen.bset:ObjectCode.VAR");
				}
				[CANopen]::ExportEDSVariableObject($writer,$propGroup,$subObject,$coa)
				$sections[[CANopen]::GetCANopenEDSKey($coa.index,$coa.subIndex)] = $subObject
				if ($maxSubIndex -lt $coa.subIndex) {
					$maxSubIndex = $coa.subIndex
				}
			}
		}
		if (!$maxSubIndexObject) {
			throw [InvalidOperationException]::new((" no MaxSubIndex object generated for compound object {0}" -f $propGroup.id))
		}
		$maxSubIndexObject.DefaultValue = $maxSubIndex
	}

	# Export a CANopen EDS variable property data section
	# @param $writer the string writer
	# @param $prop the variable property
	# @param $object the CANopen object EDS section of the variable property
	# @param $attrs object attributes
	static [void] ExportEDSVariableObject([acn.ddl.Writer]$writer, [acn.ddl.Property]$prop,
		[System.Collections.Specialized.OrderedDictionary]$object, [hashtable]$attrs)
	{
		$object.DataType = [CANopen]::GetEDSDataType($attrs.dataType)
		$object.AccessType = $attrs.AccessType
		$object.PDOMapping = $attrs.PDOMapping

		if ($attrs.DefaultValue) {
			$object['DefaultValue'] = $attrs.DefaultValue
		}
		if ($attrs.LimitMin) {
			$object['LimitMin'] = $attrs.LimitMin
		}
		if ($attrs.LimitMax) {
			$object['LimitMax'] = $attrs.LimitMax
		}
	}

	# Export a CANopen EDS file.
	# @note Unsupported features:
	# - [DynamicChannels]
	# - [Tools]
	# @pre $writer.CurrentDocument.Device.Appliance is set
	# @param $writer the string writer
	# @param $path the output path
	# @param $list the list of properties with a cia:CANopen and a krohne:GDC protocol specification to export
	static [object] ExportCANopenEDS([acn.ddl.Writer]$writer, [string]$path, [acn.ddl.Appliance]$appliance)
	{
		# type of artifact
		$artifactType = "CANopen"
		$device = $writer.CurrentDocument.Device
		if (![object]::ReferenceEquals($appliance,$device.Appliance)) {
			write-warning "the appliance ($($appliance.id)) must be of the device ($($device.id)) of the writer's current document ($($writer.CurrentDocument.FileInfo))"
		}
		# determine the name of the device
		$name = $device.id
		# get the device label text
		$deviceLabel = $device.GetLabelText($writer.LanguageCode)
		$edsFilename = [System.IO.Path]::GetFileName([CANopen]::GetExportFileName($writer, $Path, ".$artifactType.eds"))
		write-verbose ("{0,16} {1}" -f "writing","CANopen Electronic Data Sheet")
		# create nested ordered hashtable for ini-export
		$sections = [ordered]@{}
		# [FileInfo]
		$now = [DateTime]::Now
		$date = $now.ToString("MM-dd-yyyy",[CultureInfo]::InvariantCulture)
		$time = $now.ToString("hh:mmtt",[CultureInfo]::InvariantCulture)
		$sections.FileInfo = [ordered]@{
			FileName = $edsFilename
			FileVersion = '1'	# @todo use the VersionMajor of the device description
			FileRevision = '0'	# @todo use the VersionMinor of the device description
			EDSVersion = [CANopen]::eds.version
			Description = "EDS of the $deviceLabel"
			CreationTime = $time
			CreationDate = $date
			CreatedBy = $env:USERNAME
			ModificationTime = $time
			ModificationDate = $date
			ModifiedBy = $env:USERNAME
		}
		# [Comments]
		$comments = $appliance.GetProperty("CANopen.EDS.Comments")
		if ($comments) {
			$value = $comments.GetValueString().Split(@("`r`n", "`r", "`n"),[StringSplitOptions]::None)
			if ($value) {
				$sections.Comments = [ordered]@{ Lines=$value.Length.ToString() }
				for ($i = 0; $i -lt $value.Length; $i++) {
					# @todo check max line length
					$sections.Comments['Line' + ($i+1).ToString()] = $value[$i]
				}
				write-verbose ("{0,16} {1} " -f $value.Length,"comment lines exported")
			}
		}
		# [DeviceInfo]
		$sections.DeviceInfo = [CANopen]::ExportEDSImmediateObjects($writer,$appliance,'DeviceInfo')
		# [DummyUsage]
		$sections.DummyUsage = [CANopen]::ExportEDSImmediateObjects($writer,$appliance,'DummyUsage')
		# collect the CANopen properties of the device appliance
		$list = [System.Collections.Generic.SortedDictionary[[string],[acn.ddl.Property]]]::new()
		[CANopen]::CollectProtocolProperties($list,$appliance,[CANopen]::protocolDefinition.CANopen,@{})
		# map the properties to the three CANopen object sections
		$sections.MandatoryObjects = [ordered]@{ SupportedObjects = 0; }
		$sections.OptionalObjects = [ordered]@{ SupportedObjects = 0; }
		$sections.ManufacturerObjects = [ordered]@{ SupportedObjects = 0; }
		$defaultAttrs = @{}
		foreach ($kvp in $list.GetEnumerator()) {
			$prop = $kvp.Value
			$coa = [CANopen]::GetAttributes($prop,$defaultAttrs,0)
			if (![acn.CANopen.ObjectDictionary]::IsDataObject($coa.index)) {
				# skip index=0 and type definitions for export
				continue
			}
			if ($coa.hasSubIndex -and !$prop.HasArray) {
				# skip compound members (are exported as members)
				continue
			}
			write-verbose ("{0,16} {1}" -f $kvp.Key,$prop.id)
			# register the object in the appropriate list
			if ([acn.CANopen.ObjectDictionary]::IsManufacturerObject($coa.index)) {
				$section = $sections.ManufacturerObjects
			}
			else {
				if ([acn.CANopen.ObjectDictionary]::IsMandatoryObject($prop)) {
					$section = $sections.MandatoryObjects
				}
				else {
					$section = $sections.OptionalObjects
				}
			}
			$section.SupportedObjects++
			$section[$section.SupportedObjects.ToString()] = ("0x{0:X4}" -f $coa.index)
			# construct the object section
			$object = [ordered]@{
				ParameterName = $prop.GetFullIdentifier($device.Appliance);
				ObjectType = [CANopen]::GetEDSObjectType($coa.objectCode);
			}
			if ($prop.IsCompound()) {
				$object.SubNumber = 0
				[CANopen]::ExportEDSObjectDescription($writer,$prop,$defaultAttrs,$object)
				# expand the subproperties or array
				$sections[[CANopen]::GetCANopenEDSKey($coa.index,$null)] = $object
				[CANopen]::ExportEDSCompoundObjects($writer,$prop,$defaultAttrs,$sections,$object)
			}
			else {
				[CANopen]::ExportEDSVariableObject($writer,$prop,$object,$coa)
				[CANopen]::ExportEDSObjectDescription($writer,$prop,$defaultAttrs,$object)
				$sections[[CANopen]::GetCANopenEDSKey($coa.index,$null)] = $object
			}
		}		
		
		# CiA 306-3 DynamicChannels
		# $sections.DeviceInfo.DynamicChannelsSupported = 0
		# $sections.DynamicChannels = [ordered]@{}
		# CiA 306-3 Tools
		# $sections.Tools = [ordered]@{ Items=0; }
		# $sections.Tool1 = [ordered]@{ Name="Import-CANopenToAcn"; Command=""; }
		# write ini file
		$writer.WriteLine(("; EDS file for {0} - generated by {1}" -f $device.id,[CANopen]::eds.generatorName))
		[CANopen]::ExportIni($writer, $sections)
		return [CANopen]::Export($writer,$path,".$artifactType.eds");
	}


	# Export an emotas CANopen Device Designer (CDD) configuration file for the specified appliance.
	# The CDD configuration file is a CSV file for importing the CANopen configuration into
	# the emotas CANopen Device Designer (CDD).
	# The appliance should be the appliance of the current device of the writer.
	# @param $writer the string writer
	# @param $path the output path
	# @param $appliance the device appliance to write the configuration of
	static [object] ExportEmotasCDDConfiguration([acn.ddl.Writer]$writer, [string]$path, [acn.ddl.Appliance]$appliance)
	{
		$device = $writer.CurrentDocument.Device
		if (![object]::ReferenceEquals($appliance,$device.Appliance)) {
			write-warning "the appliance ($($appliance.id)) must be of the device ($($device.id)) of the writer's current document ($($writer.CurrentDocument.FileInfo))"
		}
		$list = [System.Collections.Generic.SortedDictionary[[string],[acn.ddl.Property]]]::new()
		[CANopen]::CollectProtocolProperties($list,$appliance,[CANopen]::protocolDefinition.CANopen,@{})
		write-verbose ("{0,16} {1}" -f "writing","emotas CDD configuration")
		
		# start building the output
		$fields = [CANopen]::emotasCDDHeader -split ','
		# write the header line
		$writer.WriteCSVLine($fields)
		$entry = @{}
		$defaultAttrs = @{}
		foreach ($kvp in $list.GetEnumerator()) {
			$prop = $kvp.Value
			$propId = $prop.id
			if (!$prop.HasNetworkValue() -and !$prop.HasNullValue()) {
				# skip simple properties without network access
				continue
			}
			$coa = [CANopen]::GetAttributes($prop,$defaultAttrs,0)
			if (![acn.CANopen.ObjectDictionary]::IsObject($coa.index)) {
				# skip index=0 for export
				continue
			}
			if ($prop.IsCompound()) {
				# determine the actual maxSubIndex value
				$maxSubIndex = [CANopen]::GetCompoundMaxSubIndex($prop)
				# determine explicit or implicit MaxSubIndex specification
				$maxSubIndexProp = $prop.GetPropertyWithBehavior("CANopen.bset:maxSubIndex")
				if ($maxSubIndexProp) {
					if (!$maxSubIndexProp.HasNetworkValue()) {
						# no network access
						continue;
					}
					# get the attributes from the explicit MaxSubIndex
					$msicoa = [CANopen]::GetAttributes($maxSubIndexProp,$defaultAttrs,0)
					# verify the MaxSubIndex value
					if ($maxSubIndex -ne $msicoa.DefaultValue) {
						write-host ("invalid explicit MaxSubIndex value '{0}' on '{1}', expected '{2}'" -f $msicoa.DefaultValue,$prop.id,$maxSubIndex) -foregroundcolor Red
						# correct the value
						$msicoa.DefaultValue = $maxSubIndex
					}
					[CANopen]::ExportEmotasCDDObject($writer,$prop,$appliance,$entry,$msicoa)
				}
				else {
					# are there any 'members' with network access?
					if ($maxSubIndex -le 0) {
						continue;
					}
					# no explicit MaxSubIndex: determine implicit MaxSubIndex attributes
					$coa.dataType = "acn.dms.bset:type.uint8"
					$coa.isConstant = $true
					$coa.access = "ro"
					$coa.DefaultValue = $maxSubIndex
					$coa.LimitMin = [CANopen]::DMSDataType[$coa.dataType].min
					$coa.LimitMax = [CANopen]::DMSDataType[$coa.dataType].max
					[CANopen]::ExportEmotasCDDObject($writer,$prop,$appliance,$entry,$coa)
				}
				# fix some object entry values
				# - the ObjectCode from the compound i.s.o. VAR
				$entry.ObjectCode = [CANopen]::GetObjectCodeName($coa.ObjectCode)
				# write the MaxSubIndex line of the compound
				$writer.WriteCSVLine($fields,$entry)

				if ($prop.HasArray) {
					# expand array: write the array members
					write-verbose ("{0,16} {1} (array[{2}])" -f $kvp.Key,$prop.id,$prop.ArraySize)
					for ($i = 0; $i -lt $prop.ArraySize; $i++) {
						$coa = [CANopen]::GetAttributes($prop,$defaultAttrs,$i)
						[CANopen]::ExportEmotasCDDObject($writer,$prop,$appliance,$entry,$coa)
						$entry.edsname = ("{0}[{1}]" -f $entry.edsname,$i)
						$entry.ObjectCode = ""	# $objectCode is ARRAY but do not specify with members
						$entry.description = ""	# $description once is enough
						$writer.WriteCSVLine($fields,$entry)
					}
				}
				else {
					write-verbose ("{0,16} {1} (compound with {2} members)" -f $kvp.Key,$propId,$maxSubIndex)
				}
			}
			elseif ($prop.HasBehavior("CANopen.bset:maxSubIndex")) {
				# suppress explicit MaxSubIndex (is already written)
				write-verbose ("{0,16} {1}" -f $kvp.Key,$propId)
			}
			else {
				write-verbose ("{0,16} {1}" -f $kvp.Key,$propId)
				# property is VAR, either a compound member, or a single property
				[CANopen]::ExportEmotasCDDObject($writer,$prop,$appliance,$entry,$coa)
				$writer.WriteCSVLine($fields,$entry)
			}
			
		}
		return [CANopen]::Export($writer,$path,".cdd-import.csv")
	}

	# Export a emotas CANopen Device Designer property object
	# @param $writer the string writer
	# @param $property the property
	# @param $appliance the appliance of the property
	# @param $object the CANopen object of the property
	# @param $attrs CANopen object attributes (extracted from the ACN DDL model)
	static [void] ExportEmotasCDDObject([acn.ddl.Writer]$writer, [acn.ddl.Property]$property, [acn.ddl.Appliance]$appliance,
		#[System.Collections.Specialized.OrderedDictionary]$object, [hashtable]$attrs)
		[hashtable]$object, [hashtable]$attrs)
	{
		$object.index = ("0x{0:X4}" -f $attrs.index)
		$object.sub = $attrs.subIndex
		$object.edsname = $property.GetFullIdentifier($appliance)
		try {
			$object.datatype = [CANopen]::GetDataTypeName($attrs.dataType)
		}
		catch {
			throw [InvalidOperationException]::new("no CANopen DataType found for '$($attrs.dataType)' on property '$($property.id)'")
		}
		$object.access = $attrs.access	# or AccessType if you want to include 'const'
		$object.value = ""
		$object.varname = ""			# do not specify "NONE" since DD will switch to 'Variable' in that case
		$object.LowLimit = ""
		$object.UpLimit = ""
		$object.hasDefault = "0"		# define boolean values like hasDefault with 0 and 1, i.s.o. "no" and "yes"
		if ($attrs.DefaultValue) {
			$object.value = $attrs.DefaultValue
			$object.hasDefault = "1"	# "yes"
		}
		if ($attrs.LimitMin) {
			$object.LowLimit = $attrs.LimitMin
		}
		elseif ([CANopen]::DMSDataType[$attrs.dataType].isNumber) {
			$object.LowLimit = [CANopen]::DMSDataType[$attrs.dataType].min
		}
		if ($attrs.LimitMax) {
			$object.UpLimit = $attrs.LimitMax
		}
		elseif ([CANopen]::DMSDataType[$attrs.dataType].isNumber) {
			$object.UpLimit = [CANopen]::DMSDataType[$attrs.dataType].max
		}
		$object.hasLimit = if (($object.UpLimit -ne "") -or ($object.LowLimit -ne "")) { "1" } else { "0" }
		$object.refuseRead = "1"		# refuseRead (input not supported)
		$object.refuseWrite = "1"		# refuseWrite (input not supported)
		$object.defaultInEDS = "1"		# 0 = No, 1 = AsDefaultValue, 2 = Yes
		# @note access == 'const' will imply ManagedConst
		if ($attrs.isConstant -or ($attrs.AccessType -eq "const")) {
			$object.implementationType = "ManagedConst"
		}
		else {
			$object.implementationType = "ManagedVariable"
		}
		$object.size = 0
		$object.ObjectCode = [CANopen]::GetObjectCodeName($attrs.objectCode)	# default is VAR, presumably
		if ($object.objectCode -eq "VAR") {
			$object.objectCode = ""	# suppress VAR, is default
		}
		$object.mapable = switch ($attrs.pdo) {
		"t" { "tpdo"; break }
		"r" { "rpdo"; break }
		"no" { ""; break }		# default value, leave empty
		"tr" { "both"; break }
		}
		$object.description = ""
		# since CDD version 3.6.0.4 support per (sub)index
		$descr = $property.GetPropertyWithBehavior("acn.dms.bset:description")
		if ($descr) {
			# only single line, simple stuff (without delimiters, so replace COMMA and NEWLINE)
			$object.description = $descr.GetValueString() -replace "[,\n]"," - "
		}

		# string type property specifics
		if ($attrs.dataType -eq "acn.dms.bset:type.string") {
			# determine string object implementation based on the access specifier of the protocol (const vs. ro,rw)
			# @todo determine other way of specifying, e.g. by specifying varname
			if ($attrs.AccessType -eq "const") {
				$object.implementationType = "ManagedConst"
			}
			else {
				$object.implementationType = "Variable"
			}
			$maxcodeunits = $property.GetPropertyWithBehavior("acn.dms.bset:limitMaxCodeUnits")
			if ($maxcodeunits) {
				$object.size = $maxcodeunits.GetValueString()
			}
			else {
				# if a const with initializer: use length of initializer as size
				if ($attrs.isConstant) {
					if ($object.value) {
						# although VISIBLE_STRING is only ASCII, we allow UTF8 here
						$object.size = [System.Text.Encoding]::UTF8.GetBytes($object.value).Length
					}
					else {
						$object.size = 0;
					}
				}
				else {
					throw [InvalidOperationException]::new(("MaxCodeUnits not specified on string property '{0}'" -f $property.id));
				}
			}
			# @todo put this in the (adjunct) data (e.g. as variableName subproperty
			$object.varname = "IOPal.stringBuffer"
		}
		# explicit implementation variable name specification
		$variableName = $property.GetPropertyWithBehavior("acn.dms.bset:variableName")
		if ($variableName) {
			# application variable specified
			$object.varname = $variableName.GetValueString()
			$object.implementationType = "Variable"
		}
	}

	# Write a C source and header file for translating CANopen SDO indications to GDC requests.
	# @param $writer the string writer
	# @param $Path the output path
	# @param $list the list of properties with a cia:CANopen and a krohne:GDC protocol specification to export
	static [object[]] ExportCANopenToGDCTranslationTable([acn.ddl.Writer]$writer,[string]$Path,
			[System.Collections.Generic.SortedDictionary[[string],[acn.ddl.Property]]]$list)
	{
		$result = @('source','header')
		# type of artifact
		$artifactType = "CANopenGDC"
		$device = $writer.CurrentDocument.Device
		# determine the name of the device
		$name = $device.id
		# get the device label text
		$deviceLabel = $device.GetLabelText($writer.LanguageCode)
		# convert device name to a valid C identifier
		$cname = [acn.ddl.Writer]::ConvertToCIdentifier($name)
		$headerFilename = [System.IO.Path]::GetFileName([CANopen]::GetExportFileName($writer, $Path, ".$artifactType.h"))
		$headerGuard = [acn.ddl.Writer]::ConvertToCIdentifier($headerFilename)
		$sourceFilename = [System.IO.Path]::GetFileName([CANopen]::GetExportFileName($writer, $Path, ".$artifactType.c"))
		$date = get-date -format "yyyy-MM-dd"
		write-verbose ("{0,16} {1}" -f "writing","CANopen-to-GDC translation table")
		# read the fileHeaderLogo from the associated languageset
		$fileHeader = ""
		$langset = $device.GetOrLoadLanguageSet();
		if ($langset) {
			$logo = $langset.GetStringText("product.logo.ascii");
			if ($logo) {
				$fileHeader = "`n$logo`n"
			}
			$copy = $langset.GetStringText("product.copyright");
			if ($copy) {
				$fileHeader += "`n$copy`n"
			}
			if ($fileHeader) {
				$fileHeader = "//" + $fileHeader.Replace("`n","`n// ")
				$writer.WriteLine($fileHeader);
			}
		}
			
		$writer.WriteLine(([CANopen]::sourceBegin -f $sourceFilename,$deviceLabel,$date,$headerFilename,$cname));

		# get a sorted list of CANopen properties that also have a GDC protocol attached
		# and generate the translation table for the IOPal interface
		$itemCount = 0
		foreach ($kvp in $list.GetEnumerator()) {
			$prop = $kvp.Value
			$propId = $prop.id
			$canopen = $prop.GetProtocol([CANopen]::protocolDefinition.CANopen.id)
			$gdc = $prop.GetProtocol([CANopen]::protocolDefinition.GDC.id)
			if (!$canopen -or !$gdc) {
				continue
			}
			write-verbose ("{0,16} {1}" -f $kvp.Key,$propId)
			# determine the data type size
			$type = $prop.FindBehavior("acn.dms.bset","type.")
			if (!$type) {
				throw [InvalidOperationException]::new(("cannot find the ACN DMS data type of property '{0}'" -f $prop.id));
				continue
			}
			$typeName = $type.ToString()
			$dataType = [CANopen]::DMSDataType[$type.ToString()]
			if (!$dataType) {
				throw [InvalidOperationException]::new(("unsupported data type of property '{0}': {1}" -f $prop.id,$type.ToString()));
				continue
			}
			$size = $dataType.size
			if ($typeName -eq "acn.dms.bset:type.string") {
				$maxcodeunits = $prop.GetProperty("$propId.MaxCodeUnits")
				if (!$maxcodeunits) {
					throw [InvalidOperationException]::new(("MaxCodeUnits not specified on string property '{0}'" -f $prop.id));
				}
				$size = $maxcodeunits.GetValueString()
			}
			$dataTypeCode = $dataType.code
			if ($prop.HasArray) {
				# handle array properties
				for ($i = 0; $i -lt $prop.ArraySize; $i++) {
					$canAttrs = $canopen.GetElement([CANopen]::protocolDefinition.CANopen.qname,$i)
					if (!$canAttrs -or ($canAttrs.GetAttribute("sub") -in "","0")) {
						# single specification
						$canAttrs = $canopen.GetElement([CANopen]::protocolDefinition.CANopen.qname)
						$index = $canAttrs.GetAttribute("index")
						$subIndex = $i + 1
					}
					else {
						$index = $canAttrs.GetAttribute("index")
						$subIndex = $canAttrs.GetAttribute("sub")
					}
					$gdcAttrs = $gdc.GetElement([CANopen]::protocolDefinition.GDC.qname,$i)
					if (!$canAttrs -or !$gdcAttrs) {
						throw [InvalidOperationException]::new(("missing GDC or CANopen protocol specification on property {0}[{1}]" -f $prop.id,$i));
					}
					$objectNo = $gdcAttrs.GetAttribute("objectNo")
					$subNo = $gdcAttrs.GetAttribute("subNo")
					if ([string]::IsNullOrEmpty($subNo)) {
						$subNo = "0"
					}
					$writer.WriteLine(("	{{ {0}, {1,3}, {2,5:d}, {3,2:d}, {4,10}, {5,2:d} }},	// {6}[{7}]" -f $index,$subIndex,$objectNo,$subNo,$dataTypeCode, $size, $prop.id,$i))
					$itemCount++
				}
			}
			else {
				$canAttrs = $canopen.GetElement([CANopen]::protocolDefinition.CANopen.qname)
				$gdcAttrs = $gdc.GetElement([CANopen]::protocolDefinition.GDC.qname)
				if (!$canAttrs -or !$gdcAttrs) {
					throw [InvalidOperationException]::new(("missing GDC or CANopen protocol specification on property {0}" -f $prop.id));
				}
				$index = $canAttrs.GetAttribute("index")
				$subIndex = $canAttrs.GetAttribute("sub")
				$objectNo = $gdcAttrs.GetAttribute("objectNo")
				$subNo = $gdcAttrs.GetAttribute("subNo")
				if ([string]::IsNullOrEmpty($subNo)) {
					$subNo = "0"
				}
				$writer.WriteLine(("	{{ {0}, {1,3}, {2,5:d}, {3,2:d}, {4,10}, {5,2:d} }},	// {6}" -f $index,$subIndex,$objectNo,$subNo,$dataTypeCode,$size,$prop.id))
				$itemCount++
			}
		}


#	{ /* DI[0x01770] */ DI, 6000, 1, pnKrohne_MPhase5000_Controller_SIM_KMP_Gap, &Meter1.Controller.SIM.KMP.Gap },

		$writer.WriteLine([string]::Format([CANopen]::sourceEnd,$deviceLabel,$cname));
		$result[0] = [CANopen]::Export($writer,$Path,".$artifactType.c");

		# create a C header file
		if ($fileHeader) {
			$writer.WriteLine($fileHeader);
		}
		$writer.WriteLine(([CANopen]::header -f $headerFilename,$deviceLabel,$date,$headerGuard,$cname,$itemCount));
		$result[1] = [CANopen]::Export($writer,$Path,".$artifactType.h")
		return $result
	}

	# Safely get the adjunct data of the specified group member, $default if not present
	# @param $group the AdjunctData group
	# @param $member the AdjunctData group member to get
	# @param $default the value to return in case there is no AdjunctData for this group member
	static [object] getAdjunctData([string]$group,[string]$member,[object]$default = $null) {
		# ComvertFrom-Json returns PSCustomObjects in stead of hashtables, so checking for presence without exceptions is a bit more complex
		if ([CANopen]::adjunctData -and [CANopen]::adjunctData.PSObject.Properties.Name.Contains($group) -and [CANopen]::adjunctData.$group.PSObject.Properties.Name.Contains($member)) {
			return [CANopen]::adjunctData.$group.$member
		}
		return $default
	}

	# Safely get the adjunct data of the specified group member, $null if not present
	# @param $group the AdjunctData group
	# @param $member the AdjunctData group member to get
	static [object] getAdjunctData([string]$group,[string]$member) {
		return [CANopen]::getAdjunctData($group,$member,$null);
	}
	
	# Get the CANopen protocol attributes on the specified property.
	# @param $property the property to get the CANopen protocol attributes of
	# @param $defaultAttrs default values of specific attributes
	# @param $index the array index of the (array) property
	# @return the attributes as hashtable
	# @exception InvalidOperationException in case the property has no CANopen attributes
	static [hashtable] GetAttributes([acn.ddl.Property]$property, [hashtable]$defaultAttrs, [int]$index = 0) {
		$result = [CANopen]::GetProtocolAttributes($property,[CANopen]::protocolDefinition.CANopen,$index)
		if (!$result) {
			throw [InvalidOperationException]::new(("property '{0}' has no CANopen protocol attributes" -f $property.id))
		}
		if ($result) {
			# determine the nodeID (normally not present, only in includedev elements)
			if ($result.node) {
				write-verbose ("{0,16} {1}: {2}" -f "node",$result.node,$property.id)
				$defaultAttrs.node = $result.node
			}
			if ([acn.CANopen.ObjectDictionary]::IsObject($result.index)) {
				$propId = $property.Id
				[int]$result.nodeID = $defaultAttrs.node
				# index and subIndex as [int]
				[int]$result.index = $result.index
				[int]$result.subIndex = $result.sub
				$result.hasSubIndex = ![string]::IsNullOrEmpty($result.sub)
				$result.objectCode = [CANopen]::GetObjectCode($property)
				$result.label = $property.GetProperty("$propId.Label")
				if ($result.label) {
					$result.label = $result.label.GetValueString($index)
				}
				if (!$result.label) {
					$result.label = $property.GetLabelText()
				}
				if ($property.HasArray) {
					if (!$result.hasSubIndex) {
						# expand array sub-index: assign the array-index + 1
						[int]$result.subIndex = $index + 1
					}
				}
				# determine the data type
				if ($property.valuetype -ne [acn.ddl.PropertyValueType]::NULL) {
					$result.dataType = [CANopen]::GetDataType($property)
				}
				$result.isConstant = $property.HasConstantValue()
				$result.DefaultValue = $property.GetPropertyWithBehavior("acnbase.bset:initializer")
				$result.LimitMin = $property.GetPropertyWithBehavior("acnbase.bset:limitMinInc")
				$result.LimitMax = $property.GetPropertyWithBehavior("acnbase.bset:limitMaxInc")
				if ($result.DefaultValue) {
					$result.DefaultValue = $result.DefaultValue.GetValueString($index)
				}
				if ($result.LimitMin) {
					$result.LimitMin = $result.LimitMin.GetValueString($index)
				}
				if ($result.LimitMax) {
					$result.LimitMax = $result.LimitMax.GetValueString($index)
				}
				if ($property.valuetype -eq [acn.ddl.PropertyValueType]::network) {
					# determine SDO and PDO access
					# determine traditional 'access'
					if (!$result.access) {
						# default value of sdo access
						$result.access = if ($result.isConstant) { "ro" } else { "rw" }
					}
					# translate deprecated 'const' value
					if ($result.access -eq "const") {
						$result.access = "ro"
					}
					if (!$result.sdo) {
						# determine SDO access
						$result.sdo = [CANopen]::eds.AccessType[$result.access].sdo
					}
					if (!$result.pdo) {
						$result.pdo = $property.FindBehavior("CANopen.bset","pdo.")
						if ($result.pdo) {
							# delete the 'pdo.' part of the behavior name
							$result.pdo = $result.pdo.name.replace("tpo.",'')
						}
					}
					if (!$result.pdo) {
						$result.pdo = "no"
					}
					# EDS specific attributes
					$result.AccessType = $result.access
					if (($result.AccessType -eq "ro") -and $result.isConstant) {
						$result.AccessType = "const"
					}
					$result.PDOMapping = switch ($result.pdo) {
						"t" { "1"; if ($result.AccessType -eq "rw") { $result.AccessType = "rwr" }; break }
						"r" { "1"; if ($result.AccessType -eq "rw") { $result.AccessType = "rww" }; break }
						"no" { "0"; break }
						"tr" { "1"; break }
						default { "0"; break }
					}
				}
			}
		}
		return $result
	}

	# Get the key for sorting the property in the list of CANopen object dictionary index
	static [string] GetCANopenKey([int]$nodeID, [int]$index, [string]$subIndex) {
		if (($index -lt 0x0000) -or ($index -gt 0xFFFF)) {
			throw [ArgumentException]::new("invalid CANopen object index value: $index","index")
		}
		if ($subIndex) {
			[int]$sub = $subIndex
			if (($sub -lt 0) -or ($sub -gt 255)) {
				throw [ArgumentException]::new("invalid CANopen object sub-index value: $sub","subIndex")
			}
			return "{0:X2}:{1:X4}:{2:X2}" -f $nodeID,$index,$sub
		}
		return "{0:X2}:{1:X4}:  " -f $nodeID,$index
	}

	# Get the key of the EDS section of the CANopen object
	# @param $index the CANopen Object Dictionary object index
	# @param $subIndex the (optional) CANopen Object Dictionary object sub-index
	static [string] GetCANopenEDSKey([int]$index, [string]$subIndex = $null) {
		if (($index -le 0x0000) -or ($index -gt 0xFFFF)) {
			throw [ArgumentException]::new("invalid CANopen object index value: $index","index")
		}
		if ($subIndex) {
			[int]$sub = $subIndex
			if (($sub -lt 0) -or ($sub -gt 255)) {
				throw [ArgumentException]::new("invalid CANopen object sub-index value: $sub","subIndex")
			}
			return "{0:X}sub{1:X}" -f $index,$sub
		}
		return "{0:X}" -f $index
	}
	
	# Get the CANopen MaxSubIndex value of the specified compound property
	static [int] GetCompoundMaxSubIndex([acn.ddl.Property]$property) {
		$result = 0
		if ($property.IsCompound()) {
			if ($property.HasArray) {
				$result = $property.ArraySize
			}
			else {
				$coa = [CANopen]::GetProtocolElement($property,[CANopen]::protocolDefinition.CANopen)
				$index = $coa.GetAttribute("index")
				$value = [int]0
				for ($i = 0; $i -lt $property.GetIdentifiedChildNodeCount(); $i++) {
					$node = $property.GetIdentifiedChildNode($i);
					if (($node -is [acn.ddl.Property]) -and ($node.valuetype -eq "network")) {
						$coattrs = [CANopen]::GetProtocolElement($node,[CANopen]::protocolDefinition.CANopen)
						if ($coattrs -and ($coattrs.GetAttribute('index') -eq $index)) {
							$sub = [int]$coattrs.GetAttribute('sub')
							if (($sub -gt $result) -and ($sub -lt 255)) {
								$result = $sub;
							}
						}
					}
				}
			}
		}
		return $result
	}

	# Get the datatype behavior for the specified property.
	# @param $property a property
	# @return the datatype behavior qname.
	static [string] GetDataType([acn.ddl.Property]$property) {
		$result = $property.FindBehavior("acn.dms.bset","type.")
		if (!$result) {
			throw [InvalidOperationException]::new("no datatype found for property '$($property.id)'")
		}
		return $result.ToString()
	}

	# Get the CANopen DataType for the specified datatype behavior identifier
	static [string] GetDataTypeName([string]$behavior) {
		if (!$behavior) {
			# no datatype 
			throw [InvalidOperationException]::new("no datatype specified")
		}
		$result = [CANopen]::protocolDefinition.CANopen.DataType[$behavior]
		if (!$result) {
			throw [InvalidOperationException]::new("no CANopen DataType found for behavior '$behavior'")
		}
		return $result
	}

	# Get the EDS DataType for the specified datatype behavior identifier.
	# @param $behavior datatype behavior or CANopen datatype
	static [string] GetEDSDataType([string]$behavior) {
		$datatype = [CANopen]::GetDataTypeName($behavior)
		if (!$datatype) {
			# no datatype 
			throw [InvalidOperationException]::new("no CANopen datatype specified or found for behavior '$behavior'")
		}
		$result = [CANopen]::eds.DataType[$datatype]
		if (!$result) {
			throw [InvalidOperationException]::new("no CANopen EDS DataType found for behavior '$behavior'")
		}
		return $result
	}

	# Get the behavior identifier of the specified EDS DataType
	static [string] GetEDSDataTypeBehavior([string]$edsDataType) {
		if (!$edsDataType) {
			# no default value
			throw [InvalidOperationException]::new("no datatype specified")
		}
		# normalize integer value (might be hex 0x00)
		$edsDataType = ([int]$edsDataType).ToString()
		return [CANopen]::eds.DataTypeBehavior[$edsDataType]
	}

	# Get the CANopen ObjectCode behavior for the specified property.
	# @param $prop a property with CANopen protocol
	# @return the ObjectCode represented as behavior identifier.
	static [string] GetObjectCode([acn.ddl.Property]$prop) {
		$result = $prop.FindBehavior("CANopen.bset","ObjectCode.")
		if (!$result) {
			# no objecttype 
			$result = "CANopen.bset:ObjectCode.VAR"
		}
		return $result.ToString()
	}

	# Get the CANopen ObjectCode name of the specified ObjectCode behavior.
	# @param $behavior the CANopen.bset:ObjectCode.* behavior
	# return the ObjectCode represented by the behavior identifier.
	static [string] GetObjectCodeName([string]$behavior) {
		$bset,$objectCode = $behavior -split ":ObjectCode\."
		if ($bset -ne "CANopen.bset") {
			throw [InvalidOperationException]::new(("invalid CANopen behaviorset: '{0}'" -f $bset))
		}
		return $objectCode
	}

	# Get the EDS ObjectType for the specified ObjectCode behavior identifier
	static [string] GetEDSObjectType([string]$behavior) {
		if (!$behavior) {
			# no objecttype 
			$behavior = "CANopen.bset:ObjectCode.VAR"
		}
		$result = [CANopen]::eds.ObjectCode[$behavior]
		if (!$result) {
			throw [InvalidOperationException]::new("no EDS ObjectType found for behavior '$behavior'")
		}
		return $result.ObjectType
	}

	# Get the ObjectCode behavior identifier of the specified EDS ObjectType
	static [string] GetEDSObjectTypeCode([string]$edsObjectType) {
		if (!$edsObjectType) {
			# default value: VAR
			$edsObjectType = "7"
		}
		# normalize integer value (might be hex 0x00)
		$edsObjectType = ([int]$edsObjectType).ToString()
		return [CANopen]::eds.ObjectTypeCode[$edsObjectType]
	}

	# Determine the export filename for the current document.
	# @param $writer the writer attached to the document to write
	# @param $path the output path
	# @param $ext the filename extension (specifying the artifact and/or file type)
	static [string] GetExportFileName([acn.ddl.Writer]$writer, [string]$path, [string]$ext) {
		if ($path) {
			# @todo assess if this functionality should be canonicalized (i.e. if no base name, insert document name as such)
			if ([nl.nlsw.Document.Utility]::PathMacroRegex.IsMatch($path)) {
				# expand any document info macros
				$filename = $path | Expand-ItemObjectMacros $writer.CurrentDocument
			}
			else {
				# if no file base name specified, use the document name as base name
				$foldername = [System.IO.Path]::GetDirectoryName($path)
				$filename = [System.IO.Path]::GetFileName($path)
				# remove extension to get the base name
				$filename = [System.IO.Path]::ChangeExtension($filename,$null)
				if ([string]::IsNullOrEmpty($filename)) {
					$filename = [acn.ddl.Writer]::ConvertXmlNameToFilenameString($writer.CurrentModule.id)
					if ([string]::IsNullOrEmpty($filename)) {
						$filename = $writer.CurrentModule.UUID
						if ([string]::IsNullOrEmpty($filename)) {
							# no path with filename provided, and module has no id and not even a UUID: give up
							throw [InvalidOperationException]::new(("no name specified for the '{0}' file to export" -f $ext))
						}
					}
					# append dummy filename extension, otherwise a part of the name may be replaced later
					$filename += "."
				}
				$filename = [System.IO.Path]::Combine($foldername,$filename)
			}
			# append the proper document and file type
			$filename = [System.IO.Path]::ChangeExtension($filename,$ext)
			return $filename
		}
		else {
			return $null
		}
	}

	# Get the adjunct data of the specified GDC object, $null if not present
	# @param $objectNo the GDC object number
	# @param $member the name of the member of the adjunct data of the object to return
	# @return the adjunct data of the field the object, $null if not present
	static [object] getObjectMember([string]$objectNo,[string]$member) {
		return [CANopen]::getObjectMember($objectNo,$member,$null);
	}

	# Get the adjunct data of the specified GDC object, $default if not present
	# @param $objectNo the GDC object number
	# @param $member the name of the member of the adjunct data of the object to return
	# @param $default the default value to return if no adjunct data is present
	# @return the adjunct data of the field the object, $default if not present
	static [object] getObjectMember([string]$objectNo,[string]$member,[object]$default) {
		[object] $object = [CANopen]::getObject($objectNo);
		if ($object -and $object.PSObject.Properties.Name.Contains($member)) {
			return $object.$member
		}
		return $default
	}

	# Get the adjunct data of the specified GDC object, $null if not present
	# @param $objectNo the GDC object number
	# @return the adjunct data on the object, $null of not present
	static [object] getObject([string]$objectNo) {
		return [CANopen]::getAdjunctData('GDCObject',$objectNo);
	}

	# Constructor for a device document
	static [acn.ddl.Document] GetOrCreateDeviceDocument([acn.ddl.Reader]$reader, [string]$moduleName, [string]$label) {
		$doc = $reader.CurrentDocumentList.GetDocumentByModuleName($moduleName)
		if ($doc) {
			write-verbose ("{0,16} module {1}" -f "using",$doc.RootNode.Module.id)
		}
		else {
			$doc = $reader.CurrentDocumentList.GetOrLoadDocumentByModuleName($moduleName)
			if ($doc) {
				write-verbose ("{0,16} {1}" -f "loaded",$doc.FileInfo.FullName)
			}
			else {
				$doc = $reader.CurrentDocumentList.NewDevice($moduleName,$label,[CANopen]::provider,[CANopen]::module[$moduleName])
				write-verbose ("{0,16} new device module {1}" -f "created",$doc.RootNode.Module.id)
			}
		}
		return $doc
	}
	
	# Get the protocol attributes of the specified protocol on the specified property.
	static [System.Xml.XmlElement] GetProtocolElement([acn.ddl.Property]$property, [PSCustomObject]$protocol, [int]$index = 0) {
		$proto = $property.GetProtocol($protocol.id);
		if ($proto) {
			$result = $proto.GetElement($protocol.qname,$index);
			if (!$result) {
				if ($index -gt 0) {
					# single attribute element (we guess), return that
					$result = $proto.GetElement($protocol.qname,0);
				}
			}
			return $result
		}
		return $null
	}

	# Get the protocol attributes of the specified protocol on the specified property.
	static [System.Xml.XmlElement] GetProtocolElement([acn.ddl.Property]$property, [PSCustomObject]$protocol) {
		return [CANopen]::GetProtocolElement($property,$protocol,0);
	}

	# Get the protocol attributes of the specified protocol on the specified property.
	# @return the attributes as hashtable
	static [hashtable] GetProtocolAttributes([acn.ddl.Property]$property, [PSCustomObject]$protocol, [int]$index = 0) {
		$protoattrs = [CANopen]::GetProtocolElement($property,$protocol,$index);
		if ($protoattrs) {
			$result = @{}
			foreach ($a in $protocol.attrs) {
				$result[$a] = $protoattrs.GetAttribute($a)
			}
			return $result
		}
		return $null
	}

	# Get the protocol attributes of the specified protocol on the specified property.
	static [hashtable] GetProtocolAttributes([acn.ddl.Property]$property, [PSCustomObject]$protocol) {
		return [CANopen]::GetProtocolAttributes($property,$protocol,0);
	}

	# Test if the specified GDC group is mapped to a CANopen RECORD, and if so, return the
	# CANopen protocol attributes.
	# @param $groupName text from GDC resource that identifies a GDC object group
	static [System.Collections.Specialized.OrderedDictionary] GroupToCANopenRecord([string]$groupName) {
		[object] $attrObject = [CANopen]::getAdjunctData('GDCGroupToCANopenRecord',$groupName);
		return [CANopen]::ConvertPSObjectToCANopenAttrs($attrObject);
	}
	
	# Test if the specified GDC object (by name) is mapped to a CANopen ARRAY, and if so, return the
	# CANopen protocol attributes.
	# @param $objectName text from GDC resource that identifies a GDC object
	static [hashtable] ObjectToCANopenArray([string]$objectName) {
		[object] $attrObject = [CANopen]::getAdjunctData('GDCObjectToCANopenArray',$objectName);
		return [CANopen]::ConvertPSObjectToCANopenAttrs($attrObject);
	}

	# Import data objects of a CANopen Electronic Data Sheet (EDS) document into the specified module.
	# @param $reader the reader
	# @param $fileInfo specifies the file to import
	# @param $productID the name/identifier of the device product
	# @param $moduleName the name of the ACN DDL module to import the device properties into
	static [void] ImportElectronicDataSheet([acn.ddl.Reader]$reader, [System.IO.FileInfo]$fileInfo, [string]$productID, [string]$moduleName) {
		if ($fileInfo -eq $null) {
			return;
		}
		$reader.FileInfo = $fileInfo
		try {
			# try to determine the product name and document type from the filename
			if ($fileInfo.Name -match "(?<product>[A-Za-z][A-Za-z0-9\-_]+)(?<extension>\.(eds))$") {
				if (!$productID) {
					$productID = $matches['product'];
					$product = "UNKNOWN"
				}
				if (!$productID) {
					$productID = "UNKNOWN"
				}
				if (!$moduleName) {
					# try to determine the product name from the filename
					$moduleName = $productID;
				}
				# $docType the CANopen document type
				$docType = 'ElectronicDataSheet';
				$fileType = $matches['extension'];
			}
			else {
				throw [InvalidOperationException]::new(("unsupported file type '{0}'" -f $fileInfo.ToString()))
			}
			write-verbose ("{0,16} {1}" -f "import",$reader.FileInfo)
			$objects = $null
			# read and process the EDS file
			switch ($fileType) {
			".eds" {
					$docType = 'ElectronicDataSheet';
					$objects = Import-Ini $reader.FileInfo
					break;
				}
			default {
					throw [InvalidOperationException]::new(("unsupported file type '{0}'" -f $fileType))
				}
			}
			# read and load the optional recipe file
			[CANopen]::LoadAdjunctFile($reader,$productID,$reader.FileInfo);
			switch ($docType) {
			"ElectronicDataSheet" {
					$label = "$productID Device"
					$reader.Stack.Push([CANopen]::GetOrCreateDeviceDocument($reader,$moduleName,$label))
					try {
						[CANopen]::ImportEDSObjects($reader,$reader.CurrentDevice,$objects)
					}
					finally {
						$reader.Stack.Pop()
					}
					break
				}
			default {
					throw [InvalidOperationException]::new(("not yet supported document type '{0}'" -f $docType))
				}
			}
		}
		finally {
			$reader.FileInfo = $null
		}
	}

	# Import a CANopen EDS comments section in a device.
	# The $sectionKey can only be "Comments"
	# @param $reader the reader
	# @param $canopenGroup the property group to import the objects into
	# @param $edsData the result of Import-Ini Product.eds
	# @param $sectionKey the name of the comments section
	static [void] ImportEDSComments([acn.ddl.Reader]$reader, [acn.ddl.Property]$canopenGroup, [object]$edsData, [string]$sectionKey)
	{
		$sectionKey = 'Comments'
		if ($edsData[$sectionKey])
		{
			$section = $edsData[$sectionKey]
			$lines = [System.Text.StringBuilder]::new()
			$lineCount = [int]$section['Lines']
			for ($i = 1; $i -le $lineCount; $i++) {
				if ($lines.Length -gt 0) {
					$lines.AppendLine()
				}
				$lines.Append($section['Line' + $i])
			}
			if ($lines.Length -gt 0) {
				$cmt = $canopenGroup.GetOrAddProperty("EDS.$sectionKey","immediate")
				$cmt.AddBehavior("acn.dms.bset","comment");
				$cmt.SetValue("string",$lines.ToString())
			}
		}
	}

	# Import a CANopen EDS data section with immediate properties in a device.
	# $sectionKey can be DeviceInfo and DummyUsage
	# @param $reader the reader
	# @param $canopenGroup the property group to import the objects into
	# @param $edsData the result of Import-Ini Product.eds
	# @param $sectionKey the name of the immediate data section
	static [void] ImportEDSImmediateObjects([acn.ddl.Reader]$reader, [acn.ddl.Property]$canopenGroup, [object]$edsData, [string]$sectionKey)
	{
		$section = $edsData[$sectionKey]
		if ($section) {
			$pg = $canopenGroup.GetOrAddProperty("EDS.$sectionKey","NULL","EDS $sectionKey")
			foreach ($key in [CANopen]::eds.$sectionKey.Keys)
			{
				$value = $section[$key];
				if ($value -ne $null) {
					$prop = $pg.GetOrAddProperty($key,[acn.ddl.PropertyValueType]::immediate)
					write-verbose ("{0,16} {1}" -f $key,$value)
					[CANopen]::AddBehaviors($prop,[CANopen]::eds.$sectionKey.$key)
					# determine the data type
					$type = $prop.FindBehavior("acn.dms.bset","type.")
					if (!$type) {
						throw [InvalidOperationException]::new(("cannot find the datatype of property '{0}'" -f $prop.id));
					}
					$valueDataType = [CANopen]::ConvertDataTypeToValueDataType($type.ToString())
					if ($type.ToString() -eq "acn.dms.bset:type.string") {
						$parSize = [CANopen]::eds.maxLineDataLength - $key.Length
						$prop.AddOrUpdateSubProperty("acn.dms.bset","limitMaxCodeUnits","MaxCodeUnits","uint",$parSize)
					}
					# @todo optionally convert the value (format)
					$prop.SetValue($valueDataType,$value)
				}
			}
		}
	}

	# Import CANopen EDS data (objects) in a device.
	# @param $reader the reader
	# @param $device the Device to import the objects into
	# @param $edsData the result of Import-Ini Product.eds
	static [void] ImportEDSObjects([acn.ddl.Reader]$reader, [acn.ddl.Device]$device, [object]$edsData)
	{
		# check [FileInfo].EDSVersion (must be 4.0)
		$edsVersion = $edsData['FileInfo']['EDSVersion']
		if (!$edsVersion) {
			# default value
			$edsVersion = "3.0"
		}
		if ($edsVersion -notin [CANopen]::eds.supportedVersions)
		{
			throw [InvalidOperationException]::new(("unsupported EDS version: {0}" -f $edsVersion))
		}
		# get FileInfo.ModificationData
		
		[CANopen]::RegisterModule($device, "acnbase.bset")
		[CANopen]::RegisterModule($device, "acn.dms.bset")
		[CANopen]::RegisterModule($device, "CANopen.bset")

		# optionally import [Tools] CiA 306-3
		
		# if DevInfo.DynamicChannelsSupported then import [DynamicChannels]
		
		$canopenGroup = $device.GetOrAddProperty("CANopen",[acn.ddl.PropertyValueType]::NULL,"CANopen Communication Profile")		
		
		# import [Comments]
		[CANopen]::ImportEDSComments($reader,$canopenGroup,$edsData,'Comments')
		# import immediate data sections [DeviceInfo],[DummyUsage]
		[CANopen]::ImportEDSImmediateObjects($reader,$canopenGroup,$edsData,'DeviceInfo')
		[CANopen]::ImportEDSImmediateObjects($reader,$canopenGroup,$edsData,'DummyUsage')

		$objects = [System.Collections.Generic.SortedDictionary[[string],[object]]]::new()
		
		# collect the objects
		foreach ($objectsKey in [CANopen]::eds.objectSectionKeys)
		{
			$section = $edsData[$objectsKey]
			write-verbose ("{0,16} {1}" -f $section['SupportedObjects'],$objectsKey)
			for ($i = 1; $i -le $section['SupportedObjects']; $i++)
			{
				$index = [int]$section[$i]
				$subIndex = $null
				$key = [CANopen]::GetCANopenEDSKey($index,$subIndex)
				$object = $edsData[$key]
				if (![CANopen]::isValidEDSObject($key,$object)) {
					continue
				}
				write-verbose ("{0,16} {1}" -f $key,$object['ParameterName'])
				$object.index = $index
				$object.hasSubIndex = $false
				$object.maxSubIndex = -1
				$object.objectCode = [CANopen]::GetEDSObjectTypeCode($object.'ObjectType')
				$object.isArray = ($object.objectCode -eq "CANopen.bset:ObjectCode.ARRAY")
				$object = [pscustomobject]$object

				$key = [CANopen]::GetCANopenKey(0,$index, $subIndex)
				$objects.Add($key,$object);
				# is it a structured or array object?
				if ($object.'SubNumber') {
					$subNumbers = $object.'SubNumber'
					$actualSubNumbers = 0
					$subIndex = 0
					$object.maxSubIndex = 0
					for ($subIndex = 0; $subIndex -le $object.maxSubIndex; $subIndex++)
					{
						# er moeten 'SubNumber' secties gezocht worden,
						# maar wel in de range 0 ...MaxSubIndex, met MaxSubIndex de value van XXXsub0
						# de EDS is pas invalid als #gevonden secties < 'SubNumber' aantal secties
						$subKey = [CANopen]::GetCANopenEDSKey($index,$subIndex)
						$subObject = $edsData[$subKey]
						if (![CANopen]::isValidEDSObject($subKey,$subObject)) {
							continue
						}
						if ($subObject) {
							$subObject.index = $index
							$subObject.hasSubIndex = $true
							$subObject.subIndex = $subIndex
							$subObject.objectCode = [CANopen]::GetEDSObjectTypeCode($subObject.'ObjectType')
							$subObject.isArrayMember = $object.isArray
							$actualSubNumbers++
							if ($subIndex -eq 0)
							{	# update the MaxSubIndex
								$object.maxSubIndex = [int]$subObject['DefaultValue']
								if ($object.maxSubIndex -lt 0) {
									write-error "invalid [$subKey]::DefaultValue: $($object.maxSubIndex) < 0"
									$object.maxSubIndex = 0
								}
								if ($object.maxSubIndex -gt 254) {
									write-error "invalid [$subKey]::DefaultValue: $($object.maxSubIndex) > 254"
									$object.maxSubIndex = 254
								}
							}
							$key = [CANopen]::GetCANopenKey(0,$index, $subIndex)
							#write-verbose ("{0,16} {1}" -f $key,$subObject['ParameterName'])
							$objects.Add($key,[pscustomobject]$subObject);
						}
					}
					if ($actualSubNumbers -ne $subNumbers) {
						write-error ("invalid number of sub-indices of object {0} '{1}': {2} (expected {3})" -f $section[$i],$object['ParameterName'],$actualSubNumbers,$subNumbers)
					}
				}
			}
		}
		# process the objects
		write-verbose ("{0,16} {1}" -f $objects.Count,"CANopen objects")
		# latest compound property (group)
		$compound = $null
		foreach ($kvp in $objects.GetEnumerator())
		{
			# get the object data
			$object = $kvp.Value
			$nodeID = 0
			$index = $object.index
			$subIndex = $object.subIndex
			# EDS parameter name (arbitrary text)
			$parameterName = $object.'ParameterName'

			if ($object.hasSubIndex) {
				if (!$compound) {
					throw [InvalidOperationException]::new(("object {0:X4} with sub-index {1:X2} without preceeding compound object" -f $object.index,$object.subIndex))
				}
				if ($object.subIndex -eq 0) {
					# explicit MaxSubIndex in EDS might be implicit in ACN
					if ($object.AccessType -in @('const','ro')) {
						# suppress implicit MaxSubIndex
						write-verbose ("{0,16} {1} (implicit MaxSubIndex)" -f $kvp.Key,$parameterName)
						continue
					}
					else {
						# normalize name of explicit MaxSubIndex
						# name is typically same as of parent compound: add .MaxSubIndex if needed
						if ($parameterName -notmatch ".MaxSubIndex$") {
							$parameterName += ".MaxSubIndex"
						}
					}
				}
			}

			# unique (hierarchical) identifier of the property
			$pid = $null
			# determine the parent node of the property
			if ([acn.CANopen.ObjectDictionary]::IsCommunicationObject($object.index))
			{
				$pg = $canopenGroup
			}
			else {
				$pg = $device
			}
			# check if the parameterName is the id of an existing property
			$p = $pg.GetProperty($parameterName)
			if ($p) {
				$pid = $parameterName
				write-verbose ("{0,16} {1} (existing)" -f $kvp.Key,$parameterName)
			}
			elseif ([CANopen]::deviceObjects.ContainsKey($kvp.Key)) {
				# a standard CANopen object: normalize the identifier
				$dictObject = [CANopen]::deviceObjects[$kvp.Key]
				# use the normalized identifier
				$pid = $dictObject.id
				if ($object.isArray) {
					# some standard CANopen ARRAY objects are actually a RECORD and not mapped to an ACN array
					if (!$dictObject.HasArray) {
						$object.isArray = $false
						write-verbose ("{0,16} {1} (CANopen ARRAY mapped to record)" -f $kvp.Key,$parameterName)
					}
				}
				elseif ($object.isArrayMember -and !$compound.HasArray) {
					# some standard CANopen ARRAY objects are actually a RECORD and not mapped to an ACN array
					$object.isArrayMember = $false
				}
			}
			elseif ($object.hasSubIndex) {
				if (!$compound) {
					throw [InvalidOperationException]::new(("object {0:X4} with sub-index {1:X2} without preceeding compound object" -f $object.index,$object.subIndex))
				}
				if ($object.subIndex -eq 0) {
					# explicit MaxSubIndex in ACN (e.g. with access="rw")
					# lookup the compound property of MaxSubIndex in the standard
					$key = "{0:X2}:{1:X4}:  " -f $nodeID,$index
					if ([CANopen]::deviceObjects.ContainsKey($key)) {
						$dictObject = [CANopen]::deviceObjects[$key]
						# use the normalized identifier
						$pid = $dictObject.id + ".MaxSubIndex"
					}
					else {
						# force name to 'MaxSubIndex'
						$pid = $compound.id + '.MaxSubIndex'
					}
				}
				elseif ($object.subIndex -gt 0) {
					if ($object.isArrayMember) {
						$pid = $compound.id
					}
					else {
						# check if the $parameterName is sufficiently unique; otherwise prefix with the compound ID
						if (!$parameterName.Contains('.') -or ![acn.ddl.Reader]::IsBasicLatinXmlNCName($parameterName)) {
							$pid = $compound.id + "." + [CANopen]::NormalizeName($parameterName)
						}
					}
				}
			}
			if (!$pid) {
				# convert arbitrary name into XML identifier
				$pid = [CANopen]::NormalizeName($parameterName)
				# if this pid is already present, prepend the COB-ID
				if ($pg.GetProperty($pid)) {
					$pid = "co{0:X4}.{1}" -f $object.index,$pid
				}
			}
			if ($parameterName -ne $pid) {
				write-verbose ("{0,16} {1} => {2}" -f $kvp.Key,$parameterName,$pid)
			}
			else {
				write-verbose ("{0,16} {1}" -f $kvp.Key,$parameterName)
			}
			switch ($object.objectCode) {
			"CANopen.bset:ObjectCode.ARRAY" {
					if ($object.isArray) {
						$prop = $pg.GetOrAddProperty($pid,[acn.ddl.PropertyValueType]::network)
						$prop.HasArray = $true
						if ($object.maxSubIndex -gt 1) {
							$prop.ArraySize = $object.maxSubIndex
						}
					}
					else {
						$prop = $pg.GetOrAddProperty($pid,[acn.ddl.PropertyValueType]::NULL)
					}
					if ($pid -ne $parameterName) {
						$prop.SetLabelText($parameterName)
					}
					$compound = $prop
					$prop.AddBehavior($object.objectCode)
					[CANopen]::AddCANopenProtocol($prop,$object.index,$null,$null, -1, $false)
					break
				}
			"CANopen.bset:ObjectCode.RECORD" {
					$prop = $pg.GetOrAddProperty($pid,[acn.ddl.PropertyValueType]::NULL)
					if ($pid -ne $parameterName) {
						$prop.SetLabelText($parameterName)
					}
					$compound = $prop
					$prop.AddBehavior($object.objectCode)
					[CANopen]::AddCANopenProtocol($prop,$object.index,$null, $null, -1, $false)
					break
				}
			"CANopen.bset:ObjectCode.VAR" {
					$pindex = -1
					if (!$object.hasSubIndex) {
						$compound = $null
					}
					elseif ($object.isArrayMember) {
						$pindex = $object.subIndex - 1
					}
					$prop = $pg.GetOrAddProperty($pid,[acn.ddl.PropertyValueType]::network)
					if ($pid -ne $parameterName) {
						if ($object.isArrayMember) {
							if ($parameterName -ne $compound.GetLabelText()) {
								$prop.AddOrUpdateSubProperty("acnbase.bset","labelString","Label",[acn.ddl.ValueDataType]::string,$parameterName,$pindex)
							}
						}
						else {
							$prop.SetLabelText($parameterName)
						}
					}
					# set the datatype
					$dataType = [CANopen]::GetEDSDataTypeBehavior($object.'DataType')
					$prop.AddBehavior($dataType)
					$valueDataType = [CANopen]::ConvertDataTypeToValueDataType($dataType)
					if ($object.'DefaultValue') {
						$value = $object.'DefaultValue'
						# quick fix the use of $NODEID+0x80 etc. in integer values
						if ($valueDataType -ne [acn.ddl.ValueDataType]::string) {
							if ($value.Contains('$')) {
								$valueDataType  = [acn.ddl.ValueDataType]::string;
							}
						}
						$prop.AddOrUpdateSubProperty("acnbase.bset","initializer","Default",$valueDataType,$value,$pindex)
					}
					if ($object.'LowLimit') {
						$value = $object.'LowLimit'
						# @todo suppress if value equals min of type
						$prop.AddOrUpdateSubProperty("acnbase.bset","limitMinInc","Min",$valueDataType,$value,$pindex)
					}
					if ($object.'HighLimit') {
						$value = $object.'HighLimit'
						# @todo suppress if value equals max of type
						$prop.AddOrUpdateSubProperty("acnbase.bset","limitMaxInc","Max",$valueDataType,$value,$pindex)
					}
					$addAttr = [ordered]@{
					}
					if ($object.'AccessType')
					{
						$at = [CANopen]::eds.AccessType[$object.'AccessType']
						if ($at.access -ne [CANopen]::protocolDefinition.CANopen.defaultAttrValue.access) {
							$addAttr.access = $at.access;
						}
						if ($object.'PDOMapping' -eq '1') {
							$addAttr.pdo = $at.pdo
						}
					}
					[CANopen]::AddCANopenProtocol($prop,$object.index,$object.subIndex, $addAttr, $pindex, $false)
					break
				}
			}
		}
	}
	
	# Check mandatory fields and other requirements of the specified EDS object section
	# @see CiA306-1 Table 7
	# @param $key the key of the section (with index and optionally subIndex)
	# @param $object the (sub)object section
	# @return $true if object is ok and can be handled, $false otherwise
	static [bool] isValidEDSObject([string]$key,[hashtable]$object) {
		$result = $true;
		if (!$object) {
			write-warning ("EDS entry [{0}] is missing" -f $key)
			$result = $false;
			return $result;
		}
		$objectCode = [CANopen]::GetEDSObjectTypeCode($object['ObjectType'])
		$objectEds = [CANopen]::eds.ObjectCode[$objectCode]
		if (!$objectEds.supported) {
			write-warning ("EDS entry [{0}] has unsupported ObjectType {1}" -f $key,$object['ObjectType'])
			$result = $false;
		}
		foreach ($fieldKey in $objectEds.mandatory) {
			if (!$object[$fieldKey]) {
				write-error ("invalid EDS entry [{0}]: missing '{1}'" -f $key,$fieldKey)
				$result = $false;
			}
		}
		foreach ($fieldKey in $objectEds.unexpected) {
			if ($object[$fieldKey]) {
				write-warning ("invalid EDS entry [{0}]: unexpected '{1}'" -f $key,$fieldKey)
				$result = $false;
			}
		}
		if ($object['AccessType'])
		{
			$at = [CANopen]::eds.AccessType[$object['AccessType']]
			if (!$at) {
				write-error ("invalid EDS AccessType of object [{0}] '{1}'" -f $key,$object['AccessType'])
				$result = $false;
			}
		}
		return $result
	}

	# Load the adjunct data file for the specified source file or product
	static [void] LoadAdjunctFile([acn.ddl.Reader]$reader,[string]$product,[System.IO.FileInfo]$sourceFile) {
		$filename = [CANopen]::adjunctPath
		if ($filename -is [System.IO.FileInfo]) {
			if ($filename.Extension -ne ".json") {
				throw [ArgumentException]::new(("invalid filename '{0}': AdjunctPath must have a '.json' filename extension" -f $filename));
			}
		}
		else {
			# determine the adjunct filename based on the source filename
			$filename = [System.IO.FileInfo]::new([System.IO.Path]::ChangeExtension($sourceFile.FullName,".adjunct.json"));
			if (!$filename.Exists) {
				# determine the adjunct filename based on the product name and the sourcefile folder
				$filename = [System.IO.FileInfo]::new([System.IO.Path]::Combine($sourceFile.DirectoryName,"$product.adjunct.json"));
				if (!$filename.Exists) {
					write-verbose ("{0,16} {1}" -f "adjunct","file not available")
				}
			}
		}
		if ($filename -and $filename.Exists -and ($filename -ne [CANopen]::adjunctFile)) {
			write-verbose ("{0,16} {1}" -f "loading",$filename)
			[CANopen]::adjunctData = Get-Content $filename | ConvertFrom-Json;
			[CANopen]::adjunctFile = $filename;
		}
	}
	
	# Normalize the 'name' to an identifier
	# @param name text from input resource that should be an identifier, but is arbitrary text
	static [string] NormalizeName([string]$name) {
		# trim, splat to CamelCase, replace special chars with LOW LINE
		$result = [acn.ddl.Reader]::ConvertToBasicLatinXmlNCName($name);
		# perform lookup normalization
		$result = [CANopen]::getAdjunctData('NormalizedName',$result,$result);
		return $result;
	}

	# Register the specified module(Id) for referencing with the current module
	static [void] RegisterModule([acn.ddl.Module]$module, [string]$moduleId) {
		$module.AddUUIDname([CANopen]::module.$moduleId,$moduleId)
	}

	# Translate a 'name' to something more readable
	# @param name text from input resource that should be an identifier, but is arbitrary text
	static [string] TranslateName([string]$name) {
		# perform artificial intelligence (lookup) translation
		return [CANopen]::getAdjunctData('TranslatedName',$name,$name)
	}
}

<#
.SYNOPSIS
 Exports an acn.ddl.Device (appliance) model to CANopen file(s).

.DESCRIPTION
 Exports device description data from an ACN DDL device model to a CANopen
 data file. File formats supported are:
 
 - EDS Electronic Data Sheet

 Use the -Path parameter to write the documents to a specific folder. By default,
 if -Path is $null or empty, the files are output as text string to the pipeline.

 You can use macros to format the file name based on properties of the module.

.PARAMETER Path
 The path of the file(s) to export. The exported files are written to the pipeline
 as System.IO.FileInfo objects.

 By default, or if -Path is set to $null or the empty string, the exported file content
 is written as string to the pipeline.

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

.PARAMETER Indent
 Write the XML document with non-significant line breaks and hierarchical indenting
 for easy human reading.

.PARAMETER InputObject
 An acn.ddl.Document object containing a Device module to export. May be piped.

.INPUTS
 acn.ddl.Document - ACN DDL Device document(s) to export

.OUTPUTS
 String - exported data in case Path is not specified
 System.IO.FileInfo - info of exported file(s) in case Path is specified

.EXAMPLE
 PS> $ciaFiles = $documents | Export-AcnToCANopen

 Export CANopen device description files for the ACN DDL Device modules in the $documents list to strings,
 stored in the $ciaFiles variable. $ciaFiles will be a [string[]].

.EXAMPLE
 $documents | Export-AcnToCANopen -path ".\{uuid>-}{name}.eds"

 Export the module of "Test Device" to "Test_Device.eds" in the current directory:

	PS > $documents = New-AcnDocumentList
	PS > $module = $documents.NewDevice("Test Device")
	PS > $module | Export-AcnToCANopen -path ".\{uuid>-}{name}.eds"

 Note that in the -Path two macros are specified: the "uuid" property is the first component, postfixed with a hyphen if the UUID is present in the module. The standard
 Name property is the second component of the filename.
#>
function Export-AcnToCANopen {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$false)]
		[AllowEmptyString()][AllowNull()]
		[string]$Path,

		[Parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[object]$InputObject
	)
	begin {
		# create the writer
		$writer = [acn.ddl.Writer]::New()
	}
	process {
		# process the input object(s) (filter acn.ddl.Document with a Device)
		#
		$InputObject | where-object { ($_ -is [acn.ddl.Document]) -and $_.Device } | foreach-object {
			$writer.CurrentDocument = $_
			try {
				$device = $writer.CurrentDocument.Device
				# signal the creation of the appliance if not present
				if (!$device.Appliance) {
					write-verbose ("{0,16} {1} {2}" -f "building","appliance",$device.id)
				}
				[CANopen]::ExportCANopenEDS($writer, $Path, $device.GetAppliance())

##				[CANopen]::ExportCANopenToGDCTranslationTable($writer, $Path, $list)
			}
			finally {
				$writer.CurrentDocument = $null
			}
		}
	}
	end {
	}
}


<#
.SYNOPSIS
 Exports an acn.ddl.Device (appliance) model to an emotas CANopen Device Designer CSV import file.

.DESCRIPTION
 Exports device description data from an ACN DDL device model to a CANopen
 data file, suited for import in the emotas CANopen Device Designer.
 File formats supported are:
 
 - CSV Comma Separated Values

 Use the -Path parameter to write the documents to a specific folder. By default,
 if -Path is $null or empty, the files are output as text string to the pipeline.

 You can use macros to format the file name based on properties of the module.

.PARAMETER Path
 The path of the file(s) to export. The exported files are written to the pipeline
 as System.IO.FileInfo objects.

 By default, or if -Path is set to $null or the empty string, the exported file content
 is written as string to the pipeline.

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

.PARAMETER InputObject
 An acn.ddl.Document object containing a Device module to export. May be piped.

.INPUTS
 acn.ddl.Document - ACN DDL Device document(s) to export

.OUTPUTS
 String - exported data in case Path is not specified
 System.IO.FileInfo - info of exported file(s) in case Path is specified

.EXAMPLE
 PS> $ciaFiles = $documents | Export-AcnToEmotasCDD

 Export CANopen device description files for the ACN DDL Device modules in the $documents list to strings,
 stored in the $ciaFiles variable. $ciaFiles will be a [string[]].

.EXAMPLE
 $documents | Export-AcnToEmotasCDD -path ".\{uuid>-}{name}.csv"

 Export the module of "Test Device" to "Test_Device.csv" in the current directory:

	PS > $documents = New-AcnDocumentList
	PS > $module = $documents.NewDevice("Test Device")
	PS > $module | Export-AcnToEmotasCDD -path ".\{uuid>-}{name}.csv"

 Note that in the -Path two macros are specified: the "uuid" property is the first component, postfixed with a hyphen if the UUID is present in the module. The standard
 Name property is the second component of the filename.
#>
function Export-AcnToEmotasCDD {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$false)]
		[AllowEmptyString()][AllowNull()]
		[string]$Path,

		[Parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[object]$InputObject
	)
	begin {
		# create the writer
		$writer = [acn.ddl.Writer]::New()
	}
	process {
		# process the input object(s) (filter acn.ddl.Document with a Device)
		#
		$InputObject | where-object { ($_ -is [acn.ddl.Document]) -and $_.Device } | foreach-object {
			$writer.CurrentDocument = $_
			try {
				$device = $writer.CurrentDocument.Device
				# create the appliance if not present
				if (!$device.Appliance) {
					write-verbose ("{0,16} {1} {2}" -f "building","appliance",$device.id)
				}

				# emotas CANopen Device Designer configuration
				[CANopen]::ExportEmotasCDDConfiguration($writer, $Path, $device.GetAppliance())
			}
			finally {
				$writer.CurrentDocument = $null
			}
		}
	}
	end {
	}
}

<#
.SYNOPSIS
 Import a device description from CiA CANopen sources.

.DESCRIPTION
 Import device description data from one or more CANopen data files.
 
 Supported file types are:
 - *.eds: CANopen Electronic Data Sheet (EDS) (partly supported)
 
 Currently unsupported file types are:
 - *.xdd: CANopen XML Device Description (XDD)
 - *.dcf: CANopen Device Configuration File (DCF)
 - *.xcd: CANopen XML Device Configuration Description (XCD)

 The ACN DDL modules are returned in the pipeline in an acn.ddl.DocumentList object.

.PARAMETER Path
 The file system path name of the file(s) to import, or of the file system directory that 
 holds the files to import.

 By default the Path is the current file system directory. This parameter can also be provided via the pipeline.

.PARAMETER Encoding
 The text encoding of the source files. By default, UTF-8 is assumed and Unicode signatures
 (Byte-Order-Marks) are recognized.

.PARAMETER DocumentList
 An acn.ddl.DocumentList object might be provided to import the device into. By default
 a new DocumentList is created and returned in the pipeline.

.PARAMETER AdjunctPath
 Path to a JSON file with additional and specific CANopen object data that supplements the imported source files.

.PARAMETER ModuleName
 The name of the ACN DDL device module to import the CANopen object data into.
 By default, the name "cia.CANopen.<product>" is used.

.PARAMETER ModulePath
 One or more paths of folders that contain the ACN DDL module repository.

.PARAMETER ProductID
 Name or identifier of the device product that is imported.
 By default, the product name is extracted from the source file.

.INPUTS
 String

.OUTPUTS
 acn.ddl.DocumentList

.EXAMPLE
 "MyDevice.eds" | Import-CANopenToAcn | Export-AcnModule "{name}.ddl.xml"

 - Import the MyDevice CANopen EDS file from the specified input path,
   - and read additional ACN DDL modules from the current folder,
 - Write the device description to one or more ACN DDL module files with the module name as filename
   in the current folder.

 Note that existing module files will not be overwritten: the new files will have a numeric incremental filename.
#>
function Import-CANopenToAcn {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$false, Position=0, HelpMessage="Enter the name of the file(s) to process", ValueFromPipeline = $true)]
		[SupportsWildcards()]
		[string[]]$Path = ".",

		[Parameter(Mandatory=$false)]
		[string]$Encoding = "UTF-8",

		[Parameter(Mandatory=$false)][AllowNull()][Alias("dl")]
		[acn.ddl.DocumentList]$DocumentList,

		[Parameter(Mandatory=$false)][AllowNull()][Alias("ap")]
		[string]$AdjunctPath,

		[Parameter(Mandatory=$false)][AllowNull()][Alias("mn")]
		[string]$ModuleName,

		[Parameter(Mandatory=$false)][AllowNull()][Alias("mp")]
		[string[]]$ModulePath,

		[Parameter(Mandatory=$false)][AllowNull()]
		[string]$ProductID
	)
	begin {
		# declare the container for the items to import
		if ($DocumentList -eq $null) {
			$DocumentList = [acn.ddl.DocumentList]::New()
		}
		# declare the reader
		$reader = [acn.ddl.Reader]::New([System.Text.Encoding]::GetEncoding($Encoding))
		$reader.CurrentDocumentList = $DocumentList
		if ($AdjunctPath) {
			[CANopen]::adjunctPath = Get-Item $AdjunctPath -ErrorAction "Stop"
		}
		if ($ModulePath) {
			$DocumentList.ModuleFolders.Clear();
			for ($i = 0; $i -lt $ModulePath.Length; $i++) {
				$ModulePath[$i] = resolve-path $ModulePath[$i]
				write-verbose ("{0,16} {1}" -f "mp $i",$ModulePath[$i])
			}
			$DocumentList.ModuleFolders.AddRange($ModulePath);
		}
	}
	process {
		$Path | get-item | where-object { $_ -is [System.IO.FileInfo] } | foreach-object {
			$item = $_
			$reader.FileInfo = $item
			try {
				switch -regex ($item.Name) {
				"\.eds$" {
						[CANopen]::ImportElectronicDataSheet($reader, $item, $ProductID, $ModuleName)
						# it seems reading this file was successful
						$reader.FileCount++
						break
					}
				"\.xml$"	{
						# create a file stream reader to read text from the file
						# use the specified DefaultEncoding, or the encoding specified by the BOM
						#$reader.TextReader = [System.IO.StreamReader]::new($item.FullName,$reader.DefaultEncoding)
						# add a Device module to store the data
						#$reader.Stack.Push($reader.CurrentDocumentList.NewDevice($reader.FileInfo.Name))
						#$reader.CurrentDocument.FileInfo = $reader.FileInfo
						# read and process the XmlDocument
						[xml]$xml = Get-Content $reader.FileInfo
						if ($xml.GdcDeviceLayouts) {
							# import from a GdcDeviceLayouts file
							write-verbose ("{0,16} from {1}" -f "import",$reader.FileName)
							# read and load the optional recipe file
							[CANopen]::LoadAdjunctFile($reader,"",$reader.FileInfo);
							[CANopen]::ImportGdcDeviceLayouts($reader, $xml.GdcDeviceLayouts)
							# it seems reading this file was successful
							$reader.FileCount++
						}
						else {
							# unknown or unusable XML file
						}
						break
					}
				"(?<product>[A-Z]+)_(?<type>[A-Za-z]+)\.csv$"	{
						# GDC TwoWire Document (.csv export)
						# import the GDC data
						[CANopen]::ImportGdcTwoWireDocument($reader, $item, $ProductID, $ModuleName)
						# it seems reading this file was successful
						$reader.FileCount++
						break
					}
				}
			}
		#	catch [System.Exception] {
		#		write-error $_.Exception.InnerException
		#		throw [System.Exception]::New("while importing from file $($reader.FileName)",$_.Exception)
		#	}
			finally {
				$reader.FileInfo = $null
			}
		}
	}
	end {
		# return the DocumentList in the pipeline (as single object, so use the unary array operator)
		,$DocumentList
	}
}

Export-ModuleMember -Function *
