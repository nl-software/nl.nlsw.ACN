//	__ _ ____ _  _ _    _ ____ ____   ____ ____ ____ ___ _  _ ____ ____ ____
//	| \| |=== |/\| |___ | |--- |===   ==== [__] |---  |  |/\| |--| |--< |===
//
/// @file acn.dms.Device.cs
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

///
/// The Device Management System (DMS) is a basic device model implementation, using the 
/// the Device Description Language of the ANSI E1.17 Architecture for Control Networks (ACN).
///
/// The DMS is a practical implementation that specifies common data types and other behaviors,
/// in addition to the ACN base behaviors.
///
/// The main classes in this namespace are:
///
/// - acn.dms.DataType
///   A class for representing the data type of a property.
///
/// - acn.dms.Protocol
///   A base class for representing protocol atributes of a property.
///
/// - acn.dms.ProtocolDefinition
///   A base class for the definition of protocol atributes.
///
/// - acn.dms.TypeInfo
///   Provides information for mapping ACN DMS data types to native types.
///
/// @author Ernst van der Pols
/// @date 2022-04-14
/// @pre .NET Standard 2.0
///
namespace acn.dms {

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
			_dataTypeBehavior = property.FindBehavior("acn.dms.bset","type.");
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
			return acn.dms.TypeInfo.ConvertFromString(value,this.TypeInfo);
		}
	}

	/// A base class for the protocol attributes of a device property.
	public class Protocol {
		/// Cached initial value of the property
		private string _InitialValue;
		/// Cached label string of the property
		private string _Label;
		/// The language of the cached label string.
		private string _Language;
		/// Cached maximum value of the numerical property
		private string _LimitMax;
		/// Cached minimum value of the numerical property
		private string _LimitMin;

		/// The protocol read/write access specifier for the property.
		/// The default implementation assumes an 'r' for read access and a 'w' for write access.
		public string Access { get; protected set; }

		/// The data size (maximum number of bytes) of the value of the property.
		public uint DataSize { get; protected set; }

		/// The data type of the property.
		public acn.dms.DataType DataType { get; protected set; }

		/// Get the initial value of the property
		/// @return the initial value, null if not available
		public virtual string InitialValue {
			get {
				if (_InitialValue == null) {
					acn.ddl.Property initializer = Property.GetPropertyWithBehavior("acnbase.bset:initializer");
					if (initializer != null) {
						_InitialValue = initializer.GetValueString(Property.ArrayIndex);
					}
				}
				return _InitialValue;
			}
			protected set {
				_InitialValue = value;
			}
		}

		/// Test if the property value is constant
		public bool IsConstant { get; protected set; }

		/// Get the maximum value of the property
		/// @return the maximum value, null if not available
		public string LimitMax {
			get {
				if (_LimitMax == null) {
					acn.ddl.Property max = Property.GetPropertyWithBehavior("acnbase.bset:limitMaxInc");
					if (max != null) {
						_LimitMax = max.GetValueString(Property.ArrayIndex);
					}
				}
				return _LimitMax;
			}
			protected set {
				_LimitMax = value;
			}
		}

		/// Get the minimum value of the property
		/// @return the minimum value, null if not available
		public string LimitMin {
			get {
				if (_LimitMin == null) {
					acn.ddl.Property min = Property.GetPropertyWithBehavior("acnbase.bset:limitMinInc");
					if (min != null) {
						_LimitMin = min.GetValueString(Property.ArrayIndex);
					}
				}
				return _LimitMin;
			}
			protected set {
				_LimitMin = value;
			}
		}

		/// The maximum value of the (numerical) property.
		public object MaxValue {
			get {
				if (LimitMax != null) {
					return DataType.ConvertFromString(LimitMax);
				}
				if (DataType.TypeInfo.IsNumber) {
					return DataType.TypeInfo.MaxValue;
				}
				// by default return a number
				return 0;
			}
		}

		/// The minimum value of the (numerical) property.
		public object MinValue {
			get {
				if (LimitMin != null) {
					return DataType.ConvertFromString(LimitMin);
				}
				if (DataType.TypeInfo.IsNumber) {
					return DataType.TypeInfo.MinValue;
				}
				// by default return a number
				return 0;
			}
		}

		/// The device property that has this protocol
		public acn.ddl.Property Property { get; protected set; }

		/// The protocol definition
		public acn.dms.ProtocolDefinition ProtocolDefinition { get; protected set; }

		/// The Protocol XmlElement node with the protocol attributes
		public System.Xml.XmlElement ProtocolElement { get; protected set; }

		/// Create a protocol object with the specified definition for the specified property.
		/// @param property the network property
		/// @param protocol the protocol definition
		/// @exception ArgumentNullException if the property or protocol is null
		/// @exception InvalidOperationException if the property has no CANopen protocol or protocol attributes specified.
		public Protocol(acn.ddl.Property property, acn.dms.ProtocolDefinition protocol) {
			this.Property = property;
			this.ProtocolDefinition = protocol;
			// try to get the protocol node
			ProtocolElement = GetProtocolElement(property,protocol);
			if (ProtocolElement == null) {
				throw new InvalidOperationException(string.Format("property '{0}' has no valid protocol '{1}' with atributes element '{2}'",property.id,protocol.Name,protocol.QName));
			}
			IsConstant = property.HasConstantValue();
			if (!property.HasNullValue()) {
				// determine the data tyoe
				this.DataType = new acn.dms.DataType(property);
				// determine the data size
				if (this.DataType.TypeInfo.HasVariableSize) {
					if (this.DataType.TypeInfo.IsString) {
						acn.ddl.Property maxcodeunits = property.GetPropertyWithBehavior("acn.dms.bset:limitMaxCodeUnits");
						if (maxcodeunits != null) {
							this.DataSize = (uint)acn.dms.TypeInfo.ConvertFromString(maxcodeunits.GetValueString(),acn.dms.TypeInfo.UInt32);
						}
						else {
							// MaxCodeUnits might be omitted in case of constant strings: the length of the default value is the size
							// if a const with initializer: use length of initializer as size
							acn.ddl.Property initial = property.GetPropertyWithBehavior("acnbase.bset:initializer");
							if ((initial != null) && property.HasConstantValue()) {
								string value = initial.GetValueString();
								if (string.IsNullOrEmpty(value)) {
									this.DataSize = 0;
								}
								else {
									this.DataSize = (uint)System.Text.Encoding.UTF8.GetBytes(value).Length;
								}
							}
							else {
								throw new InvalidOperationException(string.Format("MaxCodeUnits not specified on string property '{0}'",property.id));
							}
						}
					}
					else {
						// type tcObject, not supported yet
						throw new NotImplementedException("variable sized tcObject type not implemented yet");
					}
				}
				else {
					this.DataSize = this.DataType.TypeInfo.Size;
				}
			}
		}

		/// Get the protocol attribute with the specified name.
		/// @param name the name of the attribute
		/// @return the attribute value (as string), or null if the (default value of the) attribute is not found
		protected string GetAttribute(string name) {
			string result = ProtocolElement.GetAttribute(name);
			if (string.IsNullOrEmpty(result)) {
				// use the default value
				result = ProtocolDefinition.DefaultAttributes[name].ToString();
			}
			return result;
		}

		/// Get the label text of the property.
		/// @param language optional language specifier
		/// @todo handle generic acnbase.bset:label sub-properties for retrieving dynamic labels
		/// @return the label text, null if not available
		public string GetLabel(string language = null) {
			if ((_Label == null) || (string.CompareOrdinal(language,_Language) != 0)) {
				acn.ddl.Property prop = Property.GetPropertyWithBehavior("acnbase.bset:labelString");
				if (prop != null) {
					_Label = prop.GetValueString(Property.ArrayIndex);
					_Language = null;
				}
				if (_Label == null) {
					_Label = Property.GetLabelText(language);
					_Language = language;
				}
			}
			return _Label;
		}

		/// Try to get the protocol element on the specified property or the specified protocol.
		/// @paraam property the property to get the protocol on
		/// @param protocol the protocol to get
		/// @return the protocol element or null of not found
		/// @exception ArgumentNullException if the property or protocol is null
		public static System.Xml.XmlElement GetProtocolElement(acn.ddl.Property property, acn.dms.ProtocolDefinition protocol) {
			if (property == null) {
				throw new ArgumentNullException("property");
			}
			if (protocol == null) {
				throw new ArgumentNullException("protocol");
			}
			// try to get the protocol node
			acn.ddl.Protocol protocolNode = property.GetProtocol(protocol.Name);
			if (protocolNode != null) {
				System.Xml.XmlElement result = protocolNode.GetElement(protocol.QName,property.ArrayIndex);
				if ((result == null) && (property.ArrayIndex > 0)) {
					// single attribute element (we guess), return that
					result = protocolNode.GetElement(protocol.QName,0);
				}
				return result;
			}
			return null;
		}

		/// Get the key for sorting the property in the list of 'protocol properties'.
		/// By default the property.id is used
		public virtual string GetSortingKey() {
			return Property.id;
		}

		/// Check if the property has read access via the protocol.
		public virtual bool HasReadAccess() {
			return !string.IsNullOrEmpty(Access) && (Access.IndexOf('r') >= 0);
		}

		/// Check if the property has write access via the protocol.
		public virtual bool HasWriteAccess() {
			return !string.IsNullOrEmpty(Access) && (Access.IndexOf('w') >= 0);
		}

		/// Check if the protocol specification is valid
		public virtual bool IsValid() {
			return (Property != null) && (ProtocolElement != null);
		}
	}

	/// Definition and utility class of a communication protocol.
	public class ProtocolDefinition {

		/// The protocol attributes with their default value
		protected OrderedDictionary _defaultAttributes;

		/// Name of the protocol in the acn.ddl.Protocol node
		public string Name { get; protected set; }
		
		/// Qualified XML name of the XmlElement with the protocol attributes
		public string QName { get; protected set; }

		/// The XML namespace of the XmlElement with the protocol attributes
		public string Namespace { get; protected set; }
		
		/// The protocol attributes with their default value
		public OrderedDictionary DefaultAttributes {
			get { return _defaultAttributes.AsReadOnly(); }
		}

		/// Initializing constructor
		public ProtocolDefinition(string name, string qname, string ns, OrderedDictionary attrs) {
			Name = name;
			QName = qname;
			Namespace = ns;
			_defaultAttributes = attrs;
		}
	}

	///
	/// The data type code of a property.
	/// @see https://docs.microsoft.com/en-us/dotnet/api/system.typecode
	///
	public enum TypeCode {

		/// A null reference.
		/// This is not a data type, but may indicate an object without data.
		tcEmpty = 0,

		/// A structured object.
		/// This is not a data type, but an idicator for a structured object, with its own description.
		/// It might be used in implementations that directly map an ACN DDL includedev run-time description.
		tcStruct,

		/// A binary opaque object.
		/// The size of a tcObject is the maximum number of bytes required to store the
		/// (optionally) dynamic sized object, excluding the length.
		/// @note This data type is a fallback and its use must be avoided.
		tcObject,

		/// A Unicode character.
		/// @deprecated Use the tcString type to transfer single characters. This circumvents
		/// the various character / code point / grapheme-cluster definition problems.
		/// @see https://docs.microsoft.com/en-us/dotnet/standard/base-types/character-encoding-introduction#grapheme-clusters
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.text.rune
		tcChar,

		/// A Unicode (UTF-8) character string.
		/// The size of a tcString is the maximum number of bytes required to store the
		/// dynamic sized string, excluding the length (e.g. the NUL terminator or length
		/// attribute).
		/// In ACN DDL read size from MaxCodeUnits subproperty for non-constant strings.
		/// @note On .NET strings are stored in UTF-16 format that will typically require a different size.
		tcString,

		/// An enumerated bitmap (flags) type with a UInt8 base type.
		tcBitmap8,

		/// An enumerated bitmap (flags) type with a UInt32 base type.
		tcBitmap32,

		/// A simple type representing Boolean values of true or false.
		tcBoolean,

		/// An enumeration type with a UInt8 base type.
		tcEnum8,

		/// An enumeration type with a UInt32 base type.
		tcEnum32,

		/// An IEEE 754:2008 single-precision floating point number (binary32)
		tcFloat32,

		/// An IEEE 754:2008 double-precision floating point number (binary64)
		tcFloat64,

		/// An integral type representing signed (at least) 8-bit integers with values between -128 and 127.
		tcInt8,

		/// An integral type representing signed (at least) 16-bit integers with values between -32768 and 32767.
		tcInt16,

		/// An integral type representing signed (at least) 32-bit integers with values between -2147483648 and 2147483647.
		tcInt32,

		/// An integral type representing signed (at least) 64-bit integers with values between -9223372036854775808 and 9223372036854775807.
		tcInt64,

		/// An integral type representing unsigned (at least) 8-bit integers with values between 0 and 255.
		tcUInt8,

		/// An integral type representing unsigned (at least) 16-bit integers with values between 0 and 65535.
		tcUInt16,

		/// An integral type representing unsigned (at least) 32-bit integers with values between 0 and 4294967295.
		tcUInt32,

		/// An integral type representing unsigned (at least) 64-bit integers with values between 0 and 18446744073709551615.
		tcUInt64
	}

	///
	/// Description of a data type.
	///
	public class TypeInfo {
		/// The behavior identifier of the data type
		public string Behavior { get; set; }

		/// The TypeCode of the data type
		public TypeCode Code { get; set; }

		/// The name of the data type
		public string Name { get; set; }

		/// The .NET type for storing the data type
		public System.Type Type { get; set; }

		/// The number of bytes of an object with this data type.
		/// @note 0 means the type has a variable size
		/// @note The definition relies on the .NET type sizes.
		public uint Size { get; set; }
		
		/// The minimum value of the numerical data type
		public object MinValue { get; set; }
		/// The maximum value of the numerical data type
		public object MaxValue { get; set; }
		
		/// Indicates that the data type has a variable size.
		public bool HasVariableSize {
			get { return Size == 0; }
		}

		/// Is it a numerical data type?
		public bool IsNumber {
			get { return (Code >= TypeCode.tcFloat32) && (Code <= TypeCode.tcUInt64); }
		}

		/// Is it a character string data type?
		public bool IsString {
			get { return (Code == TypeCode.tcString); }
		}

		/// Enumerated bitmap flags 8-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.enum
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.flagsattribute
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.byte
		public static readonly TypeInfo Bitmap8 = new TypeInfo {
			Behavior = "acn.dms.bset:type.bitmap8",
			Code = TypeCode.tcBitmap8,
			Name = "bitmap8",
			Type = typeof(byte),
			Size = sizeof(byte)
		};

		/// Enumerated bitmap flags 32-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.enum
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.flagsattribute
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.uint32
		public static readonly TypeInfo Bitmap32 = new TypeInfo {
			Behavior = "acn.dms.bset:type.bitmap32",
			Code = TypeCode.tcBitmap32,
			Name = "bitmap32",
			Type = typeof(uint),
			Size = sizeof(uint)
		};

		/// Boolean data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.boolean
		public static readonly TypeInfo Boolean = new TypeInfo {
			Behavior = "acn.dms.bset:type.boolean",
			Code = TypeCode.tcBoolean,
			Name = "boolean",
			Type = typeof(bool),
			Size = sizeof(bool)
		};

		/// Enumerated value 8-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.enum
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.byte
		public static readonly TypeInfo Enum8 = new TypeInfo {
			Behavior = "acn.dms.bset:type.enum8",
			Code = TypeCode.tcEnum8,
			Name = "enum8",
			Type = typeof(byte),
			Size = sizeof(byte)
		};

		/// Enumerated value 32-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.enum
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.uint32
		public static readonly TypeInfo Enum32 = new TypeInfo {
			Behavior = "acn.dms.bset:type.enum32",
			Code = TypeCode.tcEnum32,
			Name = "enum32",
			Type = typeof(uint),
			Size = sizeof(uint)
		};

		/// Single precision floating-point number 32-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.single
		public static readonly TypeInfo Float32 = new TypeInfo {
			Behavior = "acn.dms.bset:type.float32",
			Code = TypeCode.tcFloat32,
			Name = "float32",
			Type = typeof(float),
			Size = sizeof(float),
			MinValue = System.Single.MinValue,
			MaxValue = System.Single.MaxValue
		};

		/// Double-precision floating-point number 64-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.double
		public static readonly TypeInfo Float64 = new TypeInfo {
			Behavior = "acn.dms.bset:type.float64",
			Code = TypeCode.tcFloat64,
			Name = "float64",
			Type = typeof(double),
			Size = sizeof(double),
			MinValue = System.Double.MinValue,
			MaxValue = System.Double.MaxValue
		};

		/// Signed integer 8-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.sbyte
		public static readonly TypeInfo Int8 = new TypeInfo {
			Behavior = "acn.dms.bset:type.int8",
			Code = TypeCode.tcInt8,
			Name = "int8",
			Type = typeof(sbyte),
			Size = sizeof(sbyte),
			MinValue = System.SByte.MinValue,
			MaxValue = System.SByte.MaxValue
		};

		/// Signed integer 16-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.int16
		public static readonly TypeInfo Int16 = new TypeInfo {
			Behavior = "acn.dms.bset:type.int16",
			Code = TypeCode.tcInt16,
			Name = "int16",
			Type = typeof(short),
			Size = sizeof(short),
			MinValue = System.Int16.MinValue,
			MaxValue = System.Int16.MaxValue
		};

		/// Signed integer 32-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.int32
		public static readonly TypeInfo Int32 = new TypeInfo {
			Behavior = "acn.dms.bset:type.int32",
			Code = TypeCode.tcInt32,
			Name = "int32",
			Type = typeof(int),
			Size = sizeof(int),
			MinValue = System.Int32.MinValue,
			MaxValue = System.Int32.MaxValue
		};

		/// Signed integer 64-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.int64
		public static readonly TypeInfo Int64 = new TypeInfo {
			Behavior = "acn.dms.bset:type.int64",
			Code = TypeCode.tcInt64,
			Name = "int64",
			Type = typeof(long),
			Size = sizeof(long),
			MinValue = System.Int64.MinValue,
			MaxValue = System.Int64.MaxValue
		};

		/// A binary object.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.object
		public static readonly TypeInfo Object = new TypeInfo {
			Behavior = "acnbase.bset:binObject",
			Code = TypeCode.tcObject,
			Name = "object",
			Type = typeof(object),
			Size = 0
		};

		/// A Unicode character string.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.string
		public static readonly TypeInfo String = new TypeInfo {
			Behavior = "acn.dms.bset:type.string",
			Code = TypeCode.tcString,
			Name = "string",
			Type = typeof(string),
			Size = 0
		};

		/// Unsigned integer 8-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.byte
		public static readonly TypeInfo UInt8 = new TypeInfo {
			Behavior = "acn.dms.bset:type.uint8",
			Code = TypeCode.tcUInt8,
			Name = "uint8",
			Type = typeof(byte),
			Size = sizeof(byte),
			MinValue = System.Byte.MinValue,
			MaxValue = System.Byte.MaxValue
		};

		/// Unsigned integer 16-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.uint16
		public static readonly TypeInfo UInt16 = new TypeInfo {
			Behavior = "acn.dms.bset:type.uint16",
			Code = TypeCode.tcUInt16,
			Name = "uint16",
			Type = typeof(ushort),
			Size = sizeof(ushort),
			MinValue = System.UInt16.MinValue,
			MaxValue = System.UInt16.MaxValue
		};

		/// Unsigned integer 32-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.uint32
		public static readonly TypeInfo UInt32 = new TypeInfo {
			Behavior = "acn.dms.bset:type.uint32",
			Code = TypeCode.tcUInt32,
			Name = "uint32",
			Type = typeof(uint),
			Size = sizeof(uint),
			MinValue = System.UInt32.MinValue,
			MaxValue = System.UInt32.MaxValue
		};

		/// Unsigned integer 64-bit data type.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.uint64
		public static readonly TypeInfo UInt64 = new TypeInfo {
			Behavior = "acn.dms.bset:type.uint64",
			Code = TypeCode.tcUInt64,
			Name = "uint64",
			Type = typeof(ulong),
			Size = sizeof(ulong),
			MinValue = System.UInt64.MinValue,
			MaxValue = System.UInt64.MaxValue
		};

		/// Map from behavior identifier to TypeInfo
		private static readonly Dictionary<string, TypeInfo> TypeInfoByBehavior = new Dictionary<string, TypeInfo>
		{
			{ Boolean.Behavior, Boolean }, { String.Behavior, String },
			{ UInt8.Behavior, UInt8 }, { UInt16.Behavior, UInt16 }, { UInt32.Behavior, UInt32 }, { UInt64.Behavior, UInt64 },
			{ Int8.Behavior, Int8 }, { Int16.Behavior, Int16 }, { Int32.Behavior, Int32 }, { Int64.Behavior, Int64 },
			{ Float32.Behavior, Float32 }, { Float64.Behavior, Float64 },
			{ Bitmap8.Behavior, Bitmap8 }, { Bitmap32.Behavior, Bitmap32 },
			{ Enum8.Behavior, Enum8 }, { Enum32.Behavior, Enum32 },
		};
		/// Map from TypeCode to TypeInfo
		private static readonly Dictionary<TypeCode, TypeInfo> TypeInfoByCode = new Dictionary<TypeCode, TypeInfo>
		{
			{ Boolean.Code, Boolean }, { String.Code, String },
			{ UInt8.Code, UInt8 }, { UInt16.Code, UInt16 }, { UInt32.Code, UInt32 }, { UInt64.Code, UInt64 },
			{ Int8.Code, Int8 }, { Int16.Code, Int16 }, { Int32.Code, Int32 }, { Int64.Code, Int64 },
			{ Float32.Code, Float32 }, { Float64.Code, Float64 },
			{ Bitmap8.Code, Bitmap8 }, { Bitmap32.Code, Bitmap32 },
			{ Enum8.Code, Enum8 }, { Enum32.Code, Enum32 },
		};
		
		/// Convert the specified string value to the specified datatype.
		/// @param value the value to convert
		/// @param typeInfo the target data type
		/// @return the converted value in the datatype, null if
		///   conversion is not possible
		public static object ConvertFromString(string value, acn.dms.TypeInfo typeInfo) {
			object result = null;
			if (value != null) {
				try {
					switch (typeInfo.Code) {
					case acn.dms.TypeCode.tcUInt8:
					case acn.dms.TypeCode.tcEnum8:
					case acn.dms.TypeCode.tcBitmap8:
						if (IsHexadecimalNumber(value)) {
							result = System.Convert.ToByte(value,16);
						}
						else {
							result = System.Convert.ToByte(value);
						}
						break;
					case acn.dms.TypeCode.tcUInt16:
						if (IsHexadecimalNumber(value)) {
							result = System.Convert.ToUInt16(value,16);
						}
						else {
							result = System.Convert.ToUInt16(value);
						}
						break;
					case acn.dms.TypeCode.tcUInt32:
					case acn.dms.TypeCode.tcEnum32:
					case acn.dms.TypeCode.tcBitmap32:
						if (IsHexadecimalNumber(value)) {
							result = System.Convert.ToUInt32(value,16);
						}
						else {
							result = System.Convert.ToUInt32(value);
						}
						break;
					case acn.dms.TypeCode.tcUInt64:
						if (IsHexadecimalNumber(value)) {
							result = System.Convert.ToUInt64(value,16);
						}
						else {
							result = System.Convert.ToUInt64(value);
						}
						break;
					case acn.dms.TypeCode.tcInt8:
						if (IsHexadecimalNumber(value)) {
							result = System.Convert.ToSByte(value,16);
						}
						else {
							result = System.Convert.ToSByte(value);
						}
						break;
					case acn.dms.TypeCode.tcInt16:
						if (IsHexadecimalNumber(value)) {
							result = System.Convert.ToInt16(value,16);
						}
						else {
							result = System.Convert.ToInt16(value);
						}
						break;
					case acn.dms.TypeCode.tcInt32:
						if (IsHexadecimalNumber(value)) {
							result = System.Convert.ToInt32(value,16);
						}
						else {
							result = System.Convert.ToInt32(value);
						}
						break;
					case acn.dms.TypeCode.tcInt64:
						if (IsHexadecimalNumber(value)) {
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
						throw new InvalidOperationException(string.Format("conversion to type {0} not implemented",typeInfo.Name));
					}
				}
				catch (Exception ex) {
					throw new InvalidOperationException(string.Format("conversion of '{0}' to type {1} failed",value,typeInfo.Name),ex);
				}
			}
			return result;
		}

		/// Get the TypeCode as string.
		public string GetTypeCodeAsString() {
			return System.Enum.GetName(typeof(acn.dms.TypeCode),Code);
		}

		/// Get the TypeInfo that corresponds with the specified ACN DDL qualified behavior identifier.
		/// @param behavior the qualified behavior identifier ('bset:name')
		/// @return the corresponding TypeInfo
		/// @exception ArgumentNullException if the behavior is null
		/// @exception KeyNotFoundException if the behavior does not represent a (known) data type
		public static TypeInfo GetTypeInfoByBehavior(string behavior) {
			return TypeInfoByBehavior[behavior];
		}

		/// Get the TypeInfo that corresponds with the specified data type code.
		/// @param code the TypeCode
		/// @return the corresponding TypeInfo
		public static TypeInfo GetTypeInfoByCode(TypeCode code) {
			return TypeInfoByCode[code];
		}

		/// Detect a hexadecimal number, C-style.
		private static bool IsHexadecimalNumber(string value) {
			return value.StartsWith("0x") || value.StartsWith("0X");
		}
	}

}
