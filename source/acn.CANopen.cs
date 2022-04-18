//	__ _ ____ _  _ _    _ ____ ____   ____ ____ ____ ___ _  _ ____ ____ ____
//	| \| |=== |/\| |___ | |--- |===   ==== [__] |---  |  |/\| |--| |--< |===
//
/// @file acn.CANopen.cs
/// @copyright Ernst van der Pols, Licensed under the EUPL-1.2-or-later

using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Collections.ObjectModel;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml;
using System.Xml.Serialization;
using acn.ddl;
using acn.dms;

///
/// CANopen protocol and device model support in the Device Description Language of the
/// ANSI E1.17 Architecture for Control Networks (ACN).
/// 
/// The CANopen specifications are maintained by the CAN in Automation organization.
///
/// The main classes in this namespace are:
///
/// - acn.CANopen.TypeInfo
///   Provides information for mapping CANopen data types.
///
/// @see http://www.can-cia.org
/// @author Ernst van der Pols
/// @date 2022-04-14
/// @pre .NET Standard 2.0
///
namespace acn.CANopen {

	/// A CANopen Electronic Data Sheet (EDS)
	public class ElectronicDataSheet {

		/// Translation table of CANopen EDS AccessType values to CANopen SDO and PDO access specifiers
		public static OrderedDictionary AccessType = new OrderedDictionary() {
			{ "ro",   new OrderedDictionary() { {"access", "ro"}, {"sdo","ro"}, {"pdo","t"} } },
			{ "wo",   new OrderedDictionary() { {"access", "wo"}, {"sdo","wo"}, {"pdo","tr"} } },
			{ "rw",   new OrderedDictionary() { {"access", "rw"}, {"sdo","rw"}, {"pdo","tr"} } },
			{ "rwr",  new OrderedDictionary() { {"access", "rw"}, {"sdo","rw"}, {"pdo","t"} } },
			{ "rww",  new OrderedDictionary() { {"access", "rw"}, {"sdo","rw"}, {"pdo","r"} } },
			{ "const",new OrderedDictionary() { {"access", "const"}, {"sdo","ro"}, {"pdo","t"} } }
			};

		/// To ease using the non-generic AccessType dictionary
		/// @param acessType the EDS access type specifier
		/// @param protocol the protocol to get the access specifier of, given the AccessType
		/// @return the protocol access specifier, null if not present
		public static string GetProtocolAccesByAccessType(string accessType, string protocol) {
			OrderedDictionary dict = (OrderedDictionary)AccessType[accessType];
			if (dict != null) {
				return (string)dict[protocol];
			}
			return null;
		}
		
		/// Get the EDS AccessType of the specified CANopen protocol specification.
		/// @param protocol the valid protocol object
		/// @return the EDS AccessType
		/// @exception InvalidOperationException if the protocol is null or not valid
		public static string GetAccessType(acn.CANopen.Protocol protocol) {
			if ((protocol == null) || !protocol.IsValid()) {
				throw new InvalidOperationException("invalid or unspecified protocol object");
			}
			// EDS specific attributes
			string result = protocol.Access;
			if ((result == "ro") && protocol.IsConstant) {
				result = "const";
			}
			switch (protocol.PDOAccess) {
				case "t":
					if (result == "rw") {
						result = "rwr";
					}
					break;
				case "r":
					if (result == "rw") {
						result = "rww";
					}
					break;
			}
			return result;
		}

		/// Get the EDS PDOMapping of the specified CANopen protocol specification.
		/// @param protocol the valid protocol object
		/// @return the EDS PDOMapping
		/// @exception InvalidOperationException if the protocol is null or not valid
		public static string GetPDOMapping(acn.CANopen.Protocol protocol) {
			if ((protocol == null) || !protocol.IsValid()) {
				throw new InvalidOperationException("invalid or unspecified protocol object");
			}
			switch (protocol.PDOAccess) {
				case "t":
				case "r":
				case "tr":
					return "1";
			}
			return "0";
		}
	}

	/// Utility class for CANopen object dictionary functions.
	public class ObjectDictionary {
		
		/// Check whether the CANopen Object Dictionary index indicates a CANopen communication profile object
		/// @param index the object dictionary index
		/// @return true if the object is a communication profile object, false otherwise
		public static bool IsCommunicationObject(int index) {
			return (index >= 0x1000) && (index <= 0x1FFF);
		}

		/// Check whether the CANopen Object Dictionary index indicates a CANopen data object
		/// @param index the object dictionary index
		/// @return true if the object is not 0 or a CANopen type definition, false otherwise
		public static bool IsDataObject(int index) {
			return (index >= 0x1000);
		}

		/// Check whether the CANopen Object Dictionary index indicates a CANopen data type definition object
		/// @note index 0x0000 is not used
		/// @param index the object dictionary index
		/// @return true if the object is a data type definition object, false otherwise
		public static bool IsDataTypeObject(int index) {
			return (index > 0x0000) && (index <= 0x0FFF);
		}

		/// Check whether the property indicates a mandatory CANopen object.
		/// @param prop the property
		/// @return true if the object is mandatory, false otherwise
		public static bool IsMandatoryObject(acn.ddl.Property prop) {
			return (prop != null) && prop.HasBehavior("CANopen.bset:category.mandatory");
		}
		
		/// Check whether the CANopen Object Dictionary index indicates a manufacturer specific object
		/// @param index the object dictionary index
		/// @return true if the object is manufacturer specifc, false otherwise
		public static bool IsManufacturerObject(int index) {
			return (index >= 0x2000) && (index <= 0x5FFF);
		}
		
		/// Check whether the CANopen Object Dictionary index indicates a CANopen object.
		/// @param index the object dictionary index
		/// @return true if the object is not 0, false otherwise
		public static bool IsObject(int index) {
			return (index > 0x0000);
		}

		/// Check whether the CANopen Object Dictionary index indicates a standard profile object
		/// @param index the object dictionary index
		/// @return true if the object is standard profile specifc, false otherwise
		public static bool IsStandardProfileObject(int index) {
			return (index >= 0x6000) && (index <= 0x9FFF);
		}
	}

	/// The CANopen protocol attributes of a device property.
	public class Protocol : acn.dms.Protocol {

		/// The CANopen protocol definition
		public static acn.dms.ProtocolDefinition Definition = new acn.dms.ProtocolDefinition("CANopen", "cia:CANopen", "https://www.can-cia.org/CANopen",
			new OrderedDictionary() {
				{ "node", "0" },
				{ "index", "0" },
				{ "sub", "0" },
				{ "access", "rw" },
				{ "pdo", "no" }
			});

		/// The node number of the device on the CANopen bus
		public byte NodeID { get; protected set;}
		
		/// A sub index is specified in the ProtocolElement
		public bool HasSubIndex { get; set; }
		
		/// The CANopen Object Dictionary index of the property
		public ushort Index { get; protected set; }

		/// The CANopen Object Dictionary sub-index of the property
		public byte SubIndex { get; protected set; }

		/// The PDO read/write access specifier for the property
		public string PDOAccess { get; protected set; }

		/// The SDO read/write access specifier for the property
		public string SDOAccess { get; protected set; }
		
		/// Class constructor
		/// - create the protocol definition (is done inline)
		static Protocol() {
		}

		/// Create a CANopen protocol object for the specified property.
		/// @param property the network property
		/// @exception ArgumentNullException if the property is null
		/// @exception InvalidOperationException if the property has no CANopen protocol specified.
		public Protocol(acn.ddl.Property property)
			: base(property,acn.CANopen.Protocol.Definition)
		{
			// get the attributes from the ProtocolElement
			string node = ProtocolElement.GetAttribute("node");
			string index = GetAttribute("index");
			string subIndex = ProtocolElement.GetAttribute("sub");
			HasSubIndex = !string.IsNullOrEmpty(subIndex);
			if (!HasSubIndex) {
				if (Property.HasArray && (Property.ArrayIndex >= 0)) {
					// expand array sub-index: assign the array-index + 1
					subIndex = (Property.ArrayIndex + 1).ToString();
				}
				else {
					// default value
					subIndex = Definition.DefaultAttributes["sub"] as string;
				}
			}
			// the node number is specified on CANopen element of the property or one of its ancestors, or in the CANopen.DCF.NodeID property
			for (acn.ddl.Property prop = property; (prop != null) && string.IsNullOrEmpty(node); prop = prop.ParentNode as acn.ddl.Property) {
				System.Xml.XmlElement element = GetProtocolElement(prop,ProtocolDefinition);
				node = (element != null ? element.GetAttribute("node") : null);
				if (string.IsNullOrEmpty(node)) {
					acn.ddl.Property nodeIDProperty = prop.GetProperty("CANopen.DCF.NodeID");
					if (nodeIDProperty != null) {
						node = nodeIDProperty.GetValueString();
					}
				}
			}
			if (!string.IsNullOrEmpty(node)) {
				NodeID = (byte)acn.dms.TypeInfo.ConvertFromString(node,acn.dms.TypeInfo.UInt8);
			}
			Index = (ushort)acn.dms.TypeInfo.ConvertFromString(index,acn.dms.TypeInfo.UInt16);
			SubIndex = (byte)acn.dms.TypeInfo.ConvertFromString(subIndex,acn.dms.TypeInfo.UInt8);

			// determine the (SDO) access
			Access = ProtocolElement.GetAttribute("access");
			if (string.IsNullOrEmpty(Access)) {
				// default value of sdo access
				Access = (IsConstant ? "ro" : "rw");
			}
			// translate deprecated 'const' value
			if (Access == "const") {
				Access = "ro";
			}
			// @todo do we support SDO access?
			SDOAccess = ProtocolElement.GetAttribute("sdo");
			if (string.IsNullOrEmpty(SDOAccess)) {
				SDOAccess = acn.CANopen.ElectronicDataSheet.GetProtocolAccesByAccessType(Access,"sdo");
			}

			// determine the PDO access
			PDOAccess = ProtocolElement.GetAttribute("pdo");
			if (string.IsNullOrEmpty(PDOAccess)) {
				acn.ddl.BehaviorReference behavior = Property.FindBehavior("CANopen.bset","pdo.");
				if (behavior != null) {
					// delete the 'pdo.' part of the behavior name
					PDOAccess = behavior.name.Replace("tpo.","");
				}
			}
			if (string.IsNullOrEmpty(PDOAccess)) {
				// default value
				PDOAccess = Definition.DefaultAttributes["pdo"] as string;
			}
		}
		
		/// Try to get the CANopen protocol attributes of the specified property
		/// @param property the property to get the protocol of
		/// @return the CANopen protocol attributes or null if not available
		public static Protocol GetProtocol(acn.ddl.Property property) {
			Protocol result = null;
			try {
				result = new Protocol(property);
			}
			catch (Exception) {
				return null;
			}
			return result;
		}

		/// Get the CANopen ObjectCode behavior for the related property.
		/// @return the ObjectCode represented as behavior identifier.
		public string GetCANopenObjectCode() {
			acn.ddl.BehaviorReference behavior = this.Property.FindBehavior("CANopen.bset","ObjectCode.");
			if (behavior == null) {
				// no objecttype, use default
				return "CANopen.bset:ObjectCode.VAR";
			}
			return behavior.ToString();
		}

		/// Get the key for sorting the property in the list of 'protocol properties'.
		public override string GetSortingKey() {
			if (IsValid()) {
			//	if (($index -lt 0x0000) -or ($index -gt 0xFFFF)) {
			//		throw [ArgumentException]::new("invalid CANopen object index value: $index","index")
			//	}
			//	if ($subIndex) {
			//		[int]$sub = $subIndex
			//		if (($sub -lt 0) -or ($sub -gt 255)) {
			//			throw [ArgumentException]::new("invalid CANopen object sub-index value: $sub","subIndex")
			//		}
			//		return "{0:X2}:{1:X4}:{2:X2}" -f $nodeID,$index,$sub
			//	}
			//	return "{0:X2}:{1:X4}:  " -f $nodeID,$index
				return string.Format("{0:X2}:{1:X4}:{2:X2}",NodeID,Index,SubIndex);
			}
			return null;
		}
		
		/// Check if the CANopen object is a data object (and not a data type object).
		public bool IsCANopenDataObject() {
			return acn.CANopen.ObjectDictionary.IsDataObject(Index);
		}
	}
}
