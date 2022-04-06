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
/// @date 2022-04-01
/// @pre .NET Standard 2.0
///
namespace acn.CANopen {

	/// The data type of a device property
	public class DataType {
		/// the property that has this data type
		private acn.ddl.Property _property;

		/// The behavior reference that specifies the data type of the property
		private acn.ddl.BehaviorReference _dataTypeBehavior;

		/// the TypeInfo of the data type
		private acn.dms.TypeInfo _typeInfo = null;

		/// the property that has this data type
		public acn.ddl.Property Property { get { return _property; } }

		/// the TypeInfo of the data type
		public acn.dms.TypeInfo TypeInfo { get { return _typeInfo; } }

		/// Create a data type object for the specified property
		/// @exception ArgumentNullException if the property is null
		/// @exception InvalidOperationException if the property has no data type specified
		public DataType(acn.ddl.Property property) {
			if (property == null) {
				throw new ArgumentNullException("property");
			}
			_property = property;
			_dataTypeBehavior = property.FindBehavior("acn.dms.bset", "type.");
			if (_dataTypeBehavior == null) {
				throw new InvalidOperationException(string.Format("no datatype found for property '{0}'",property.id));
			}
			string behavior = _dataTypeBehavior.ToString();
			try {
				_typeInfo = acn.dms.TypeInfo.GetTypeInfoByBehavior(behavior);
			}
			catch (Exception ex) {
				throw new InvalidOperationException(string.Format("invalid or unsupported datatype behavior '{0}' of property '{1}'",behavior,property.id),ex);
			}
		}

		/// Convert the specified string value to the datatype of the property.
		/// @param value the value to convert
		/// @return the converted value in the datatype of the property, null if
		///   conversion is not possible
		public object ConvertFromString(string value) {
			object result = null;
			if (value != null) {
				try {
					switch (this.TypeInfo.Code) {
					case acn.dms.TypeCode.tcUInt8:
					case acn.dms.TypeCode.tcEnum8:
					case acn.dms.TypeCode.tcBitmap8:
						if (value.StartsWith("0x") || value.StartsWith("0X")) {
							result = System.Convert.ToByte(value,16);
						}
						else {
							result = System.Convert.ToByte(value);
						}
						break;
					case acn.dms.TypeCode.tcUInt16:
						if (value.StartsWith("0x") || value.StartsWith("0X")) {
							result = System.Convert.ToUInt16(value,16);
						}
						else {
							result = System.Convert.ToUInt16(value);
						}
						break;
					case acn.dms.TypeCode.tcUInt32:
					case acn.dms.TypeCode.tcEnum32:
					case acn.dms.TypeCode.tcBitmap32:
						if (value.StartsWith("0x") || value.StartsWith("0X")) {
							result = System.Convert.ToUInt32(value,16);
						}
						else {
							result = System.Convert.ToUInt16(value);
						}
						break;
					case acn.dms.TypeCode.tcUInt64:
						if (value.StartsWith("0x") || value.StartsWith("0X")) {
							result = System.Convert.ToUInt64(value,16);
						}
						else {
							result = System.Convert.ToUInt64(value);
						}
						break;
					case acn.dms.TypeCode.tcInt8:
						if (value.StartsWith("0x") || value.StartsWith("0X")) {
							result = System.Convert.ToSByte(value,16);
						}
						else {
							result = System.Convert.ToSByte(value);
						}
						break;
					case acn.dms.TypeCode.tcInt16:
						if (value.StartsWith("0x") || value.StartsWith("0X")) {
							result = System.Convert.ToInt16(value,16);
						}
						else {
							result = System.Convert.ToInt16(value);
						}
						break;
					case acn.dms.TypeCode.tcInt32:
						if (value.StartsWith("0x") || value.StartsWith("0X")) {
							result = System.Convert.ToInt32(value,16);
						}
						else {
							result = System.Convert.ToInt32(value);
						}
						break;
					case acn.dms.TypeCode.tcInt64:
						if (value.StartsWith("0x") || value.StartsWith("0X")) {
							result = System.Convert.ToInt64(value,16);
						}
						else {
							result = System.Convert.ToInt64(value);
						}
						break;
					case acn.dms.TypeCode.tcFloat32:
						result = System.Convert.ToSingle(value);
						break;
					case acn.dms.TypeCode.tcFloat64:
						result = System.Convert.ToDouble(value);
						break;
					case acn.dms.TypeCode.tcString:
						result = value;
						break;
					default:
						throw new InvalidOperationException(string.Format("conversion to type {0} not implemented",this.TypeInfo.Name));
					}
				}
				catch (Exception ex) {
					throw new InvalidOperationException(string.Format("conversion of '{0}' to type {1} failed",value,this.TypeInfo.Name),ex);
				}
			}
			return result;
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
		public Protocol(acn.ddl.Property property) : base(property,acn.CANopen.Protocol.Definition)
		{
			// get the attributes from the ProtocolElement
			string node = GetAttribute("node");
			string index = GetAttribute("index");
			string subIndex = GetAttribute("sub");
			NodeID = (byte)acn.dms.TypeInfo.ConvertFromString(node,acn.dms.TypeInfo.UInt8);
			Index = (ushort)acn.dms.TypeInfo.ConvertFromString(index,acn.dms.TypeInfo.UInt16);
			SubIndex = (byte)acn.dms.TypeInfo.ConvertFromString(subIndex,acn.dms.TypeInfo.UInt8);
			SDOAccess = GetAttribute("access");
			PDOAccess = GetAttribute("pdo");
			
			// quick fix
			if (NodeID == 0) {
				NodeID = 1;
			}
		}
		
		/// Try to get the CANopen protocol attributes of the specified property
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
		
		/// Determine the CANopen NodeID of the specified property.
		public static byte GetCANopenNodeID(acn.ddl.Property property) {
			return 0;
		}
	}
}
