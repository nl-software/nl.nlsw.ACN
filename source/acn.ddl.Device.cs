//	__ _ ____ _  _ _    _ ____ ____   ____ ____ ____ ___ _  _ ____ ____ ____
//	| \| |=== |/\| |___ | |--- |===   ==== [__] |---  |  |/\| |--| |--< |===
//
/// @file acn.ddl.Device.cs
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
using nl.nlsw.Identifiers;
using nl.nlsw.Items;

///
/// The Device Description Language (DDL) is the formal specification language of the
/// communication interface of devices in the ANSI E1.17 Architecture for Control Networks (ACN).
///
/// In the DDL of ACN a device is described as a hierarchical tree of properties and subdevices. 
/// The classes in this namespace use the ACN DDL terminology.
///
/// Many of the classes in this namespace have two (partial) implementations:
/// - one generated from the ACN-DDL-1.1.xsd, representing the ADC DDL data elements
/// - one manual implementation with additional functionality.
///
/// The generated part enables (de)serialization of the XML files with the XmlSerializer. This
/// supports 'strict' processing of DDL documents.
///
/// The generation of acn.ddl.1.1.xsd.cs from the ACN-DDL-1.1.xsd schema is as followes:
/// <code>
/// 	xsd .\ACN-DDL-1.1.xsd /c /order /n:acn.ddl
/// 	move ACN-DDL-1_1.cs ../acn.ddl.1.1.xsd.cs
/// </code>
///
/// These classes conform to the ACN DDL specification, with the following extensions, or limitations:
///
/// - It is assumed that properties have an xml:id specified for identification. Presence is not enforced.
///
/// - The restriction on the length of UUIDName.name to 32 characters (or at least < 36) is lifted.
///   Discrimination between UUID and a name should be done:
///   - by looking the name up in the UUIDnames (used in XSL templates)
///   - match the string with UUID regex (used in C#)
///
/// - A ddl:section in a behavior definition may contain not only a ddl:hd, ddl:p, and ddl:section,
///   but also any element from the html namespace. This is an extension of the ACN DDL schema.
///   Main purpose is to allow for hyperlinked references to external definitions in the behavior description.
///   Authors are advised to only include html:p or html:section elements in the ddl:section, encapsulating
///   a limited part of the description with HTML markup.
///   Authors should be aware that other ACN DDL processors may drop the data in the html elements.
///
/// - There is not a full coverage of all use cases of the language (yet). Untested / unsupported features include:
///   - multi-dimensional arrays, and any combination of nested arrays
///   - parameters
///
/// A preserving mode of processing DDL documents with additional data, like comments, and
/// extended XML is supported via the Node.DOMNode link. This enables editing the DDL document
/// without losing the additional data.
///
/// The main classes in this namespace are:
///
/// - acn.ddl.DocumentList
///   A container of ACN DDL documents.
///
/// - acn.ddl.Document
///   The representation of an ACN DDL document. It inherits from nl.nlsw.Items.ItemObject,
///   the class that interacts with the DocumentList (derived from ItemList).
///
/// - acn.ddl.Node
///   Base class of all nodes in an acn.ddl.Document.
///   It handles the (optional) link to a corresponding XmlNode (DOMNode).
///
/// - acn.ddl.DDLDocument
///   The representation of the ddl:DDL document element (a.k.a. root node).
///
/// - acn.ddl.Module
///   The base class of acn.ddl.Device, acn.ddl.BehaviorSet, and acn.ddl.LanguageSet.
///
/// - acn.ddl.Device
///   The representation of a ddl:device.
///
/// - acn.ddl.Property
///   The representation of a ddl:property.
///
///
/// @author Ernst van der Pols
/// @date 2022-04-15
/// @pre .NET Standard 2.0
///
namespace acn.ddl {

	///
	/// Base class for document nodes
	///
	public class Node {
		/// The default XML namespace of ACN DDL documents
		public const string DDLNamespace = "http://www.esta.org/acn/namespace/ddl/2008/";

		/// Reference to a corresponding node in an XmlDocument
		[System.Xml.Serialization.XmlIgnoreAttribute()]
		public XmlNode DOMNode { get; set; }

		/// The parent node of this node
		[System.Xml.Serialization.XmlIgnoreAttribute()]
		public Node ParentNode { get; set; }

		/// Default constructor
		public Node() {
		}

		/// Add one or more items to the specified array.
		/// @param array the array to add the item to
		/// @param newItems the items to add
		public static void ArrayAdd<T>(ref T[] array, params T[] newItems) {
			int oldLength = array == null ? 0 : array.Length;
			Array.Resize(ref array, oldLength + newItems.Length);
			newItems.CopyTo(array, oldLength);
		}

		/// Add one or more Node items to the specified array.
		/// The array must be a member of 'this' node, making it the
		/// ParentNode of the new items.
		/// This operation will perform additional actions establishing the relationship.
		/// @param array the member array to add the item to
		/// @param newItems the items to add
		protected void ArrayAddChildNode<T>(ref T[] array, params T[] newItems) {
			ArrayAdd(ref array,newItems);
			// update the whole array or only the new items?
			this.UpdateChildNodesIn(newItems);
			this.NotifyNodeChanged();
		}

		/// Raise a Node Changed event.
		/// If the node has a DDLDocument root node, its Module.IsChanged property will be set.
		public void NotifyNodeChanged() {
			DDLDocument root = GetDDLDocument();
			if (root != null && root.Module != null) {
				root.Module.IsChanged = true;
			}
		}
		
		/// Get the ancestor DDLDocument of this node.
		/// The DDLDocument is the root node of the DDL tree.
		/// @return the DDLDocument of the node
		/// @pre all ParentNode members are initialized
		public DDLDocument GetDDLDocument() {
			Node node = this;
			while (node.ParentNode != null) {
				node = node.ParentNode;
			}
			return node as DDLDocument;
		}

		/// Get the child node with the specified index.
		/// @return the node with the specified index, or null if index out of range
		public virtual Node GetChildNode(int index) {
			return null;
		}

		/// Get the number of child nodes
		public virtual int GetChildNodeCount() {
			return 0;
		}

		/// Safely get the number of children in the specified array.
		/// It is a helper function for the GetChildNodeCount() operation.
		protected int GetChildNodeCountOf<T>(T[] array) {
			return (array == null ? 0 : array.Length);
		}

		/// Safely get the number of children of the specified node.
		/// It is a helper function for the GetChildNodeCount() operation.
		protected int GetChildNodeCountOf(Node node) {
			return (node == null ? 0 : 1);
		}

		/// Get the index of this node in its parent list of child nodes.
		/// @return the index of the node, -1 is the node has no parent (or is not a child of its parent)
		public int GetChildNodeIndex() {
			Node parent = ParentNode;
			if (parent != null) {
				int count = parent.GetChildNodeCount();
				for (int i = 0; i < count; i++) {
					if (parent.GetChildNode(i) == this) {
						return i;
					}
				}
			}
			return -1;
		}

		/// Get the Device of this node.
		/// @note This operation is only useful on nodes that are valid
		///    descendants of a Device.
		/// @return the Device of this node or null if not found.
		public acn.ddl.Device GetDevice() {
			return GetModule() as acn.ddl.Device;
		}
		
		/// Get the owning Document of this node.
		/// The Document holds the DDLDocument as RootNode and is, as ItemObject, the container
		///   of the module document in the DocumentList.
		/// @return the Document of the node, or null if not available
		/// @pre all ParentNode members are initialized
		public acn.ddl.Document GetDocument() {
			acn.ddl.DDLDocument ddl = GetDDLDocument();
			if (ddl != null) {
				return ddl.Document;
			}
			return null;
		}
		
		/// Get the Module of this node.
		/// @note This operation is only useful on nodes that are valid
		///    descendants of a Module.
		/// @return the Module of this node or null if not found.
		public acn.ddl.Module GetModule() {
			Node node = this;
			do {
				if (node is acn.ddl.Module) {
					return node as acn.ddl.Module;
				}
				node = node.ParentNode;
			} while (node != null);
			return null;
		}
		
		/// Get the DOMDocument of the node, and create one if needed.
		/// @return the DOMDocument of the node
		/// @exception InvalidOperationException if the DOMDocument cannot be created
		public System.Xml.XmlDocument GetOrCreateDOMDocument() {
			System.Xml.XmlDocument result = null;
			if (DOMNode != null) {
				// we have already an associated XmlNode: get its owner
				result = DOMNode.OwnerDocument;
			}
			if (result == null) {
				// trace the root back via our own ParentNode
				acn.ddl.Document doc = GetDocument();
				if (doc == null) {
					throw new InvalidOperationException("cannot create a DOMDocument if the node is not part of a document tree");
				}
				if (doc.DOMDocument == null) {
					result = new System.Xml.XmlDocument();
					doc.DOMDocument = result;
					// @todo UpdateNode to construct the corresponding XmlDocument tree
					result.AppendChild(result.CreateXmlDeclaration("1.0", "UTF-8", null));
				}
				result = doc.DOMDocument;
			}
			return result;
		}
		
		/// Get the Module referenced with the specified UUID or name.
		/// @note This operation is only useful on nodes that are valid
		///    descendants of a Module.
		/// @return the referenced Module or null if not found.
		public acn.ddl.Module GetReferencedModule(string uuid) {
			acn.ddl.Module module = GetModule();
			if (module != null) {
				// node is part of a module
				return module.GetOrLoadModuleByUUIDname(uuid);
			}
			return null;
		}
		
		/// Check if the two module reference names refer to the same module.
		/// @param name1 a UUID or a UUIDname
		/// @param name2 a UUID or a UUIDname
		/// @return true if name1 and name2 refer to the same module
		public bool MatchModuleIdentifier(string name1, string name2) {
			if (name1 == name2) {
				return true;
			}
			acn.ddl.Module module = GetModule();
			if (module != null) {
				acn.ddl.UUIDName uuidname = module.GetUUIDname(name1);
				if (uuidname != null) {
					return uuidname.Matches(name2);
				}
			}
			return false;
		}

		/// Conditionally register the namespace of an XmlElement.
		/// XmlElements added to the tree with a non-default namespace should
		/// register their namespace in the DDLDocument node.
		/// This prevents the namespace written to each node in the output format.
		/// @param elementQName the qualified element name
		/// @param namespaceURI the XML namespace associated with the elementQName
		public void RegisterXmlNamespace(string elementQName, string namespaceURI) {
			if (!string.IsNullOrEmpty(elementQName) && (namespaceURI != DDLNamespace)) {
				// register the namespace if the elementName has a prefix
				int colon = elementQName.IndexOf(':');
				if (colon >= 0) {
					string prefix = elementQName.Substring(0,colon);
					if (!string.IsNullOrEmpty(prefix)) {
						acn.ddl.DDLDocument doc = GetDDLDocument();
						if (doc != null) {
							// if already present, it will not be added twice
							doc.XmlNamespaces.Add(prefix,namespaceURI);
						}
					}
				}
			}
		}

		/// Update the tree state of the child nodes.
		/// This operation is e.g. called after deserialization of a tree (fragment).
		/// It must be overriden in each descendant class with child nodes.
		/// For each child node the UpdateChildNodesIn() operation must be called,
		/// after calling UpdateChildNodes() of the base class.
		protected virtual void UpdateChildNodes() {
		}

		/// Recursively update the child nodes in the specified child node.
		/// - Sets the ParentNode of the child node to 'this'.
		/// - Calls UpdateChildNodes() on the child node.
		/// @param childNode the child node
		protected void UpdateChildNodesIn(Node childNode) {
			if (childNode != null) {
				childNode.ParentNode = this;
				childNode.UpdateChildNodes();
			}
		}

		/// Recursively update the child nodes in the specified object array.
		/// This operation calls UpdateChildNodesIn() for each Node in the array.
		protected void UpdateChildNodesIn<T>(T[] array) {
			if (array is object[]) {
				foreach (object child in (array as object[])) {
					UpdateChildNodesIn(child as Node);
				}
			}
		}

		/// Update the tree state of the node.
		/// This operation is e.g. called after deserialization of a tree (fragment). It performs:
		/// - Set the ParentNode on all child nodes.
		/// - Synchronize the Node and the corresponding DOMNode. (not implemented yet)
		///   - if node == null, a corresponding DOMNode is created or updated based on the Node properties.
		///   - if node != null, the properties of the Node are set based on the corresponding XmlNode.
		public virtual void UpdateNode(XmlNode node = null) {
			DOMNode = node;
			UpdateChildNodes();
		}

		///
		/// Verify the specified Module reference identifier (UUID or UUIDname) for the current node.
		/// - If the id is not a UUID, check that this identifier is registered in the UUIDnames of the node's Module
		/// @param id the identifier to verify
		/// @exception ArgumentNullException the identifier is null or empty
		/// @exception InvalidOperationException the reference module is not registered
		///
		public void VerifyModuleIdentifier(string id) {
			if (string.IsNullOrEmpty(id)) {
				throw new ArgumentNullException("id");
			}
			// make sure the module is registered in the module's UUIDName or is a UUID
			acn.ddl.Module module = GetModule();
			if ((module != null) && !UUIDName.IsUUID(id) && (module.GetUUIDname(id) == null)) {
				throw new InvalidOperationException(string.Format("module '{0}' not registered in UUIDNames of module {1}",id,module.id));
			}
		}

		///
		/// Verify the specified identifier to the rules for an 'xml:id' attribute.
		/// @param id the identifier to verify
		/// @exception XmlException the identifier is not a valid NCName
		/// @exception ArgumentNullException the identifier is null or empty
		/// @see https://www.w3.org/TR/xml-id/
		///
		public static void VerifyNodeIdentifier(string id) {
			if (string.IsNullOrEmpty(id)) {
				throw new ArgumentNullException("id");
			}
			// first perform some normalization as specified in https://www.w3.org/TR/xml-id/#id-avn
			id = id.Trim();
			XmlConvert.VerifyNCName(id);
		}
	}

	/// Constants returned by INodeFilter.acceptNode()
	public enum NodeFilterResult : short
	{
		/// Accept the node. Navigation methods defined for NodeIterator or TreeWalker will return this node.
		FILTER_ACCEPT = 1,
		/// Reject the node. Navigation methods defined for NodeIterator or TreeWalker will not return this node.
		/// For TreeWalker, the children of this node will also be rejected. NodeIterators treat this as a synonym for FILTER_SKIP.
		FILTER_REJECT = 2,
		/// Skip this single node. Navigation methods defined for NodeIterator or TreeWalker will not return this node.
		/// For both NodeIterator and TreeWalker, the children of this node will still be considered.
		FILTER_SKIP = 3
	}

	/// A node filter is an object that knows how to "filter out" nodes.
	/// If an INodeIterator or ITreeWalker is given a NodeFilter, it applies the filter before it
	/// returns the next node. If the filter says to accept the node, the traversal logic returns it;
	/// otherwise, traversal looks for the next node and pretends that the node that was rejected was not there.
	///
	/// This interface is based on the W3 Document Object Model NodeFilter interface, but adapted for 
	/// acn.ddl.Node types.
	///
	/// @see https://www.w3.org/TR/DOM-Level-2-Traversal-Range/traversal.html#Traversal-NodeFilter
	public interface INodeFilter {
		/// Test whether a specified node is visible in the logical view of a TreeWalker or NodeIterator.
		/// This function will be called by the implementation of TreeWalker and NodeIterator;
		/// it is not normally called directly from user code. (Though you could do so if you wanted to use
		/// the same filter to guide your own application logic.)
		/// @param node The node to check to see if it passes the filter or not.
		/// @return a constant to determine whether the node is accepted, rejected, or skipped
		NodeFilterResult acceptNode(Node node);
	}

	/// NodeIterator objects are used to step through a document tree or subtree in document order
	/// using the view of the document defined by the optional filter.
	///
	/// This interface is based on a W3 Document Object Model NodeIterator, without the WhatToShow feature.
	/// 
	/// It also has an IEnumerator interface to support .NET foreach usage.
	/// @see https://www.w3.org/TR/DOM-Level-2-Traversal-Range/traversal.html#Traversal-NodeIterator
	/// @see https://docs.microsoft.com/en-us/dotnet/api/system.collections.generic.ienumerator-1
	/// @see https://docs.microsoft.com/en-us/dotnet/api/system.collections.ienumerator
	public interface INodeIterator : System.Collections.Generic.IEnumerator<Node> {

		/// The root node of the NodeIterator, as specified when it was created.
		Node root { get; }

		/// The filter used to hide nodes from the view.
		INodeFilter filter { get; }

		/// Detaches the NodeIterator from the set which it iterated over,
		/// releasing any computational resources and placing the iterator in the INVALID state.
		/// After detach() has been invoked, calls to nextNode() or previousNode() will raise an InvalidOperationException.
		/// This operation is called in the IDisposable.Dispose() operation.
		void detach();

		/// Returns the next node in the set and advances the position of the iterator in the set. After a NodeIterator is created, the first call to nextNode() returns the first node in the set.
		/// @return The next Node in the set being iterated over, or null if there are no more members in that set.
		/// @exception InvalidOperationException if this method is called after the detach method was invoked.
		Node nextNode();

		/// Returns the previous node in the set and moves the position of the NodeIterator backwards in the set.
		/// @return The previous Node in the set being iterated over, or null if there are no more members in that set.
		/// @exception InvalidOperationException if this method is called after the detach method was invoked.
		Node previousNode();

	}

	/// TreeWalker objects are used to navigate a document tree or subtree using the view of the document
	/// defined by the optional filter. 
	/// This class has the interface and behavior of a W3 Document Object Model TreeWalker,
	/// without the WhatToShow feature.
	/// @see https://www.w3.org/TR/DOM-Level-2-Traversal-Range/traversal.html#Traversal-TreeWalker
	public interface ITreeWalker {

		/// The root node of the TreeWalker, as specified when it was created.
		Node root { get; }

		/// The node at which the TreeWalker is currently positioned.
		/// Alterations to the node tree may cause the current node to no longer be accepted by the
		/// TreeWalker's associated filter. currentNode may also be explicitly set to any node, whether
		/// or not it is within the subtree specified by the root node or would be accepted by the filter
		/// and whatToShow flags. Further traversal occurs relative to currentNode even if it is not part
		/// of the current view, by applying the filters in the requested direction; if no traversal is possible,
		/// currentNode is not changed.
		/// @exception System.NotSupportedException on setting currentNode to null
		Node currentNode { get; set; }
		
		/// The filter used to hide nodes from the view.
		INodeFilter filter { get; }

		/// Moves the TreeWalker to the first visible child of the current node, and returns the new node.
		/// If the current node has no visible children, returns null, and retains the current node.
		/// @return The new node, or null if the current node has no visible children in the TreeWalker's logical view.
		Node firstChild();

		/// Moves the TreeWalker to the last visible child of the current node, and returns the new node. If the current node has no visible children, returns null, and retains the current node.
		/// @return The new node, or null if the current node has no children in the TreeWalker's logical view.
		Node lastChild();

		/// Moves the TreeWalker to the next visible node in document order relative to the current node, and returns the new node. If the current node has no next node, or if the search for nextNode attempts to step upward from the TreeWalker's root node, returns null, and retains the current node.
		/// @return The new node, or null if the current node has no next node in the TreeWalker's logical view.
		Node nextNode();

		/// Moves the TreeWalker to the next sibling of the current node, and returns the new node. If the current node has no visible next sibling, returns null, and retains the current node.
		/// @return The new node, or null if the current node has no next sibling. in the TreeWalker's logical view.
		Node nextSibling();

		/// Moves to and returns the closest visible ancestor node of the current node.
		/// If the search for parentNode attempts to step upward from the TreeWalker's root node,
		/// or if it fails to find a visible ancestor node, this method retains the current position and returns null.
		/// @return The new parent node, or null if the current node has no parent in the TreeWalker's logical view.
		Node parentNode();

		/// Moves the TreeWalker to the previous sibling of the current node, and returns the new node. If the current node has no visible previous sibling, returns null, and retains the current node.
		/// @return The new node, or null if the current node has no previous sibling. in the TreeWalker's logical view.
		Node previousSibling();

		/// Moves the TreeWalker to the previous visible node in document order relative to the current node, and returns the new node. If the current node has no previous node, or if the search for previousNode attempts to step upward from the TreeWalker's root node, returns null, and retains the current node.
		/// @return The new node, or null if the current node has no previous node in the TreeWalker's logical view.
		Node previousNode();
	}

	///
	/// An ACN DDL Appliance.
	///
	/// A DDL device is a module that describes a piece of equipment or a part of it.
	///
	/// A root device is a device that has no parent device. An appliance is the entire
	/// device structure formed by a root device and all of its children and descendants.
	///
	/// An appliance can be considered as the run-time object instance of a class,
	/// being the root device.
	///
	/// Although an appliance could be considered as a property of the device module,
	/// the reason for using Property as base class is to have a single API for the
	/// whole appliance tree and the regular properties of a device module.
	///
	public class Appliance : acn.ddl.Property, System.Collections.IEnumerable {
		
		private acn.ddl.Device _RootDevice = null;
	
		/// The root device of the appliance.
		/// This is the root device module that describes the device.
		public acn.ddl.Device RootDevice {
			get { return _RootDevice; }
			set { _RootDevice = value; }
		}
	
		/// Default constructor
		private Appliance() : base() {
		}

		/// Initializing constructor
		/// @param rootDevice the root device to create the appliance of
		public Appliance(acn.ddl.Device rootDevice) : base() {
			_RootDevice = rootDevice;
			// Build the appliance from its description
			BuildAppliance();
		}
		
		/// Build the appliance based on the RootDevice description
		public void BuildAppliance() {
			if (RootDevice != null) {
				this.id = RootDevice.id;
				this.label = RootDevice.label;
				CompileNodes(this, RootDevice.Items);
			}
		}

		/// Compile the nodes as child of the specified parent property.
		/// @param parent the parent property
		/// @param nodes the nodes to compile
		public void CompileNodes(acn.ddl.Property parent, acn.ddl.IdentifiedNode[] nodes) {
			if (parent == null) {
				throw new ArgumentNullException("parent");
			}
			if (nodes != null) {
				foreach (acn.ddl.IdentifiedNode node in nodes) {
					if (node is acn.ddl.Property) {
						CompileProperty(parent,node as acn.ddl.Property);
					}
					else if (node is acn.ddl.IncludeDevice) {
						CompileIncludeDevice(parent,node as acn.ddl.IncludeDevice);
					}
					else if (node is acn.ddl.PropertyPointer) {
						CompilePropertyPointer(parent,node as acn.ddl.PropertyPointer);
					}
					else {
						throw new InvalidOperationException(string.Format("property child node of invalid type {0}","node"));
					}
				}
			}
		}

		/// Compile the property pointer as child of the specified parent property.
		/// @param parent the parent property
		/// @param include the includedev to compile
		public void CompileIncludeDevice(acn.ddl.Property parent, acn.ddl.IncludeDevice includedev) {
			acn.ddl.Device device = includedev.GetDefinition();
			if (device != null) {
				// create a NULL property as wrapper instance of the included device
				acn.ddl.Property prop = new acn.ddl.Property(includedev.id,acn.ddl.PropertyValueType.NULL);
				// add the property to the parent
				// NOTE prevent (shallow) child nodes from being updated: add before assigning children
				parent.AddProperty(prop);
				// keep a reference to the source definition
				prop.Definition = includedev;
				
				// @todo check unique id (?)
				prop.id = includedev.id;
				prop.label = includedev.label;
				prop.array = includedev.array;
				prop.protocol = includedev.protocol;
				// @todo handle setparam
				// @todo set pop.Definition
				
				CompileNodes(prop, device.Items);
			}
		}

		/// Compile the property as child of the specified parent property.
		/// @param parent the parent property
		/// @param property the property to compile
		public void CompileProperty(acn.ddl.Property parent, acn.ddl.Property property) {
			// create a shallow copy of the property
			acn.ddl.Property prop = new acn.ddl.Property(property.id,property.valuetype);
			// add the property to the parent
			// NOTE prevent (shallow) child nodes from being updated: add before assigning children
			parent.AddProperty(prop);
			// keep a reference to the source definition
			prop.Definition = property;
			prop.sharedefine = property.sharedefine;
			
			// create shallow copies of label, behaviors, values, and protocols
			// @todo check unique id (?)
			prop.id = property.id;
			prop.label = property.label;
			prop.array = property.array;
			prop.array = property.array;
			prop.behavior = property.behavior;
			prop.protocol = property.protocol;
			prop.value = property.value;

			// @todo resolve parameters
			prop.arrayparamname = property.arrayparamname;
			prop.valuetypeparamname = property.valuetypeparamname;
			prop.sharedefineparamname = property.sharedefineparamname;
			
			// compile the child nodes of the property (if any)
			CompileNodes(prop, property.Items);
		}

		/// Compile the property pointer as child of the specified parent property.
		/// @param parent the parent property
		/// @param pointer the property pointer to compile
		private void CompilePropertyPointer(acn.ddl.Property parent, acn.ddl.PropertyPointer pointer) {
			if (pointer != null) {
				// @todo lookup the property and then compile that into this location
			}
		}

		/// Get the child node with the specified index.
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			return base.GetChildNode(index);
		}

		/// Get the number of child nodes
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount();
		}

		System.Collections.IEnumerator System.Collections.IEnumerable.GetEnumerator() {
			return (System.Collections.IEnumerator)GetNodeIterator();
		}

		public NodeIterator GetNodeIterator(INodeFilter filter = null) {
			return new NodeIterator(this,filter);
		}
	}

    public partial class Behavior : BehaviorReference {

        /// Default constructor
		public Behavior() : base() {
		}
		
        /// Initializing constructor
		/// @param set the UUID (or UUIDname) of the BehaviorSet (max length = 36)
		/// @param name the name of the behavior
		/// @exception XmlException if set is not a NMTOKEN or name is not an NCName
		/// @exception ArgumentException if set.Length > 36
		public Behavior(string set, string name) : base(set,name) {
		}
	}

    public partial class BehaviorDefinition : LabeledElement {

        /// Default constructor
		public BehaviorDefinition() : base() {
		}
		
        /// Initializing constructor
		/// @param id the (optional) identifier of the BehaviorDefinition
		/// @param name the name of the behavior
		/// @param label the label of the behavior
		/// @exception XmlException the name is not a valid NCName
		public BehaviorDefinition(string id, string name, string label = null) : base(id,label) {
			System.Xml.XmlConvert.VerifyNCName(name);
			this.name = name;
		}
		
		/// Add a reference to a BehaviorDefinition that this one refines.
		/// If the reference to the specified behavior is already present, nothing happens.
		/// @todo exception on a circular reference
		/// @param set the UUID(name) of the BehaviorSet of the refined behavior
		/// @param name the name of the refined behavior
		public void AddRefines(string set, string name) {
			if (GetRefines(set,name) == null) {
				acn.ddl.Refines result = new acn.ddl.Refines(set,name);
				ArrayAddChildNode(ref refinesField, result);
			}
		}
		
		/// Recursively find the behavior with the specified name (start) and (optionally) set.
		/// The name is matched with the start of the specified behavior name, e.g. "type."
		/// The set can be set to null to allow any set.
		/// @param set the behaviorset of the behavior, if null any set
		/// @param name the (start of the) name of the behavior
		/// @return the matching Behavior(Reference) or null if not found.
		public acn.ddl.BehaviorReference FindBehavior(string set, string name) {
			if (refinesField != null) {
				foreach (acn.ddl.Refines refines in refinesField) {
					acn.ddl.BehaviorReference result = refines.FindBehavior(set,name);
					if (result != null) {
						return result;
					}
				}
			}
			return null;
		}

		/// Get the child node with the specified index.
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			int count = base.GetChildNodeCount();
			if ((index >= 0) && (index < count)) {
				return base.GetChildNode(index);
			}
			index -= count;
			count = GetChildNodeCountOf(refinesField);
			if ((index >= 0) && (index < count)) {
				return refinesField[index];
			}
			index -= count;
			count = GetChildNodeCountOf(sectionField);
			if ((index >= 0) && (index < count)) {
				return sectionField[index];
			}
			return null;
		}

		/// Get the number of child nodes
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount()
					+ GetChildNodeCountOf(refinesField)
					+ GetChildNodeCountOf(sectionField);
		}

		/// Get the Refines reference of the specified behavior.
		/// @return the Refines reference of the specified behavior, null if not present.
		public acn.ddl.Refines GetRefines(string set, string name) {
			if (refinesField != null) {
				foreach (acn.ddl.Refines refines in refinesField) {
					if (refines.name == name && MatchModuleIdentifier(refines.set,set)) {
						return refines;
					}
				}
			}
			return null;
		}

		/// Recursively test if this behavior definition refines the specified behavior.
		/// @param set the behaviorset of the behavior
		/// @param name the name of the behavior
		/// @return true if the behavior definition refines the specified behavior, false otherwise.
		public bool RefinesBehavior(string set, string name) {
			if (refinesField != null) {
				foreach (acn.ddl.Refines refines in refinesField) {
					if (refines.HasBehavior(set, name)) {
						return true;
					}
				}
			}
			return false;
		}

		protected override void UpdateChildNodes() {
			base.UpdateChildNodes();
			UpdateChildNodesIn(refinesField);
			UpdateChildNodesIn(sectionField);
		}
	}

    public partial class BehaviorReference : IdentifiedNode {
		
		/// Separator of the set and name, or prefix and local part
		/// of the qualified behavior reference name.
		public const char QNameSeparator = ':';

        /// Default constructor
		public BehaviorReference() : base() {
		}
		
        /// Initializing constructor
		/// @param set the UUID (or UUIDname) of the BehaviorSet
		/// @param name the name of the behavior
		/// @exception XmlException if set is not a NMTOKEN or name is not an NCName
		public BehaviorReference(string set, string name) : base() {
			System.Xml.XmlConvert.VerifyNMTOKEN(set);
			System.Xml.XmlConvert.VerifyNCName(name);
			this.set = UUIDName.NormalizeUUID(set);
			this.name = name;
		}
		
		/// Get the behavior definition of this behavior reference
		public acn.ddl.BehaviorDefinition GetDefinition() {
			acn.ddl.Module module = GetModule();
			if (module != null) {
				// node is part of a module
				module = module.GetOrLoadModuleByUUIDname(this.set);
				if (module != null) {
					if (!(module is acn.ddl.BehaviorSet)) {
						throw new InvalidOperationException(string.Format("invalid behavior reference '{0}:{1}': not a behaviorset",this.set,this.name));
					}
					acn.ddl.BehaviorSet bset = module as acn.ddl.BehaviorSet;
					acn.ddl.BehaviorDefinition result = bset.GetBehaviorDef(this.name);
					if (result == null) {
						throw new InvalidOperationException(string.Format("behavior '{1}' not found in set '{0}'",this.set,this.name));
					}
					return result;
				}
				else {
					throw new InvalidOperationException(string.Format("behaviorset '{0}' not found",this.set));
				}
			}
			return null;
		}
		
		/// Get the local part of the qualified name.
		/// @param qname the qualified name
		/// @return the local part of the qualified name
		public static string GetNameOfQName(string qname) {
			if (qname != null) {
				int colon = qname.IndexOf(QNameSeparator);
				return (colon < 0) ? qname : qname.Substring(colon + 1);
			}
			return null;
		}
		
		/// Get the set (or prefix) part of the qualified name.
		/// @param qname the qualified name
		/// @return the prefix part of the qualified name
		public static string GetPrefixOfQName(string qname) {
			if (qname != null) {
				int colon = qname.IndexOf(':');
				return (colon < 0) ? null : qname.Substring(0,colon);
			}
			return null;
		}

		/// Recursively find the behavior with the specified name (start) and (optionally) set.
		/// The name is matched with the start of the specified behavior name, e.g. "type."
		/// The set can be set to null to allow any set.
		/// @param set the behaviorset of the behavior, if null any set
		/// @param name the (start of the) name of the behavior
		/// @return the matching Behavior(Reference) or null if not found.
		public acn.ddl.BehaviorReference FindBehavior(string set, string name) {
			// is this a direct reference to the behavior we are looking for?
			if (this.MatchesBehaviorGroup(set,name)) {
				return this;
			}
			// see if the referenced behavior refines the behavior we are looking for
			acn.ddl.BehaviorDefinition bdef = GetDefinition();
			if (bdef != null) {
				return bdef.FindBehavior(set,name);
			}
			return null;
		}

		/// Recursively test if this behavior references the specified behavior definition.
		/// @param set the behaviorset of the behavior
		/// @param name the name of the behavior
		/// @return true if the referred behavior has the specified behavior, false otherwise.
		public bool HasBehavior(string set, string name) {
			// is this a direct reference to the behavior we are looking for?
			// or see if the referenced behavior refines the behavior we are looking for
			if (this.MatchesBehavior(set,name) || this.RefinesBehavior(set,name)) {
				return true;
			}
			return false;
		}

		/// Test if this behavior references the specified behavior definition.
		/// @param set the behaviorset of the behavior
		/// @param name the name of the behavior
		/// @return true if the referred behavior matches the specified behavior, false otherwise.
		public bool MatchesBehavior(string set, string name) {
			// is this a direct reference to the behavior we are looking for?
			if (this.name == name && MatchModuleIdentifier(this.set,set)) {
				return true;
			}
			return false;
		}

		/// Test if this behavior references the specified behavior definition.
		/// @param set the behaviorset of the behavior
		/// @param name the name of the behavior
		/// @return true if the referred behavior matches the specified behavior, false otherwise.
		public bool MatchesBehaviorGroup(string set, string name) {
			// is this a direct reference to the behavior we are looking for?
			if (this.name.StartsWith(name,StringComparison.Ordinal)
				&& (string.IsNullOrEmpty(set) || MatchModuleIdentifier(this.set,set))) {
				return true;
			}
			return false;
		}

		/// Recursively test if this behavior references the specified behavior definition.
		/// @param set the behaviorset of the behavior
		/// @param name the name of the behavior
		/// @return true if the referred behavior has the specified behavior, false otherwise.
		public bool RefinesBehavior(string set, string name) {
			// see if the referenced behavior refines the behavior we are looking for
			acn.ddl.BehaviorDefinition bdef = GetDefinition();
			if (bdef != null) {
				return bdef.RefinesBehavior(set,name);
			}
			return false;
		}
		
		/// Return the qualified name of the behavior reference.
		public override string ToString() {
			return string.Concat(this.set,":",this.name);
		}		
	}

	///
	/// An ACN DDL Behavior Set module.
	///
	public partial class BehaviorSet : ConcreteModule {
	
		/// Default constructor
		public BehaviorSet() : base() {
		}

		/// Initializing constructor
		/// @param id the identifier of the node
		/// @param label the label text
		/// @param provider the URI of the provider of the module
		/// @param uuid the UUID of the module
		/// @exception XmlException if the identifier is not valid
		public BehaviorSet(string id, string label = null, string provider = null, string uuid = null) : base(id,uuid,label,provider) {
		}

		/// Create a new BehaviorDefinition and add it to the set.
		/// If the behavior is already defined in the set,
		/// @param name the name of the behavior
		/// @param label the label text of the behavior
		/// @return the (new) BehaviorDefinition
		public acn.ddl.BehaviorDefinition AddBehaviorDef(string name, string label = null) {
			acn.ddl.BehaviorDefinition result = GetBehaviorDef(name);
			if (result == null) {
				result = new acn.ddl.BehaviorDefinition(null,name,label);
				ArrayAddChildNode(ref behaviordefField, result);
			}
			return result;
		}

		/// Get the BehaviorDefinition with the specified name.
		/// @param name the name of the BehaviorDefinition to find.
		/// @return the BehaviorDefinition or null if not found
		public acn.ddl.BehaviorDefinition GetBehaviorDef(string name) {
			if (behaviordefField != null) {
				foreach (acn.ddl.BehaviorDefinition behavior in behaviordefField) {
					if (behavior.name == name) {
						return behavior;
					}
				}
			}
			return null;
		}

		/// Get the child node with the specified index.
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			int count = base.GetChildNodeCount();
			if ((index >= 0) && (index < count)) {
				return base.GetChildNode(index);
			}
			index -= count;
			count = GetChildNodeCountOf(behaviordefField);
			if ((index >= 0) && (index < count)) {
				return behaviordefField[index];
			}
			return null;
		}

		/// Get the number of child nodes
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount()
					+ GetChildNodeCountOf(behaviordefField);
		}

		protected override void UpdateChildNodes() {
			base.UpdateChildNodes();
			UpdateChildNodesIn(behaviordefField);
		}
	}

	///
	/// A ConcreteModule is a Module that has no ddl:parameter(s)
	///
	public partial class ConcreteModule : Module {
		
		/// Default constructor
		public ConcreteModule() : base() {
		}

		/// Initializing constructor
		/// @param id the identifier of the node
		/// @param uuid the UUID of the module
		/// @param label the label text
		/// @param provider the URI of the provider of the module
		/// @exception XmlException if the identifier is not valid
		public ConcreteModule(string id, string uuid = null, string label = null, string provider = null) : base(id,uuid,label,provider) {
		}
	}

	///
	/// The root node of an ACN DDL document.
	///
	/// An acn.ddl.DDLDocument represents the ddl:DDL root node, containing either:
	/// - a ddl:device
	/// - a ddl:behaviorset
	/// - a ddl:languageset
	///
	/// This (partial) class is constructed from the manually written code here,
	/// and the XSD generated code. The generated partial class has (deliberately) no
	/// super class, so that it inherits from Node, like the IdentifiedNode and 
	/// IdentifiedLeafNode.
	///
	public partial class DDLDocument : Node {

		private acn.ddl.Document _Document;
	
		private System.Xml.Serialization.XmlSerializerNamespaces _XmlNamespaces;
		
		/// Reference to the owning Document
		[System.Xml.Serialization.XmlIgnore()]
		public acn.ddl.Document Document {
			get { return _Document; }
			set {
				if (value != null && _Document != null) {
					throw new InvalidOperationException("DDL root node already attached to a Document");
				}
				_Document = value;
			}
		}
		
		[System.Xml.Serialization.XmlIgnore()]
		public Module Module {
			get { return this.Item; }
			set { this.Item = value; }
		}

		[System.Xml.Serialization.XmlIgnore()]
		public Device Device {
			get { return this.Item as acn.ddl.Device; }
			set { this.Item = value; }
		}

		[System.Xml.Serialization.XmlIgnore()]
		public BehaviorSet BehaviorSet {
			get { return this.Item as acn.ddl.BehaviorSet; }
			set { this.Item = value; }
		}

		[System.Xml.Serialization.XmlIgnore()]
		public LanguageSet LanguageSet {
			get { return this.Item as acn.ddl.LanguageSet; }
			set { this.Item = value; }
		}

		/// XML Namespace definitions for use with the XmlSerializer on writing the document.
		[System.Xml.Serialization.XmlIgnore()]
		public System.Xml.Serialization.XmlSerializerNamespaces XmlNamespaces {
			get {
				if (_XmlNamespaces == null) {
					_XmlNamespaces = new System.Xml.Serialization.XmlSerializerNamespaces();
				}
				return _XmlNamespaces;
			}
		}

		/// Default constructor.
		/// @note the XmlSerializer requires a default constructor.
		public DDLDocument() {
		}

		/// Initializing constructor.
		/// @param module the ACN DDl module contained in this document
		public DDLDocument(Module module) {
			this.version = "1.1";
			this.Module = module;
			if (module != null) {
				module.IsChanged = false;
				module.ParentNode = this;
			}
		}

		/// Get the child node with the specified index.
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			int count = base.GetChildNodeCount();
			if ((index >= 0) && (index < count)) {
				return base.GetChildNode(index);
			}
			index -= count;
			count = GetChildNodeCountOf(itemField);
			if ((index >= 0) && (index < count)) {
				return itemField;
			}
			return null;
		}

		/// Get the number of child nodes
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount()
					+ GetChildNodeCountOf(itemField);
		}

		protected override void UpdateChildNodes() {
			base.UpdateChildNodes();
			UpdateChildNodesIn(itemField);
		}
	}

	///
	/// An ACN DDL Device module.
	///
	public partial class Device : Module {
	
		private acn.ddl.Appliance _Appliance = null;

		/// Cached appliance of this device
		/// @note use GetAppliance() to enforce building of the appliance
		[System.Xml.Serialization.XmlIgnoreAttribute()]
		public acn.ddl.Appliance Appliance {
			get { return _Appliance; }
			set { _Appliance = value; }
		}
	
		/// Default constructor
		public Device() : base() {
		}

		/// Initializing constructor
		/// @param id the identifier of the node
		/// @param label the label text
		/// @param provider the URI of the provider of the module
		/// @param uuid the UUID of the module
		/// @exception XmlException if the identifier is not valid
		public Device(string id, string label = null, string provider = null, string uuid = null) : base(id,uuid,label,provider) {
		}

		/// Add the specified property as child of this property.
		/// @param prop the child property to add
		internal void AddProperty(acn.ddl.Property prop) {
			if (prop != null) {
				ArrayAddChildNode(ref itemsField, prop);
			}
		}

		/// Create a new UseProtocol and add it to the Device.
		/// If the protocol is already specified in the Device, nothing happens.
		/// @param name the name of the protocol
		public void AddUseProtocol(string name) {
			if (GetUseProtocol(name) == null) {
				acn.ddl.UseProtocol result = new acn.ddl.UseProtocol(name);
				ArrayAddChildNode(ref useprotocolField, result);
			}
		}
		
		/// Get the appliance of this device.
		/// @return the cached appliance or builds the appliance if not build yet.
		public acn.ddl.Appliance GetAppliance() {
			if (Appliance == null) {
				Appliance = new acn.ddl.Appliance(this);
			}
			return Appliance;
		}

		/// Get the child node with the specified index.
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			int count = base.GetChildNodeCount();
			if ((index >= 0) && (index < count)) {
				return base.GetChildNode(index);
			}
			index -= count;
			count = GetChildNodeCountOf(useprotocolField);
			if ((index >= 0) && (index < count)) {
				return useprotocolField[index];
			}
			index -= count;
			count = GetChildNodeCountOf(itemsField);
			if ((index >= 0) && (index < count)) {
				return itemsField[index];
			}
			return null;
		}

		/// Get the number of child nodes
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount()
					+ GetChildNodeCountOf(useprotocolField)
					+ GetChildNodeCountOf(itemsField);
		}

		/// Get the array of child nodes, null if not available.
		internal override acn.ddl.IdentifiedNode[] GetIdentifiedChildNodes() {
			return itemsField;
		}

		/// Get the property with the specified identifier, 
		/// or create and add a new Property.
		/// If the id is null, the property is created anyway.
		/// If a matching property is found, the type is verified (unless NULL is specified)
		/// @param id the identifier of the property
		/// @param type the valuetype of the property
		/// @param label the label text of the property
		/// @return the new or existing property
		public acn.ddl.Property GetOrAddProperty(string id, acn.ddl.PropertyValueType type = acn.ddl.PropertyValueType.NULL, string label = null) {
			acn.ddl.Property result = GetProperty(id);
			if (result == null) {
				if (GetIdentifiedNode(id) != null) {
					throw new InvalidOperationException(string.Format("device '{0}' already has a child node '{1}'",this.id,id));
				}
				// see if any group of this property exists
				acn.ddl.Property group = GetGroupOfProperty(id);
				if (group != null) {
					result = new acn.ddl.Property(id,type,label);
					group.AddProperty(result);
				}
				else {
					result = new acn.ddl.Property(id,type,label);
					AddProperty(result);
				}
			}
			else {
				if (type != acn.ddl.PropertyValueType.NULL) {
					if (result.valuetype != type) {
						// do not update: it is a GetOrAdd, not addorupdate
						throw new InvalidOperationException(string.Format("property '{0}' has valuetype '{1}' in stead of '{2}'",result.id,result.valuetype,type));
					}
				}
			}
			return result;
		}


		/// Get the group of the property with the specified id, null if not found.
		/// @param id the id or full id of the property to get the group of
		/// @return the group of the property with the specified identifier, null if not found
		public acn.ddl.Property GetGroupOfProperty(string id) {
			return this.GetGroupOfIdentifiedNode(id) as acn.ddl.Property;
		}

		/// Get the property with the specified id, null if not found
		public acn.ddl.Property GetProperty(string id) {
			return (this.GetIdentifiedNode(id) as acn.ddl.Property);
		}

		/// Get the child property with the specified behavior, null if not found
		/// @param qname the qualified name of the behavior
		/// @return The child property with the specified behavior, null if not found.
		public acn.ddl.Property GetPropertyWithBehavior(string qname) {
			string set = acn.ddl.BehaviorReference.GetPrefixOfQName(qname);
			string name = acn.ddl.BehaviorReference.GetNameOfQName(qname);
			return acn.ddl.Property.GetPropertyNodeWithBehavior(ref itemsField, set, name);
		}

		/// Get the child property with the specified behavior, null if not found
		/// @param behaviorset the set of the behavior definition
		/// @param behavior the behavior from the group to find.
		/// @return The child property with the specified behavor, null if not found.
		public acn.ddl.Property GetPropertyWithBehavior(string behaviorset, string behavior) {
			return acn.ddl.Property.GetPropertyNodeWithBehavior(ref itemsField, behaviorset, behavior);
		}

		/// Get the UseProtocol with the specified name.
		/// @param name the name of the UseProtocol to find.
		/// @return the UseProtocol or null if not found
		public acn.ddl.UseProtocol GetUseProtocol(string name) {
			if (useprotocolField != null) {
				foreach (acn.ddl.UseProtocol protocol in useprotocolField) {
					if (protocol.name == name) {
						return protocol;
					}
				}
			}
			return null;
		}

		protected override void UpdateChildNodes() {
			base.UpdateChildNodes();
			UpdateChildNodesIn(useprotocolField);
			UpdateChildNodesIn(itemsField);
		}
	}

	///
	/// An ACN DDL module documents list.
	///
	/// An ACN device description typically consists of a set of modules, at least one
	/// device module and a behaviorset module. The DocumentList is the container of these modules
	/// and can be used for lookup of cross-references.
	/// The RootDevice property indicates the module that contains the root device description.
	/// @see https://docs.microsoft.com/en-us/dotnet/api/system.collections.objectmodel.keyedcollection-2
	///
	public class DocumentList : nl.nlsw.Items.ItemList {
		
		private string _DefaultFileNameExtension = ".ddl.xml";
		private System.Collections.Generic.List<string> _ModuleFolders;
	
		/// The default constructor.
		public DocumentList() : base() {
		}
		
		/// The default filename extension of ACN DDL module files.
		public string DefaultFileNameExtension {
			get { return _DefaultFileNameExtension; }
			set { _DefaultFileNameExtension = value; }
		}
		
		/// The list of folders holding ACN DDL module files.
		public System.Collections.Generic.List<string> ModuleFolders {
			get {
				if (_ModuleFolders == null) {
					_ModuleFolders = new System.Collections.Generic.List<string>();
				}
				return _ModuleFolders;
			}
			set { _ModuleFolders = value; }
		}
		
		///
		/// Add the specified module to the DocumentList.
		/// The Document that is created to hold the module is returned.
		///
		/// @param module the module to add
		/// @return the (new) Document that holds the module
		///
		private Document AddModule(Module module) {
			if (module != null) {
				Document doc = new acn.ddl.Document();
				// sync the UUID of the module with the document
				if (string.IsNullOrEmpty(module.UUID)) {
					// use the newly generated UUID of the document
					module.UUID = (doc.Identifier as UrnUri).UUID.ToString();
				}
				else {
					// use the UUID of the module
					Guid uuid;
					if (System.Guid.TryParse((string)module.UUID,out uuid)) {
						doc.Identifier = nl.nlsw.Identifiers.UrnUri.NewUuidUrnUri(uuid);
					}
					else {
						throw new InvalidOperationException("Module " + module.id + " has invalid UUID " + module.UUID);
					}
				}
				// verify the module.id and add UUIDname of the module itself
				if (!string.IsNullOrEmpty(module.id)) {
					acn.ddl.Node.VerifyNodeIdentifier(module.id);
					// add a UUIDName for the module itself, if missing
					module.AddUUIDname(module.UUID, module.id);
				}
				doc.Name = module.id;
				// set the date attribute of the module
				if (string.IsNullOrEmpty(module.date)) {
					module.SetDateToNow();
				}
				// create a label with the name of the module
				if (module.label == null) {
					module.label = new Label();
					module.label.Value = doc.Name;
				}
				doc.RootNode = new DDLDocument(module);
				doc.RootNode.NotifyNodeChanged();
				Add(doc);
				return doc;
			}
			return null;
		}
		
		/// Find the module file with the specified name.
		/// This operation tries to find the the specified file in the file system.
		/// It will look in the following places:
		/// - at the specified location in case of a rooted filename
		/// - the current directory
		/// - the folders specified in the ModuleFolders list
		/// @param filename the relative or absolute file name path of the module file
		/// @return the FileInfo of the (first) found file with the specified name, null if not found
		public System.IO.FileInfo FindModuleFile(string filename) {
			System.IO.FileInfo result = new System.IO.FileInfo(filename);
			// found already, or do we have to look further?
			if (!result.Exists && !System.IO.Path.IsPathRooted(filename)) {
				// try the ModuleFolders
				foreach (string folder in ModuleFolders) {
					string path = System.IO.Path.Combine(folder,filename);
					result = new System.IO.FileInfo(path);
					if (result.Exists) {
						return result;
					}
				}
				return null;
			}
			return result;
		}

		/// Get the Document that contains the module with the specified name (or UUID).
		/// @param name the xml:id of the ACN DDL module, or the UUID of the module
		/// @return the Document that holds the module, null if not found
		public Document GetDocumentByModuleName(string name) {
			if (this.Items != null) {
				if (acn.ddl.UUIDName.IsUUID(name)) {
					// convert to uuid urn
					System.Guid guid = new System.Guid(name);
					nl.nlsw.Identifiers.UrnUri urn = nl.nlsw.Identifiers.UrnUri.NewUuidUrnUri(guid);
					// lookup the UUID Identifier (prevent exception)
					if (this.Contains(urn.ToString())) {
						return this[urn.ToString()] as acn.ddl.Document;
					}
				}
				else {
					foreach (ItemObject item in this.Items) {
						if (item.Name == name) {
							return item as Document;
						}
					}
				}
			}
			return null;
		}

		/// Get the Document that contains the module with the specified name
		/// @todo add callback to signal import of document to user, if needed
		///   use in powershell: Register-ObjectEvent `
		///    -InputObject ([Console]) `
		///    -EventName "CancelKeyPress"`
		///    -SourceIdentifier "ConsoleCancelEventHandler"`
		///    -Action { Write-Host "Press cancel key: Ctrl-C" }
		/// @param name the xml:id of the ACN DDL module
		/// @return the Document that holds the module, null if not found or loaded
		public Document GetOrLoadDocumentByModuleName(string name) {
			acn.ddl.Document result = GetDocumentByModuleName(name);
			if (result == null) {
				// @todo search ModulePath and filename extension variants
				string filename = string.Concat(name,this.DefaultFileNameExtension);
				// search for the file in the 'current folder' and in the ModuleFolders
				System.IO.FileInfo fileInfo = FindModuleFile(filename);
				if (fileInfo != null) {
					acn.ddl.Reader reader = new acn.ddl.Reader();
					reader.CurrentItemList = this;
					reader.TextReader = new System.IO.StreamReader(fileInfo.FullName,reader.DefaultEncoding);
					result = reader.ImportDocument(reader.TextReader);
					if (result != null) {
						result.FileInfo = fileInfo;
					}
				}
			}
			return result;
		}

		/// Create a new BehaviorSet module document and add it to the DocumentList.
		/// @param id the xml:id of the BehaviorSet
		/// @param label the label text (display name) of the BehaviorSet
		/// @param provider the URI of the module provider
		/// @param uuid the UUID of the module
		/// @return the (new) Document that holds the new BehaviorSet
		public Document NewBehaviorSet(string id = null, string label = null, string provider = null, string uuid = null) {
			BehaviorSet module = new BehaviorSet(id,label,provider);
			module.UUID = uuid;
			return AddModule(module);
		}

		/// Create a new Device module document and add it to the DocumentList.
		/// @param id the xml:id of the device
		/// @param label the label text (display name) of the device
		/// @param provider the URI of the module provider
		/// @param uuid the UUID of the module
		/// @return the (new) Document that holds the new Device
		public Document NewDevice(string id = null, string label = null, string provider = null, string uuid = null) {
			Device module = new Device(id,label,provider);
			module.UUID = uuid;
			return AddModule(module);
		}

		/// Create a new LanguageSet module document and add it to the DocumentList.
		/// @param id the xml:id of the LanguageSet
		/// @param label the label text (display name) of the LanguageSet
		/// @param provider the URI of the module provider
		/// @param uuid the UUID of the module
		/// @return the (new) Document that holds the new LanguageSet
		public Document NewLanguageSet(string id = null, string label = null, string provider = null, string uuid = null) {
			LanguageSet module = new LanguageSet(id,label,provider);
			module.UUID = uuid;
			return AddModule(module);
		}
	}

	///
	/// An ACN DDL document.
	///
	/// An acn.ddl.Document is a single XML document with a ddl:DDL root node, containing either:
	/// - a ddl:device
	/// - a ddl:behaviorset
	/// - a ddl:languageset
	/// 
	/// Being an nl.nlsw.Items.ItemObject, a Document integrates with the acn.ddl.DocumentList.
	///
	public class Document : nl.nlsw.Items.ItemObject {
	
		/// The root node of the document (ddl:DDL)
		private DDLDocument _RootNode;

		/// Reference to the owning DocumentList.
		public DocumentList DocumentList {
			get { return (ItemList as DocumentList); }
		}

		/// Reference to the corresponding XmlDocument
		public XmlDocument DOMDocument { get; set; }

		/// The file of the document
		public System.IO.FileSystemInfo FileInfo { get; set; }
		
		/// The root node of the document (ddl:DDL)
		public DDLDocument RootNode {
			get { return _RootNode; }
			set {
				if (_RootNode != null) {
					// detach the node from this Document
					_RootNode.Document = null;
				}
				_RootNode = value;
				if (_RootNode != null) {
					// assign the root node to this Document
					_RootNode.Document = this;
					if (_RootNode.Module != null) {
						if (!string.IsNullOrEmpty( _RootNode.Module.UUID)) {
							this.Identifier = nl.nlsw.Identifiers.UrnUri.NewUuidUrnUri(new System.Guid(_RootNode.Module.UUID));
						}
						if (!string.IsNullOrEmpty(_RootNode.Module.id)) {
							this.Name = _RootNode.Module.id;
						}
						// construct the corresponding XmlDocument
						_RootNode.UpdateNode();
					}
				}
			}
		}

		/// The ddl:device of this document (if the ACN module is a device description).
		public Device Device {
			get { return RootNode == null ? null : RootNode.Module as acn.ddl.Device; }
			set { }
		}

		/// The ddl:behaviorset of this document (if the ACN module is a behavior set).
		public BehaviorSet BehaviorSet {
			get { return RootNode == null ? null : RootNode.Module as acn.ddl.BehaviorSet; }
			set { }
		}

		/// The ddl:languageset of this document (if the ACN module is a language set).
		public LanguageSet LanguageSet {
			get { return RootNode == null ? null : RootNode.Module as acn.ddl.LanguageSet; }
			set { }
		}

		/// The ACN module of this document
		public Module Module {
			get { return RootNode == null ? null : RootNode.Module; }
			set { }
		}

		/// Default constructor.
		public Document() : base(null,null) {
		}

		/// Initializing constructor
		/// @param name the (display) name of the document
		/// @param id a unique identifier URI; by default a new UUID URI is generated 
		public Document(string name, nl.nlsw.Identifiers.Uri id = null) : base(name,id) {
		}
		
		/// Synchronize the Node and the corresponding DOMNode.
		/// - if node == null, a corresponding DOMNode is created or updated based on the Node properties.
		/// - if node != null, the properties of the Node are set based on the corresponding XmlNode.
		public virtual void UpdateNode(XmlNode node = null) {
			if (node == null) {
				// @TODO specify XmlNameTable
//				DOMDocument = new XmlDocument();
			}
		}
	}

	///
	/// Base class for complex DDL document nodes
	///
	/// This (partial) class is constructed from the manually written code here,
	/// and the XSD generated code. The generated partial class has (deliberately) no
	/// super class, so that it inherits from Node, like the DDLDocument and 
	/// IdentifiedLeafNode.
	///
	public partial class IdentifiedNode : Node {

		/// The character used for delimiting nested identifier parts
		/// @note ACN DDL uses '/' as separator for reference paths to identified nodes.
		public const char IdentifierSeparator = '.';

		/// String.Concat needs a string instead of a char.
		private static string _IdentifierSeparatorString = new System.String(IdentifierSeparator,1);

		/// The character used for delimiting node identifiers in a path 
		/// @note ACN DDL uses '/' as separator for reference paths to identified nodes.
		public const char IdentifierPathSeparator = '/';

		/// Default constructor
		public IdentifiedNode() : base() {
		}

		/// Initializing constructor
		/// @param id the identifier of the node
		/// @exception XmlException if the identifier is not valid
		public IdentifiedNode(string id) : base() {
			if (!string.IsNullOrEmpty(id)) {
				VerifyNodeIdentifier(id);
				this.id = id;
			}
		}
		
		/// Recursively, gets the full identifier of the node.
		/// The full identifier of a node is its id prepended
		/// with the '.'-separated ids of its ancestor nodes, leaving out common parts.
		///
		/// Optionally, a rootNode can be specified to get a relative identifier of the node,
		/// with the rootNode as base.
		///
		/// In an XML file each xml:id has to be unique. A common pattern to achieve this is
		/// to identify nested properties with their full identifier.
		/// This function takes this pattern into account.
		/// @param rootNode the ancestor node that is the base of a relative identifier.
		/// @return the full identifier of the node (starting at the rootNode), or null if id == null
		public string GetFullIdentifier(acn.ddl.IdentifiedNode rootNode = null) {
			if (id != null) {
				acn.ddl.IdentifiedNode parent = ParentNode as acn.ddl.IdentifiedNode;
				if ((parent != null) && (parent != rootNode)) {
					string baseId = parent.GetFullIdentifier(rootNode);
					string result = MergeOverlappingIdentifiers(baseId,id);
					if (result == null) {
						result = string.Concat(baseId,_IdentifierSeparatorString,id);
					}
					return result;
				}
			}
			return id;
		}

		/// Get the group of the node with the specified id, null if not found.
		/// The group node is the node that (may) have the specified node as parent node.
		/// @param baseNode the owner of the nodes
		/// @param nodes the nodes to check
		/// @param id the id or full id of the node to get the group of
		/// @return the group of the node with the specified identifier, null if not found
		public acn.ddl.IdentifiedNode GetGroupOfIdentifiedNode(string id) {
			if (id != null) {
				int i = id.LastIndexOf(acn.ddl.IdentifiedNode.IdentifierSeparator);
				while (i > 0) {
					acn.ddl.IdentifiedNode result = this.GetIdentifiedNode(id.Substring(0,i));
					if (result != null) {
						return result;
					}
					i = id.LastIndexOf(acn.ddl.IdentifiedNode.IdentifierSeparator,i - 1);
				}
			}
			return null;
		}
		
		/// Get the child node with the specified index, null if not found
		public acn.ddl.IdentifiedNode GetIdentifiedChildNode(int index) {
			acn.ddl.IdentifiedNode[] nodes = GetIdentifiedChildNodes();
			if ((nodes != null) && (index >= 0) && (index < nodes.Length)) {
				return nodes[index];
			}
			return null;
		}

		/// Get the number of child nodes
		public int GetIdentifiedChildNodeCount() {
			acn.ddl.IdentifiedNode[] nodes = GetIdentifiedChildNodes();
			return (nodes != null) ? nodes.Length : 0;
		}

		/// Get the array of child nodes, null if not available.
		internal virtual acn.ddl.IdentifiedNode[] GetIdentifiedChildNodes() {
			return null;
		}
		
		/// Get the node with the specified id, null if not found.
		/// The identifier must be relative to the current node.
		/// Note that the id of a node can partly overlap the ids of its
		/// ancestors. This operation takes that into account.
		/// @param id the identifier of the node to get
		/// @return the node with the specified id, null if not found.
		public acn.ddl.IdentifiedNode GetIdentifiedNode(string id) {
			acn.ddl.IdentifiedNode[] nodes = GetIdentifiedChildNodes();
			if (id != null && nodes != null) {
				string baseId = this.GetFullIdentifier();
				string target = MergeOverlappingIdentifiers(baseId,id);
				if (target == null) {
					target = string.Concat(baseId,_IdentifierSeparatorString,id);
				}
				foreach (acn.ddl.IdentifiedNode node in nodes) {
					// if there is a partial match and the node has child nodes (Property only), then search further
					string nodeId = node.GetFullIdentifier();
					// 'substract' the base part, and test if the id starts with the significant part of the nodeId
					int n = baseId.Length + 1;	// start of significant part of nodeId (skip base part + IndentifierSeparator)
					int m = nodeId.Length - n;
					if (target.StartsWith(nodeId, StringComparison.Ordinal)) {
						if (target.Length == nodeId.Length) {
							return node;
						}
						if (target[nodeId.Length] == IdentifierSeparator) {
							return node.GetIdentifiedNode(target.Substring(nodeId.Length + 1));
						}
					}
				}
			}
			return null;
		}

		/// Try to merge a base identifier with a possibly partly overlapping identifier, and return the resulting identifier.
		/// @param baseId the base identifier
		/// @param id the (perhaps partly overlapping) identifier
		/// @return the merged identifier, null if there is no overlap.
		public static string MergeOverlappingIdentifiers(string baseId, string id) {
			if (baseId == null) {
				throw new ArgumentNullException("baseId");
			}
			if (id == null) {
				throw new ArgumentNullException("id");
			}
			// determine endpoint of possibly overlapping part
			int point = id.LastIndexOf(IdentifierSeparator);
			while (point > 0) {
				if (point <= baseId.Length) {
					if (string.CompareOrdinal(baseId,baseId.Length - point, id, 0, point) == 0) {
						return string.Concat(baseId,id.Substring(point));
					}
				}
				point = id.LastIndexOf(IdentifierSeparator,point - 1);
			}
			return null;
		}
	}

	///
	/// Base class for simple DDL document nodes (leaf nodes).
	///
	/// This (partial) class is constructed from the manually written code here,
	/// and the XSD generated code. The generated partial class has (deliberately) no
	/// super class, so that it inherits from Node, like the IdentifiedNode and 
	/// DDLDocument.
	///
	public partial class IdentifiedLeafNode : Node {

		/// Default constructor
		public IdentifiedLeafNode() : base() {
		}

		/// Initializing constructor
		/// @param id the identifier of the node
		/// @param value the text value of the node
		/// @exception XmlException if the identifier is not valid
		public IdentifiedLeafNode(string id, string value = null) : base() {
			if (!string.IsNullOrEmpty(id)) {
				VerifyNodeIdentifier(id);
				this.id = id;
			}
			this.Value = value;
		}
		
		/// Test if the node is empty, i.e. has no value or the empty string.
		public virtual bool IsEmpty() {
			return string.IsNullOrEmpty(this.Value);
		}
	}

	///
	/// A statically included device description.
	///
    public partial class IncludeDevice : LabeledArrayElement {

		/// Default constructor
		public IncludeDevice() : base() {
		}

        /// Initializing constructor
		/// A UUID must be written in lower case.
		/// @param id the identifier of the node
		/// @param uuid the UUID (or UUIDname) of the device included
		/// @param label the label text
		/// @exception XmlException if the identifier or the uuid is not valid
		public IncludeDevice(string id, string uuid, string label = null) : base(id, label) {
			System.Xml.XmlConvert.VerifyNMTOKEN(uuid);
            this.UUID = UUIDName.NormalizeUUID(uuid);
		}

		/// Get the child node with the specified index.
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			int count = base.GetChildNodeCount();
			if ((index >= 0) && (index < count)) {
				return base.GetChildNode(index);
			}
			index -= count;
			count = GetChildNodeCountOf(protocolField);
			if ((index >= 0) && (index < count)) {
				return protocolField[index];
			}
			index -= count;
			count = GetChildNodeCountOf(setparamField);
			if ((index >= 0) && (index < count)) {
				return setparamField[index];
			}
			return null;
		}

		/// Get the number of child nodes
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount()
					+ GetChildNodeCountOf(protocolField)
					+ GetChildNodeCountOf(setparamField);
		}

		/// Get the device module definition of the included device.
		public acn.ddl.Device GetDefinition() {
			acn.ddl.Module module = GetReferencedModule(this.UUID);
			if (!(module is acn.ddl.Device)) {
				throw new InvalidOperationException(string.Format("invalid device reference '{0}': not an existing device module",this.UUID));
			}
			return module as acn.ddl.Device;
		}

		/// Create a new Protocol and add it to the IncludeDevice.
		/// If the protocol is already specified in the property, that property is returned.
		///
		/// If the Device of the IncludeDevice not already has a UseProtocol for this protocol,
		///   it is added to that device as well.
		///
		/// @note Zero or more protocol entries are required on an IncludeDevice, depending on the protocol.
		/// 
		/// @param name the name of the protocol
		/// @return the (new) protocol with the specified name
		public acn.ddl.Protocol GetOrAddProtocol(string name) {
			acn.ddl.Protocol result = GetProtocol(name);
			if (result == null) {
				result = new acn.ddl.Protocol(name);
				ArrayAddChildNode(ref protocolField, result);
				// make sure the Device uses this protocol
				acn.ddl.Device device = GetDevice();
				if (device != null && (device.GetUseProtocol(name) == null)) {
					device.AddUseProtocol(name);
				}
			}
			return result;
		}

		/// Get the Protocol with the specified name.
		/// @param name the name of the Protocol to find.
		/// @return the Protocol or null if not found
		public acn.ddl.Protocol GetProtocol(string name) {
			if (protocolField != null) {
				foreach (acn.ddl.Protocol prot in protocolField) {
					if (prot.name == name) {
						return prot;
					}
				}
			}
			return null;
		}

		protected override void UpdateChildNodes() {
			base.UpdateChildNodes();
			UpdateChildNodesIn(protocolField);
			UpdateChildNodesIn(setparamField);
		}
	}

	/// A text that indicates the function of its parent element.
	/// Labels may be assigned to many elements in DDL. A label is intended for human consumption
	///	and should indicate the function of its parent element. Labels may take one of two forms.
	/// - An immediate label contains the label text as its content.
	/// - A referenced label contains both a string key and a languageset attribute that reference a string
	///   (or set of strings in different languages) that contains the text of the label.
	/// A label shall have either immediate text content or both key and set attributes. It shall not have
	/// both content and attributes.
    public partial class Label : IdentifiedLeafNode {

		/// Default constructor
		public Label() : base() {
		}

		/// Initializing constructor
		/// @param id the identifier of the node
		/// @param label the label text
		/// @exception XmlException if the identifier is not valid
		public Label(string id, string label = null) : base(id, label) {
		}
		
		public bool IsImmediateLabel() {
			return !string.IsNullOrEmpty(this.Value);
		}
		
		public bool IsReferencedLabel() {
			return !string.IsNullOrEmpty(this.key) && !string.IsNullOrEmpty(this.set);
		}
		
		/// Get the referenced languageset module definition
		public acn.ddl.LanguageSet GetDefinition() {
			acn.ddl.Module module = GetReferencedModule(this.set);
			if (!(module is acn.ddl.LanguageSet)) {
				throw new InvalidOperationException(string.Format("invalid language set reference '{0}': not an existing module",this.set));
			}
			return module as acn.ddl.LanguageSet;
		}

		/// Get the text string of the label in the specified language.
		/// If the label has both a local text and a language reference:
		/// - use local string if no language is specified
		/// - lookup language string, if not found, use local string
		///
		/// @param lang the language specifier; if null or empty: use first language of the set
		/// @return the text string of the label
		public string GetText(string lang = null) {
			if (IsReferencedLabel()) {
				acn.ddl.LanguageSet langset = GetDefinition();
				return langset.GetStringText(this.key,lang);
			}
			return base.Value;
		}
		
		public override bool IsEmpty() {
			return base.IsEmpty() && string.IsNullOrEmpty(this.key);
		}

		/// Set parent's labelField label text as immediate text, or as language dependent string reference.
		/// This operation supports three ways of setting the label text.
		/// 1. value only - sets the text in the label itself ('immediate label'), when empty the label is removed
		/// 2. no value, languageset and key - sets a reference to a language dependent label text ('referenced label')
		/// 3. value, languageset, key and optionally lang - sets a reference to a language dependent label text and adds or verifies the value
		/// @param parent the parent node of the label
		/// @param labelField the label field of the parent
		/// @param label the label text
		/// @param languageset the language set identifier
		/// @param key the key of the label text string in the languageset
		/// @param lang language code
		public static void SetLabelText(acn.ddl.Node parent, ref acn.ddl.Label labelField, string value, string languageset = null, string key = null, string lang = null) {
			if ((labelField == null) && (!string.IsNullOrEmpty(value) || !string.IsNullOrEmpty(key))) {
				labelField = new acn.ddl.Label();
				labelField.ParentNode = parent;
			}
			if (labelField != null) {
				bool changed = labelField.SetText(value,languageset,key,lang);
				if (labelField.IsEmpty()) {
					labelField = null;
				}
				if (changed) {
					parent.NotifyNodeChanged();
				}
			}
		}

		/// Set or update the label text as immediate text, or as language dependent string reference.
		/// This operation supports three ways of setting the label text.
		/// 1. value only - sets the text in the label itself ('immediate label'), when empty the label is removed
		/// 2. no value, languageset and key - sets a reference to a language dependent label text ('referenced label')
		/// 3. value, languageset, key and optionally lang - sets a reference to a language dependent label text and adds or verifies the value
		/// @param label the label text
		/// @param languageset the language set identifier
		/// @param key the key of the label text string in the languageset
		/// @param lang language code
		/// @return true if the label was changed, false otherwise
		/// @exception ArgumentNullException when no languageset specified with a key
		/// @exception InvalidOperationException verification error: referenced label text != specified value
		public bool SetText(string value, string languageset = null, string key = null, string lang = null) {
			bool changed = false;
			if (!string.IsNullOrEmpty(key)) {
				if (string.IsNullOrEmpty(languageset)) {
					throw new ArgumentNullException("languageset");
				}
				// make the label 'referenced'
				if ((languageset != this.set) || (key != this.key)) {
					this.set = languageset;
					this.key = key;
					changed = true;
				}
				if (this.Value != null) {
					this.Value = null;
					changed = true;
				}
				// set / verify the (referenced) value
				if (!string.IsNullOrEmpty(value)) {
					string oldvalue = GetText(lang);
					// value to check or set
					if (oldvalue == null) {
						// invalid reference
						// @todo set the string
						throw new InvalidOperationException(string.Format("label {0} reference '{1}:{2}({3})' not found",this.id,this.set,this.key,lang));
					}
					else if (string.Compare(oldvalue,value,StringComparison.InvariantCulture) != 0) {
						// verification error: referenced label text != specified value
						throw new InvalidOperationException(string.Format("label {0} reference '{1}:{2}({3})' = '{4}' is not equal to '{5}'",this.id,this.set,this.key,lang,oldvalue,value));
					}
				}
			}
			else {
				// make the label immediate
				if ((this.set != null) || (this.key != null)) {
					this.set = null;
					this.key = null;
					changed = true;
				}
				// set the value
				if (string.Compare(this.Value,value,StringComparison.InvariantCulture) != 0) {
					this.Value = value;
					changed = true;
				}
			}
			return changed;
		}
	}

    public abstract partial class LabeledElement : IdentifiedNode {
       
		/// Default constructor
		public LabeledElement() : base() {
		}

		/// Initializing constructor
		/// @param id the identifier of the node
		/// @param label the label text
		/// @exception XmlException if the identifier is not valid
		public LabeledElement(string id, string label) : base(id) {
			if (!string.IsNullOrEmpty(label)) {
				this.SetLabelText(label);
			}
		}

		/// Get the child node with the specified index.
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			int count = base.GetChildNodeCount();
			if ((index >= 0) && (index < count)) {
				return base.GetChildNode(index);
			}
			index -= count;
			count = GetChildNodeCountOf(labelField);
			if ((index >= 0) && (index < count)) {
				return labelField;
			}
			return null;
		}

		/// Get the number of child nodes
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount()
					+ GetChildNodeCountOf(labelField);
		}

		/// Get the label text in the specified language.
		/// @param language the language identifier, if null or empty: use default
		/// @return the label text of the element, null if not found
		public string GetLabelText(string language = null) {
			return (labelField != null) ? labelField.GetText(language) : null;
		}

		/// Set the label text as immediate text, or as language dependent string reference.
		/// This operation supports three ways of setting the label text.
		/// 1. value only - sets the text in the label itself ('immediate label'), when empty the label is removed
		/// 2. no value, languageset and key - sets a reference to a language dependent label text ('referenced label')
		/// 3. value, languageset, key and optionally lang - sets a reference to a language dependent label text and adds or verifies the value
		/// @param label the label text
		/// @param languageset the language set identifier
		/// @param key the key of the label text string in the languageset
		/// @param lang language code
		public void SetLabelText(string value, string languageset = null, string key = null, string lang = null) {
			acn.ddl.Label.SetLabelText(this, ref this.labelField, value,languageset,key,lang);
		}

		protected override void UpdateChildNodes() {
			base.UpdateChildNodes();
			UpdateChildNodesIn(labelField);
		}
    }

	/// A language contains a set of string definitions in a particular language that is
	/// identified by its lang attribute.
	/// It may optionally specify an alternative language within the same languageset that
	/// should be searched if no string with a specified key is found in this language.
	///
	/// The altlang attribute points to another language in the same languageset by matching this
	/// language's altlang attribute with the lang attribute on another language. It is an error
	/// if there is no matching language element in the same languageset.
	///
	/// If no altlang attribute is present then this language must contain a string element for
	/// every key present in the languageset.
	///
	/// The use of altlang as a pointer can create chains of languages. It is an error if a language
	/// points to itself, whether directly or indirectly.
	///
	/// @see http://ietf.org/rfc/rfc3066.txt
	/// 
    public partial class Language : LabeledElement {
		
		/// Default constructor
		public Language() : base() {
		}

		/// Initializing constructor
		/// @param lang the IETF RFC3066 tag for the identification of languages (unique within the LanguageSet
		/// @param altlang the lang attribute of another Language in the LanguageSet to use as alternative
		/// @param label the optional label of the language
		public Language(string lang, string altlang = null, string label = null) : base(null,label) {
			this.lang = lang;
			this.altlang = altlang;
		}

		/// Add the string with the specified key to the language
		/// @param key the NCName identifier of the string
		/// @exception ArgumentException if the key is already present
		public void AddString(string key, string value) {
			if (GetString(key) != null) {
				throw new ArgumentException(string.Format("string {0} already specified for language {1}",key,this.lang),"key");
			}
			acn.ddl.String result = new acn.ddl.String(key,value);
			ArrayAdd(ref stringField, result);
		}

		/// Get the child node with the specified index.
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			int count = base.GetChildNodeCount();
			if ((index >= 0) && (index < count)) {
				return base.GetChildNode(index);
			}
			index -= count;
			count = GetChildNodeCountOf(stringField);
			if ((index >= 0) && (index < count)) {
				return stringField[index];
			}
			return null;
		}

		/// Get the number of child nodes
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount()
					+ GetChildNodeCountOf(stringField);
		}

		/// Get the string with the specified key.
		/// @param key the key of the string to find.
		/// @return the string or null if not found
		public acn.ddl.String GetString(string key) {
			if (stringField != null) {
				foreach (acn.ddl.String s in stringField) {
					if (s.key == key) {
						return s;
					}
				}
			}
			return null;
		}

		protected override void UpdateChildNodes() {
			base.UpdateChildNodes();
			UpdateChildNodesIn(stringField);
		}
	}

	///
	/// An ACN DDL Language Set module.
	///
	///
	public partial class LanguageSet : ConcreteModule {
	
		/// Default constructor
		public LanguageSet() : base() {
		}

		/// Initializing constructor
		/// @param id the identifier of the node
		/// @param label the label text
		/// @param provider the URI of the provider of the module
		/// @param uuid the UUID of the module
		/// @exception XmlException if the identifier is not valid
		public LanguageSet(string id, string label = null, string provider = null, string uuid = null) : base(id,uuid,label,provider) {
		}

		/// Create a Language with the specified tag and add it to the set.
		/// @param lang the IETF RFC3066 tag for the identification of languages (unique within the LanguageSet)
		/// @param altlang the lang attribute of another Language in the LanguageSet to use as alternative
		/// @param label the optional label of the language
		/// @exception System.ArgumentException if the language is already present in the set
		/// @exception System.ArgumentException if the alternative language is not present in the set
		public acn.ddl.Language AddLanguage(string lang, string altlang = null, string label = null) {
			if (GetLanguage(lang) != null) {
				throw new ArgumentException(string.Format("Language {0} already present in languageset {1}",lang,this.id),"lang");
			}
			if (GetLanguage(altlang) == null) {
				throw new ArgumentException(string.Format("Alternative language {0} not present in languageset {1}",altlang,this.id),"altlang");
			}
			acn.ddl.Language result = new Language(lang,altlang,label);
			ArrayAdd(ref languageField, result);
			return result;			
		}

		/// Get the child node with the specified index.
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			int count = base.GetChildNodeCount();
			if ((index >= 0) && (index < count)) {
				return base.GetChildNode(index);
			}
			index -= count;
			count = GetChildNodeCountOf(languageField);
			if ((index >= 0) && (index < count)) {
				return languageField[index];
			}
			return null;
		}

		/// Get the number of child nodes
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount()
					+ GetChildNodeCountOf(languageField);
		}

		/// Get the language with the specified language tag.
		/// If the language tag is null-or-empty, the first language in the set is returned.
		/// @param lang the language tag
		/// @return the language, or null if not found
		public acn.ddl.Language GetLanguage(string lang) {
			if ((languageField != null) && (languageField.Length > 0)) {
				if (string.IsNullOrEmpty(lang)) {
					return languageField[0];
				}
				foreach (Language lan in languageField) {
					if (lan.lang == lang) {
						return lan;
					}
				}
			}
			return null;
		}

		/// Get the string with the specified key in the specified language.
		/// If the string is not found in the specified language and an alternative
		///   language is specified, that language is used (recursively).
		/// @param key the key of the string to find.
		/// @param lang the language to return the string for (by default the first language in the set)
		/// @return the string or null if not found
		public acn.ddl.String GetString(string key, string lang = null) {
			acn.ddl.Language lan = GetLanguage(lang);
			while (lan != null) {
				acn.ddl.String result = lan.GetString(key);
				if (result != null) {
					return result;
				}
				lan = GetLanguage(lan.altlang);
			}
			return null;
		}

		/// Get the string text with the specified key in the specified language.
		/// If the string is not found in the specified language and an alternative
		///   language is specified, that language is used (recursively).
		/// @param key the key of the string to find.
		/// @param lang the language to return the string for (by default the first language in the set)
		/// @return the string or null if not found
		public string GetStringText(string key, string lang = null) {
			acn.ddl.String s = GetString(key,lang);
			if (s != null) {
				return s.Value;
			}
			return null;
		}

		protected override void UpdateChildNodes() {
			base.UpdateChildNodes();
			UpdateChildNodesIn(languageField);
		}
	}

	///
	/// An ACN DDL module is either:
	/// - a ddl:device
	/// - a ddl:behaviorset
	/// - a ddl:languageset
	///
	/// @note A Module has a label but is not derived from LabeledElement,
	///  since in the XML schema it has elements that precede the label element.
	///  Therefore the GetLabelText and SetLabelText members are duplicated here.
	public partial class Module : IdentifiedNode {

		private bool _IsChanged;
		/// cached associated languageset
		private acn.ddl.LanguageSet _LanguageSet = null;

		/// Track modifications on the module content.
		/// On the first change, the date of the module is updated.
		/// On any change, cached data is cleared.
		[System.Xml.Serialization.XmlIgnore()]
		public bool IsChanged {
			get { return _IsChanged; }
			set {
				if (_IsChanged != value) {
					_LanguageSet = null;
					_IsChanged = value;
					if (_IsChanged) {
						this.SetDateToNow();
					}
				}
			}
		}
		
		
		/// Default constructor
		public Module() : base() {
		}

		/// Initializing constructor
		/// @param id the identifier of the node
		/// @param uuid the UUID of the module
		/// @param label the label text
		/// @param provider the URI of the provider of the module
		/// @exception XmlException if the identifier is not valid
		public Module(string id, string uuid = null, string label = null, string provider = null) : base(id) {
			this.UUID = acn.ddl.UUIDName.NormalizeUUID(uuid);
			if (!string.IsNullOrEmpty(label)) {
				this.SetLabelText(label);
			}
			this.provider = provider;
		}

		/// Add a UUIDname with the specified name and UUID.
		/// If the name and/or the UUID is already registered as UUIDname,
		/// nothing happens, otherwise a new UUIDname is added to this module.
		/// @param uuid the UUID of the UUIDname to add.
		/// @param name the name of the UUIDname to add.
		public void AddUUIDname(string uuid, string name) {
			UUIDName result = GetUUIDname(uuid);
			if (result == null) {
				result = GetUUIDname(name);
			}
			if (result == null) {
				result = new UUIDName(uuid, name);
				ArrayAddChildNode(ref uUIDnameField, result);
			}
		}

		/// Get the child node with the specified index.
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			int count = base.GetChildNodeCount();
			if ((index >= 0) && (index < count)) {
				return base.GetChildNode(index);
			}
			index -= count;
			count = GetChildNodeCountOf(uUIDnameField);
			if ((index >= 0) && (index < count)) {
				return uUIDnameField[index];
			}
			index -= count;
			count = GetChildNodeCountOf(parameterField);
			if ((index >= 0) && (index < count)) {
				return parameterField[index];
			}
			index -= count;
			count = GetChildNodeCountOf(labelField);
			if ((index >= 0) && (index < count)) {
				return labelField;
			}
			index -= count;
			count = GetChildNodeCountOf(alternateforField);
			if ((index >= 0) && (index < count)) {
				return alternateforField[index];
			}
			index -= count;
			count = GetChildNodeCountOf(extendsField);
			if ((index >= 0) && (index < count)) {
				return extendsField[index];
			}
			return null;
		}

		/// Get the number of child nodes
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount()
					+ GetChildNodeCountOf(uUIDnameField)
					+ GetChildNodeCountOf(parameterField)
					+ GetChildNodeCountOf(labelField)
					+ GetChildNodeCountOf(alternateforField)
					+ GetChildNodeCountOf(extendsField);
		}

		/// Get the label text in the specified language.
		/// @param language the language identifier, if null or empty: use default
		/// @return the label text of the element, null if not found
		public string GetLabelText(string language = null) {
			return (labelField != null) ? labelField.GetText(language) : null;
		}
		
		/// Get the languageset that is associated with this module.
		/// The association is based on a corresponding base part of the module id.
		public acn.ddl.LanguageSet GetOrLoadLanguageSet() {
			if (_LanguageSet == null) {
				System.Collections.Generic.List<string> idparts = new System.Collections.Generic.List<string>(this.id.Split('.'));
				idparts.Add("lset");
				while (idparts.Count > 1) {
					string lsetID = string.Join(".",idparts);
					_LanguageSet = GetOrLoadModuleByUUIDname(lsetID) as acn.ddl.LanguageSet;
					if (_LanguageSet != null) {
						break;
					}
					idparts.RemoveAt(idparts.Count - 2);
				}
			}
			return _LanguageSet;
		}

		/// Get or load the module identified with the specified name or UUID.
		/// 
		/// @param id the name or UUID of the module to get.
		/// @return the matching module or null if not found.
		public acn.ddl.Module GetOrLoadModuleByUUIDname(string id) {
			// lookup the module in the DocumentList
			acn.ddl.UUIDName uuidname = GetUUIDname(id);
			if (uuidname != null) {
				return uuidname.GetReferencedModule();
			}
			return null;
		}

		/// Get the UUIDname with the specified name or UUID.
		/// @param id the name or UUID of the UUIDname to get.
		/// @return the matching UUIDname or null if not found.
		public acn.ddl.UUIDName GetUUIDname(string id) {
			if (uUIDnameField != null) {
				foreach (acn.ddl.UUIDName un in uUIDnameField) {
					if (un.Matches(id)) {
						return un;
					}
				}
			}
			return null;
		}

		/// Set the date of the module to the current date
		public void SetDateToNow() {
			this.date = DateTime.Now.ToString("yyyy-MM-dd");
		}

		/// Set the label text as immediate text, or as language dependent string reference.
		/// This operation supports three ways of setting the label text.
		/// 1. value only - sets the text in the label itself ('immediate label'), when empty the label is removed
		/// 2. no value, languageset and key - sets a reference to a language dependent label text ('referenced label')
		/// 3. value, languageset, key and optionally lang - sets a reference to a language dependent label text and adds or verifies the value
		/// @param label the label text
		/// @param languageset the language set identifier
		/// @param key the key of the label text string in the languageset
		/// @param lang language code
		public void SetLabelText(string value, string languageset = null, string key = null, string lang = null) {
			acn.ddl.Label.SetLabelText(this, ref this.labelField, value,languageset,key,lang);
		}

		protected override void UpdateChildNodes() {
			base.UpdateChildNodes();
			UpdateChildNodesIn(uUIDnameField);
			UpdateChildNodesIn(parameterField);
			UpdateChildNodesIn(labelField);
			UpdateChildNodesIn(alternateforField);
			UpdateChildNodesIn(extendsField);
		}
	}

	/// Base class of Property and IncludeDev classes.
	/// Both can have an array specifier.
    public partial class LabeledArrayElement : LabeledElement {
		
		/// Default constructor
		public LabeledArrayElement() {
		}

        /// Initializing constructor
		/// @param id the identifier of the node
		/// @param label the label text
		/// @exception XmlException if the identifier is not valid
		public LabeledArrayElement(string id, string label = null) : base(id, label) {
		}

		///
		/// The 'array' attribute of the property in integer format.
		/// @note Setting ArraySize to 0 or 1 will clear the 'array' attribute.
		/// @see use HasArray for testing/setting array/non-array mode of the property (
		[System.Xml.Serialization.XmlIgnoreAttribute()]
		public uint ArraySize {
			get { return string.IsNullOrEmpty(this.array) ? 1 : Convert.ToUInt32(this.array); }
			set {
				if (value <= 1) {
					this.array = null;
				}
				else {
					this.array = value.ToString();
				}
			}
		}

		/// Test (or set) the 'array' attribute of the property.
		/// @note In ACN DDL is the default value of the 'array' attribute: 1.
		///   If we want to be able to distinguish between:
		///     -# int property;
		///     -# int property[1];
		///   then we could use the absense (1) or presence (2) of the 'array' attribute as indicator.
		///   This property provides an interface for this, but note that this implies a change
		///   of the ACN DDL semantics.
		[System.Xml.Serialization.XmlIgnoreAttribute()]
		public bool HasArray {
			get { return !string.IsNullOrEmpty(this.array); }
			set {
				if (value) {
					// make sure the array property is set
					if (string.IsNullOrEmpty(this.array)) {
						this.array = "1";
					}
				}
				else {
					this.array = null;
				}
			}
		}
	}

    public partial class Parameter : LabeledElement {
		
		/// Default constructor
		public Parameter() {
		}

        /// Initializing constructor
		/// @param id the identifier of the node
		/// @param label the label text
		/// @exception XmlException if the identifier is not valid
		public Parameter(string id, string label = null) : base(id, label) {
		}

		/// Get the child node with the specified index.
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			int count = base.GetChildNodeCount();
			if ((index >= 0) && (index < count)) {
				return base.GetChildNode(index);
			}
			index -= count;
			count = GetChildNodeCountOf(itemsField);
			if ((index >= 0) && (index < count)) {
				return itemsField[index];
			}
			return null;
		}

		/// Get the number of child nodes
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount()
					+ GetChildNodeCountOf(itemsField);
		}

		protected override void UpdateChildNodes() {
			base.UpdateChildNodes();
			UpdateChildNodesIn(itemsField);
		}
	}

	/// <summary>
	/// A NodeFilter that only shows Property nodes with valuetype network.
	/// </summary>
	public class NetworkPropertyFilter : acn.ddl.INodeFilter
	{
		public NetworkPropertyFilter() {
		}

		public NodeFilterResult acceptNode(acn.ddl.Node node) {
			acn.ddl.Property prop = node as acn.ddl.Property;
			if (prop != null) {
				switch (prop.valuetype) {
					case acn.ddl.PropertyValueType.network:
						return NodeFilterResult.FILTER_ACCEPT;
					case acn.ddl.PropertyValueType.NULL:
					case acn.ddl.PropertyValueType.implied:
						return NodeFilterResult.FILTER_SKIP;
				}
			}
			return NodeFilterResult.FILTER_REJECT;
		}
	}

	///
	/// The Property class represents an ACN DDL property.
	///
	/// A property can have the following acn.ddl.PropertyValueType types:
	///
	/// - acn.ddl.PropertyValueType.NULL
	///   The Property has no value.
	///   The childnodes are label?, behavior+, protocol*, (property|includedev|propertypointer)*
	///   @symbol U+2400 ␀ NULL
	///   @symbol U+26B2 ⚲ NEUTER
	///
	///	- acn.ddl.PropertyValueType.immediate
	///   The Property value is in the description.
	///   The childnodes are label?, behavior+, value+, protocol*, (property|includedev|propertypointer)*
	///   @symbol U+1F3AF DIRECT HIT
	///
	/// - acn.ddl.PropertyValueType.implied
	///   The Property value is implied (not available on the network, nor in the description).
	///   The childnodes are label?, behavior+, protocol*, (property|includedev|propertypointer)*
	///   @symbol U+1F52E CRYSTAL BAL
	///
	/// - acn.ddl.PropertyValueType.network
	///   The Property value is implied (calculated internally).
	///   The childnodes are label?, behavior+, protocol*, (property|includedev|propertypointer)*
	///   @symbol U+1F5A7 THREE NETWORKED COMPUTERS
	///
	/// @note In ACN-DDL-1.1.dtd the child order is specified as ( ..., value*, protocol*, ..)
	///       while in the spec. text the order is (..., protocol*, value*, ...)
	///       This implementationi follows the specification text.
	///
	public partial class Property : LabeledArrayElement {
	
		public static bool Nested = false;
		private LabeledArrayElement _Definition = null;
		
		public const int InvalidArrayIndex = -1;

		/// The array index of the property.
		/// This property is used in an appliance property that HasArray, when iterating
		/// through the array.
		[System.Xml.Serialization.XmlIgnoreAttribute()]
		public int ArrayIndex { get; set; }

		/// The defining declaration of the property.
		/// By default, the defining declaration of a property is the property itself.
		/// In case of an appliance property, the defining declaration is the property (or includedev) i
		[System.Xml.Serialization.XmlIgnoreAttribute()]
		public LabeledArrayElement Definition {
			get { return _Definition; }
			set { _Definition = value; }
		}
	
        /// Initializing constructor
		/// @param id the identifier of the node
		/// @param type the valuetype of the property
		/// @param label the label text
		/// @exception XmlException if the identifier is not valid
		public Property(string id, acn.ddl.PropertyValueType type, string label = null) : base(id, label) {
            this.sharedefineField = PropertyShareDefine.@false;
			this.valuetype = type;
			this.ArrayIndex = InvalidArrayIndex;
		}

		/// Conditionally, add the specified Behavior to the property.
		/// If the behavior is already specified, but should be absent, an exception is raised.
		/// @param qname the qualified name of the behavior
		/// @param present if true the behavior must be present, if false it must be absent
		/// @exception InvalidOperationException in case the behavior is wrongly present
		public void AddBehavior(string qname, bool present = true) {
			string set = acn.ddl.BehaviorReference.GetPrefixOfQName(qname);
			string name = acn.ddl.BehaviorReference.GetNameOfQName(qname);
			AddBehavior(set,name,present);
		}

		/// Conditionally, add the specified Behavior to the property.
		/// If the behavior is already specified, but should be absent, an exception is raised.
		/// @param set the behaviorset of the behavior
		/// @param name the name of the behavior
		/// @param present if true the behavior must be present, if false it must be absent
		/// @exception InvalidOperationException in case the behavior is wrongly present
		public void AddBehavior(string set, string name, bool present = true) {
			if (this.HasBehavior(set,name) != present) {
				if (present) {
					acn.ddl.Behavior result = new acn.ddl.Behavior(set,name);
					// make sure the set is registered in the module's UUIDName
					VerifyModuleIdentifier(set);
					ArrayAddChildNode(ref behaviorField, result);
				}
				else {
					throw new InvalidOperationException(string.Format("property {0} has behavior '{1}:{2}' while it should not",this.id,set,name));
				}
			}
		}

		/// Conditionally add the behavior of a behavior group from the specified behaviorset to the property.
		/// If a behavior of the group is found, and is not equal to the specified one, an exception is raised.
		/// @note Some behaviors, like e.g. data type behaviors, form groups of which normally only one member should be specified
		///   on a property. These groups have a common prefix, like "type.".
		/// @param behaviorset the set of the behavior definition
		/// @param behavior the behavior of the group to set, null or empty if the behavior group must not be set.
		/// @param behaviorgroup the behavior group identifier; by convention it is the first (common) part of the behavior name
		/// @exception InvalidOperationException in case the present behavior of the group does not match the specified one.
		public void AddBehavior(string behaviorset, string behavior, string behaviorgroup) {
			// look for any behavior of this behavior group
			acn.ddl.BehaviorReference b = this.FindBehavior(behaviorset,behaviorgroup);
			if (b == null) {
				if (!string.IsNullOrEmpty(behavior)) {
					// add the behavior to the property
					this.AddBehavior(behaviorset,behavior);
				}
			}
			else {
				// if found the name should match the specified behavior
				if (string.CompareOrdinal(b.name, behavior) != 0) {
					throw new InvalidOperationException(string.Format("property {0} has behavior '{1}:{2}', while it should have '{3}:{4}'",this.id,b.set,b.name,behaviorset,behavior));
				}
			}
		}

		/// Add or update the specified immediate sub property of the property.
		/// This operation is used for specifying attributes of a property.
		/// Verification takes always place on the valuetype and behavior of the existing subproperty,
		/// and the ValueDataType of the value. If the verify flag is set also on the value.
		/// @param behaviorset the set of the behavior definition of the subproperty
		/// @param behavior the behavior of the subproperty
		/// @param name the name of the subproperty
		/// @param type the acn.ddl.ValueDataType of the value of the subproperty
		/// @param value the value of the subproperty
		/// @param index the index of the element of the array property, -1 for non-array property
		/// @param verify if true the value is verified rather than updated on an existing subproperty
		/// @return the added or updated subproperty, null if not found/added
		/// @exception InvalidOperationException if the verification fails
		public acn.ddl.Property AddOrUpdateSubProperty(string behaviorset, string behavior, string name, acn.ddl.ValueDataType type, string value, int index = -1, bool verify = false) {
			acn.ddl.Property pd = null;
			if (!string.IsNullOrEmpty(value)) {
				// the sub-property's id is by default the name appended to the parent's id
				string propId = string.Concat(this.id,".",name);
				// check if the subproperty with the default name already exists
				// this will raise exception below, since it has not the required behavior
				pd = this.GetProperty(propId);
				if (pd != null) {
					// mixed behavior of the same subproperty not allowed
					if (pd.valuetype != acn.ddl.PropertyValueType.immediate) {
						throw new InvalidOperationException(string.Format("existing subproperty '{0}' for behavior: '{1}:{2}' has not immediate value type", pd.id,behaviorset,behavior));
					}
					// mixed behavior of the same subproperty not allowed
					if (!pd.HasBehavior(behaviorset,behavior)) {
						throw new InvalidOperationException(string.Format("existing subproperty '{0}' does not have the required behavior: '{1}:{2}'", pd.id,behaviorset,behavior));
					}
					int count = pd.GetValueCount();
					if (count == 0) {
						// existing immediate property without value is an anomaly: silently fix it by setting the value
						pd.SetValue(type,value);
					}
					else {
						// one or more values already exist, verify or update, depending on array index and verify flag
						acn.ddl.Value pdvalue = null;
						if ((index >= 0) && (index < count)) {
							// array property with existing value at array position
							pdvalue = pd.GetValueByIndex(index);
						}
						else {
							// if all values are the same, only one entry is maintained
							pdvalue = pd.GetValueByIndex(count - 1);
						}
						if ((pdvalue == null) || (pdvalue.type != type)) {
							throw new InvalidOperationException(string.Format("missing value of immediate subproperty '{0}', or invalid or invalid ValueDataType '{1}'", pd.id,type));
						}
						if (index < count) {
							// not an array property or array property with existing value at array position: verify or update
							pdvalue.SetValue(value,verify);
						}
						else {
							// index >= count: in case of (second entry of) an array: check difference of previous value
							// if all values are the same, only one entry is maintained
							if ((count > 1) || (string.CompareOrdinal(pdvalue.Value,value) != 0)) {
								// different values in the array: write them all out
								for (; count < index; count++) {
									pd.AddValue(pdvalue.type, pdvalue.Value);
								}
								pd.AddValue(type, value);
							}
						}
					}
				}
				else {
					pd = this.GetOrAddProperty(propId,acn.ddl.PropertyValueType.immediate);
					pd.AddBehavior(behaviorset,behavior);
					pd.SetValue(type,value);
				}
			}
			return pd;
		}

		/// Add the specified property as child of this property.
		/// @param prop the child property to add
		internal void AddProperty(acn.ddl.Property prop) {
			if (prop != null) {
				ArrayAddChildNode(ref itemsField, prop);
			}
		}

		/// Create a new Value and add it to the property.
		/// @pre valuetype == acn.ddl.PropertyValueType.immediate
		/// @param type the type of the value
		/// @param value the value of the Value
		/// @return the added Value
		/// @exception InvalidOperationException valuetype != acn.ddl.PropertyValueType.immediate
		public acn.ddl.Value AddValue(acn.ddl.ValueDataType type, string value) {
			if (this.valuetype != acn.ddl.PropertyValueType.immediate) {
				throw new InvalidOperationException(string.Format("cannot add value to property {0} of type {1}",this.id,this.valuetype));
			}
			acn.ddl.Value result = new acn.ddl.Value(type);
			result.SetValue(value);
			ArrayAddChildNode(ref valueField, result);
			return result;
		}

		/// Recursively find the behavior with the specified name (start) and (optionally) set.
		/// The name is matched with the start of the specified behavior name, e.g. "type."
		/// The set can be set to null to allow any set.
		/// @note First local behavior references are searched, 
		///   then refinements of these behaviors are searched recursively.
		/// @param set the behaviorset of the behavior, if null any set
		/// @param name the (start of the) name of the behavior
		/// @return the matching Behavior(Reference) or null if not found.
		public acn.ddl.BehaviorReference FindBehavior(string set, string name) {
			if (behaviorField != null) {
				foreach (acn.ddl.Behavior b in behaviorField) {
					if (b.MatchesBehaviorGroup(set,name)) {
						return b;
					}
				}
				foreach (acn.ddl.Behavior b in behaviorField) {
					acn.ddl.BehaviorReference result = b.FindBehavior(set,name);
					if (result != null) {
						return result;
					}
				}
			}
			return null;
		}

		/// Get the behavior with the specified name and set.
		/// @param set the behaviorset of the behavior
		/// @param name the name of the behavior
		/// @return the matching Behavior or null if not found.
		public acn.ddl.Behavior GetBehavior(string set, string name) {
			if (behaviorField != null) {
				foreach (acn.ddl.Behavior b in behaviorField) {
					if (b.MatchesBehavior(set,name)) {
						return b;
					}
				}
			}
			return null;
		}

		/// Get the child node with the specified index.
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			int count = base.GetChildNodeCount();
			if ((index >= 0) && (index < count)) {
				return base.GetChildNode(index);
			}
			index -= count;
			count = GetChildNodeCountOf(behaviorField);
			if ((index >= 0) && (index < count)) {
				return behaviorField[index];
			}
			index -= count;
			count = GetChildNodeCountOf(protocolField);
			if ((index >= 0) && (index < count)) {
				return protocolField[index];
			}
			index -= count;
			count = GetChildNodeCountOf(valueField);
			if ((index >= 0) && (index < count)) {
				return valueField[index];
			}
			index -= count;
			count = GetChildNodeCountOf(itemsField);
			if ((index >= 0) && (index < count)) {
				return itemsField[index];
			}
			return null;
		}

		/// Get the number of child nodes
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount()
					+ GetChildNodeCountOf(behaviorField)
					+ GetChildNodeCountOf(protocolField)
					+ GetChildNodeCountOf(valueField)
					+ GetChildNodeCountOf(itemsField);
		}

		/// Get the array of child nodes, null if not available.
		internal override acn.ddl.IdentifiedNode[] GetIdentifiedChildNodes() {
			return itemsField;
		}

		/// Get the property with the specified identifier, 
		/// or create and add a new Property.
		/// If the id is null, the property is created anyway.
		/// If a matching property is found, the type is verified (unless NULL is specified)
		/// @param id the identifier of the property
		/// @param type the valuetype of the property
		/// @param label the label text of the property
		/// @return the new or existing property
		public acn.ddl.Property GetOrAddProperty(string id, acn.ddl.PropertyValueType type = acn.ddl.PropertyValueType.NULL, string label = null) {
			acn.ddl.Property result = GetProperty(id);
			if (result == null) {
				if (GetIdentifiedNode(id) != null) {
					throw new InvalidOperationException(string.Format("property '{0}' already has a child node '{1}'",this.id,id));
				}
				// see if any group of this property exists
				acn.ddl.Property group = GetGroupOfProperty(id);
				if (group != null) {
					result = new acn.ddl.Property(id,type,label);
					group.AddProperty(result);
				}
				else {
					result = new acn.ddl.Property(id,type,label);
					AddProperty(result);
				}
			}
			else {
				if (type != acn.ddl.PropertyValueType.NULL) {
					if (result.valuetype != type) {
						// do not update: it is a GetOrAdd, not addorupdate
						throw new InvalidOperationException(string.Format("property '{0}' has valuetype '{1}' in stead of '{2}'",result.id,result.valuetype,type));
					}
				}
			}
			return result;
		}

		/// Get the property with the specified id, null if not found.
		/// @param id the id or full id of the property to get
		/// @return the child or descendant property with the specified identifier, null if not found
		public acn.ddl.Property GetProperty(string id) {
			return (this.GetIdentifiedNode(id) as acn.ddl.Property);
		}

		/// Get the group of the property with the specified id, null if not found.
		/// @param id the id or full id of the property to get the group of
		/// @return the group of the property with the specified identifier, null if not found
		public acn.ddl.Property GetGroupOfProperty(string id) {
			return this.GetGroupOfIdentifiedNode(id) as acn.ddl.Property;
		}

		/// Get the child property with the specified behavior, null if not found
		/// @param nodes the nodes to check
		/// @param behaviorset the set of the behavior definition
		/// @param behavior the behavior from the group to find.
		/// @return The child property with the specified behavor, null if not found.
		internal static acn.ddl.Property GetPropertyNodeWithBehavior(ref acn.ddl.IdentifiedNode[] nodes, string behaviorset, string behavior) {
			if (nodes != null) {
				foreach (acn.ddl.IdentifiedNode node in nodes) {
					acn.ddl.Property property = node as acn.ddl.Property;
					if ((property != null) && property.HasBehavior(behaviorset,behavior)) {
						return property;
					}
				}
			}
			return null;
		}

		/// Get the child property with the specified behavior, null if not found
		/// @param qname the qualified name of the behavior
		/// @return The child property with the specified behavor, null if not found.
		public acn.ddl.Property GetPropertyWithBehavior(string qname) {
			string set = acn.ddl.BehaviorReference.GetPrefixOfQName(qname);
			string name = acn.ddl.BehaviorReference.GetNameOfQName(qname);
			return GetPropertyNodeWithBehavior(ref itemsField, set, name);
		}

		/// Get the child property with the specified behavior, null if not found
		/// @param behaviorset the set of the behavior definition
		/// @param behavior the behavior from the group to find.
		/// @return The child property with the specified behavor, null if not found.
		public acn.ddl.Property GetPropertyWithBehavior(string behaviorset, string behavior) {
			return GetPropertyNodeWithBehavior(ref itemsField, behaviorset, behavior);
		}

		/// Create a new Protocol and add it to the Property.
		/// If the protocol is already specified in the property, that protocol is returned.
		///
		/// If the Device of the property not already has a UseProtocol for this protocol,
		///   it is added to that device as well.
		///
		/// @note One or more protocol entries are required on acn.ddl.PropertyValueType.network properties
		///   and optional on other properties.
		/// 
		/// @param name the name of the protocol
		/// @return the (new) protocol with the specified name
		public acn.ddl.Protocol GetOrAddProtocol(string name) {
			acn.ddl.Protocol result = GetProtocol(name);
			if (result == null) {
				result = new acn.ddl.Protocol(name);
				ArrayAddChildNode(ref protocolField, result);
				// make sure the Device uses this protocol
				acn.ddl.Device device = GetDevice();
				if (device != null && (device.GetUseProtocol(name) == null)) {
					device.AddUseProtocol(name);
				}
			}
			return result;
		}

		/// Get the Protocol with the specified name.
		/// @param name the name of the Protocol to find.
		/// @return the Protocol or null if not found
		public acn.ddl.Protocol GetProtocol(string name) {
			if (protocolField != null) {
				foreach (acn.ddl.Protocol prot in protocolField) {
					if (prot.name == name) {
						return prot;
					}
				}
			}
			return null;
		}

		/// Get the Value of the property with the specified identifier.
		/// If no id is specified, the first Value if returned.
		/// @param id the identifier of the value node
		/// @return the Value node, null if not found
		public acn.ddl.Value GetValue(string id = null) {
			if (valueField != null) {
				foreach (acn.ddl.Value result in valueField) {
					if (string.IsNullOrEmpty(id) || (result.id == id)) {
						return result;
					}
				}
			}
			return null;
		}

		/// Get the Value of the property with the specified index.
		/// If the property only has one value, that is returned regardless of the index.
		/// @return the Value at the specified index, null if not present range.
		public acn.ddl.Value GetValue(int index) {
			if (valueField != null) {
				if (valueField.Length == 1) {
					return valueField[0];
				}
				if ((index >= 0) && (index < valueField.Length)) {
					return valueField[index];
				}
			}
			return null;
		}

		/// Get the Value of the property with the specified index.
		/// @return the Value at the specified index, null if not present / out of range.
		/// @exception ArgumentOutOfRangeException if index is not a valid index
		/// @deprecated
		public acn.ddl.Value GetValueByIndex(int index) {
			if (valueField != null) {
				if ((index >= 0) && (index < valueField.Length)) {
					return valueField[index];
				}
				throw new ArgumentOutOfRangeException("value index invalid","index");
			}
			return null;
		}

		/// Get the number of Values of the property.
		/// @return the number of values
		public int GetValueCount() {
			return (valueField == null) ? 0 : valueField.Length;
		}

		/// Get the Value value (as string) of the property with the specified identifier.
		/// If no id is specified, the first Value if returned.
		/// @param id the identifier of the value node
		/// @return the Value string, null if not found
		public string GetValueString(string id = null) {
			acn.ddl.Value result = GetValue(id);
			return (result == null) ? null : result.Value;
		}

		/// Get the Value value (as string) of the property with the specified index.
		/// @param id the identifier of the value node
		/// @return the Value string, null if not found
		public string GetValueString(int index) {
			acn.ddl.Value result = GetValue(index);
			return (result == null) ? null : result.Value;
		}

		/// Test if this property has the specified behavior.
		/// @note First local behavior references are searched, 
		///   then refinements of these behaviors are searched recursively.
		/// @param qname the qualified name of the behavior
		/// @return true if the property has this Behavior, false otherwise.
		public bool HasBehavior(string qname) {
			string set = acn.ddl.BehaviorReference.GetPrefixOfQName(qname);
			string name = acn.ddl.BehaviorReference.GetNameOfQName(qname);
			return HasBehavior(set,name);
		}

		/// Test if this property has the specified behavior.
		/// @note First local behavior references are searched, 
		///   then refinements of these behaviors are searched recursively.
		/// @param set the behaviorset of the behavior
		/// @param name the name of the behavior
		/// @return true if the property has this Behavior, false otherwise.
		public bool HasBehavior(string set, string name) {
			if (behaviorField != null) {
				foreach (acn.ddl.Behavior b in behaviorField) {
					if (b.MatchesBehavior(set, name)) {
						return true;
					}
				}
				foreach (acn.ddl.Behavior b in behaviorField) {
					if (b.RefinesBehavior(set, name)) {
						return true;
					}
				}
			}
			return false;
		}
		
		/// Test whether the property has a constant value.
		public bool HasConstantValue() {
			return HasBehavior("acnbase.bset","constant");
		}

		/// Test whether the property is a property with immediate valuetype.
		public bool HasImmediateValue() {
			return (valuetype == acn.ddl.PropertyValueType.immediate);
		}

		/// Test whether the property is a property with implied valuetype.
		public bool HasImpliedValue() {
			return (valuetype == acn.ddl.PropertyValueType.implied);
		}

		/// Test whether the property is a property with network valuetype.
		public bool HasNetworkValue() {
			return (valuetype == acn.ddl.PropertyValueType.network);
		}

		/// Test whether the property is a property with NULL valuetype.
		public bool HasNullValue() {
			return (valuetype == acn.ddl.PropertyValueType.NULL);
		}

		/// Test whether the property has a persistent value.
		public bool HasPersistentValue() {
			return HasBehavior("acnbase.bset","persistent");
		}

		/// Test whether the property has a volatile value.
		public bool HasVolatileValue() {
			return HasBehavior("acnbase.bset","volatile");
		}

		/// Test whether the property is a compound property.
		/// A compound property may consist of multiple (sub) property values. It is either:
		/// - a structure, record, or class: multiple (names) properties with different behaviors
		/// - an array: multiple (indexed) properties with the same behavior
		public bool IsCompound() {
			return ((valuetype == acn.ddl.PropertyValueType.NULL) || HasArray);
		}

		/// Set the Value of the property.
		/// If the property has multiple values, they are replaced by this single one.
		/// @param type the type of the value
		/// @param value the value of the Value
		/// @return the set Value
		public acn.ddl.Value SetValue(acn.ddl.ValueDataType type, string value) {
			acn.ddl.Value result;
			if ((valueField != null) && (valueField.Length == 1)) {
				result = valueField[0];
				result.type = type;
				result.SetValue(value);
			}
			else {
				valueField = null;
				result = AddValue(type,value);
			}
			return result;
		}

		protected override void UpdateChildNodes() {
			base.UpdateChildNodes();
			UpdateChildNodesIn(behaviorField);
			UpdateChildNodesIn(protocolField);
			UpdateChildNodesIn(valueField);
			UpdateChildNodesIn(itemsField);
			// update of Property after load needed (@todo rename UpdateChildNodes())
			this.ArrayIndex = InvalidArrayIndex;
		}
	}

    public partial class PropertyPointer : IdentifiedNode {
		
		[System.Xml.Serialization.XmlIgnoreAttribute()]
		public string reference {
			get { return this.@ref; }
			set { this.@ref = value; }
		}

		/// Default constructor
		public PropertyPointer() : base() {
		}

		/// Initializing constructor
		/// @note the referenced property should be available (obsiously), but that
		///   is not checked here.
		/// @param id the identifier of the PropertyPointer
		/// @param reference the the identifier of the defining declaration of the property
		/// @exception ArgumentException if the name is null or empty
		public PropertyPointer(string id, string reference) : base(id) {
			if (string.IsNullOrEmpty(reference)) {
				throw new ArgumentException("empty property pointer reference","reference");
			}
			this.@ref = reference;
		}
	}

    public partial class Protocol : IdentifiedNode {

		/// Default constructor
		public Protocol() : base() {
		}

		/// Initializing constructor
		/// @param name the name of the protocol
		/// @exception ArgumentException if the name is null or empty
		public Protocol(string name) : base() {
			if (string.IsNullOrEmpty(name)) {
				throw new ArgumentException("empty protocol name","name");
			}
			this.name = name;
		}

		/// Add or update the specified protocol attributes for the parent property.
		/// @note Use this operation in stead of SetAttributes() for array properties that need
		///   multiple protocol specifications.
		/// The attributes are protocol specific, but common attributes are
		/// the property address, or other specific access characteristics.
		/// @note We assume for now that all attribute elements in the protocol have the same name.
		/// @param elementName the qualified name of the XmlElement that holds the attributes
		/// @param attrs the attribute set to assign
		/// @param namespaceURI the namespace URI of the element (if any)
		/// @param index the index of the element of the array property, -1 for non-array property
		/// @param verify if true the attributes are verified rather than updated on an existing element
		/// @exception XmlException if elementName is not a valid NCName
		/// @exception InvalidOperationException if the verification fails
		public void AddOrUpdateAttributes(string elementName, System.Collections.IDictionary attrs, string namespaceURI = DDLNamespace, int index = -1, bool verify = false) {
			// validate the elementName
			System.Xml.XmlConvert.VerifyName(elementName);
			if (attrs != null) {
				System.Xml.XmlDocument dom = GetOrCreateDOMDocument();
				int count = GetElementCount(elementName);
				if (count == 0) {
					System.Xml.XmlElement element = dom.CreateElement(elementName,namespaceURI);
					SetOrVerifyAttributes(element,attrs);
					RegisterXmlNamespace(elementName,namespaceURI);
					AddElement(element);
				}
				else {
					// one or more elements already exist, verify or update, depending on array index and verify flag
					System.Xml.XmlElement element = null;
					if ((index >= 0) && (index < count)) {
						// array property with existing value at array position
						element = this.GetElement(elementName,index);
					}
					else {
						// if all values are the same, only one entry is maintained
						element = this.GetElement(elementName, count - 1);
					}
					if (element == null) {
						throw new InvalidOperationException(string.Format("missing protocol specification '{0}'", elementName));
					}
					if (index < count) {
						// not an array property or array property with existing value at array position: verify or update
						SetOrVerifyAttributes(element,attrs,verify);
					}
					else {
						// index >= count: in case of (second entry of) an array: check difference of previous value
						// if all values are the same, only one entry is maintained
						if ((count > 1) || (CompareAttributes(element,attrs) != 0)) {
							// different values in the array: write them all out
							for (; count < index; count++) {
								AddElement(element.CloneNode(true) as System.Xml.XmlElement);
							}
							element = element.CloneNode(false) as System.Xml.XmlElement;
							SetOrVerifyAttributes(element,attrs);
							AddElement(element);
						}
					}
				}
			}
		}

		/// Add a protocol specification element.
		/// @param element the element node
		public void AddElement(System.Xml.XmlElement element) {
			if (element == null) {
				throw new ArgumentException("emtpy element node","element");
			}
			ArrayAdd(ref anyField, element);
		}
		
		/// Compare the attributes of the element with the specified attributes.
		/// @param element the XmlElement to compare the attributes of
		/// @param attrs the attributes to compare
		/// @return 0 if the values of the attrs match with the attributes of the element, <0 or > 0 otherwise
		/// @exception ArgumentNullException for element and attrs if they are null
		public int CompareAttributes(System.Xml.XmlElement element, System.Collections.IDictionary attrs) {
			if (element == null) {
				throw new ArgumentNullException("element");
			}
			if (attrs == null) {
				throw new ArgumentNullException("attrs");
			}
			int result = 0;
			foreach (System.Collections.DictionaryEntry entry in attrs) {
				string value = element.GetAttribute(entry.Key.ToString());
				result = string.CompareOrdinal(value, entry.Value.ToString());
				if (result != 0) {
					break;
				}
			}
			return result;
		}

		/// Get the child node with the specified index.
		/// @note anyField contains XmlElement objects, not Node objects, and
		///    therefore the child nodes of a Protocol are not part of the Node tree (apart from the label)
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			return base.GetChildNode(index);
		}

		/// Get the number of child nodes
		/// @note anyField contains XmlElement objects, not Node objects
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount();
		}

		/// Get the index'st protocol specification element with the specified name.
		/// @note Any index <= 0 will return the first element
		/// @param elementName the name of the element
		/// @param index the index of the element to get of this name.
		/// @return the index'st element child node with the specified name
		public System.Xml.XmlElement GetElement(string elementName, int index = 0) {
			if (anyField != null) {
				int counter = 0;
				foreach (System.Xml.XmlElement element in anyField) {
					if (element.Name == elementName) {
						if ((index < 0) || (counter == index)) {
							return element;
						}
						counter++;
					}
				}
			}
			return null;
		}

		/// Get the number of protocol specification elements with the specified name.
		/// @param elementName the name of the element; if null or empty: any element name
		/// @return the number of element child nodes with the specified (or any) name
		public int GetElementCount(string elementName = null) {
			int counter = 0;
			if (anyField != null) {
				if (string.IsNullOrEmpty(elementName)) {
					counter = anyField.Length;
				}
				else foreach (System.Xml.XmlElement element in anyField) {
					if (element.Name == elementName) {
						counter++;
					}
				}
			}
			return counter;
		}

		/// Set the protocol attributes for the parent property.
		/// The attributes are protocol specific, but common attributes are
		/// the property address, or other specific access characteristics.
		/// @param elementName the qualified name of the XmlElement that holds the attributes
		/// @param attrs the attribute set to assign
		/// @param namespaceURI the namespace URI of the element (if any)
		/// @exception XmlException if elementName is not a valid NCName
		public void SetAttributes(string elementName, System.Collections.IDictionary attrs, string namespaceURI = DDLNamespace) {
			// validate the elementName
			System.Xml.XmlConvert.VerifyName(elementName);
			System.Xml.XmlElement element = GetElement(elementName);
			if (element == null) {
				System.Xml.XmlDocument dom = GetOrCreateDOMDocument();
				element = dom.CreateElement(elementName,namespaceURI);
				AddElement(element);
			}
			RegisterXmlNamespace(elementName,namespaceURI);
			element.RemoveAllAttributes();
			SetOrVerifyAttributes(element,attrs);
		}

		/// Set or verify the attributes of the element with the specified attributes.
		/// @param element the XmlElement to compare the attributes of
		/// @param attrs the attributes to set of verify
		/// @param verify if the the attributes are compared, rather then set
		/// @exception ArgumentNullException for element and attrs if they are null
		/// @exception InvalidOperationException if verify is true and the values of the attrs do not match with the attributes of the element
		public void SetOrVerifyAttributes(System.Xml.XmlElement element, System.Collections.IDictionary attrs, bool verify = false) {
			if (element == null) {
				throw new ArgumentNullException("element");
			}
			if (attrs == null) {
				throw new ArgumentNullException("attrs");
			}
			foreach (System.Collections.DictionaryEntry entry in attrs) {
				string value = element.GetAttribute(entry.Key.ToString());
				if (string.CompareOrdinal(value, entry.Value.ToString()) != 0) {
					if (verify) {
						throw new InvalidOperationException(string.Format("protocol {0} specification '{1}' value mismatch: '{2}', expected '{3}'", 
										this.name,entry.Key.ToString(),value,entry.Value.ToString()));
					}
					else {
						element.SetAttribute(entry.Key.ToString(),entry.Value.ToString());
						this.NotifyNodeChanged();
					}
				}
			}
		}

		protected override void UpdateChildNodes() {
			base.UpdateChildNodes();
			// register any namespaces of the child nodes
			if (anyField != null) {
				foreach (System.Xml.XmlElement element in anyField) {
					RegisterXmlNamespace(element.Name,element.NamespaceURI);
				}
			}
		}
	}

	/// A Reader class for reading ACN DDL related documents from a stream.
	/// The class itself can deserialize an ACN DDL module XML file with the ImportDocument() operation.
	/// Furthermore, the class has properties to facilitate reading of all kind of input documents and 
	/// build or update ACN DDL modules from that.
	public class Reader : nl.nlsw.Items.Reader {

		/// XML Deserializer
		private XmlSerializer _Serializer = new System.Xml.Serialization.XmlSerializer(typeof(DDLDocument));

		/// The current document
		public Document CurrentDocument {
			get { return CurrentItem as Document; }
		}

		/// The current DocumentList from which the modules are written
		public acn.ddl.DocumentList CurrentDocumentList {
			get { return CurrentItemList as acn.ddl.DocumentList; }
			set { CurrentItemList = value; }
		}

		/// The current device
		public Device CurrentDevice {
			get { return CurrentModule as Device; }
		}

		/// The current module
		public Module CurrentModule {
			get { return (CurrentDocument != null && CurrentDocument.RootNode != null) ? CurrentDocument.RootNode.Module : null; }
		}

		/// A regex for matching or replacing characters in a Name (that might be arbitrary text)
		/// that are not allowed in an XML NCName when only using BasicLatin.
		/// The allowed characters are: A-Z a-z 0-9 LOW-LINE HYPHEN-MINUS FULL-STOP MIDDLE-DOT
		public static readonly Regex ReplaceNonBasicLatinXmlNCNameRegex = new Regex(@"[^A-Z_a-z0-9_\.\-\u00B7]",
			RegexOptions.Compiled|RegexOptions.CultureInvariant);

		/// A regex for matching or replacing characters in a Name (that might be arbitrary text)
		/// that are not allowed as first character of an XML NCName when only using BasicLatin.
		/// The allowed characters are: A-Z a-z LOW-LINE
		public static readonly Regex MatchNonBasicLatinXmlNCNameStartCharRegex = new Regex(@"^[^A-Z_a-z0-9_]",
			RegexOptions.Compiled|RegexOptions.CultureInvariant);

		/// A regex for matching or replacing special characters in a Name (that might be arbitrary text)
		/// that are not allowed in an identifier.
		/// Name special characters are any non letter or digit or LOW LINE
		public static readonly Regex ReplaceNameSpecialCharsIdentifierRegex = new Regex(@"[^a-zA-Z0-9_]",
			RegexOptions.Compiled|RegexOptions.CultureInvariant);

		/// A regex for matching or replacing a character sequence that can be replaced as CamelCase notation.
		public static readonly Regex ReplaceNameCamelCaseOpportunitiesRegex = new Regex(@"([a-zA-Z0-9_])[\s\-]+([A-Z])",
			RegexOptions.Compiled|RegexOptions.CultureInvariant);

		/// Convert a name to an identifier.
		/// - The name is first trimmed (leading and trailing whitespace is removed).
		/// - CamelCase opportunities are replaced as such 
		/// - Any non letter a-zA-Z or digit is replaced with LOW LINE (underscore).
		/// - If the first character is a digit, a LOW LINE is prepended
		/// @deprecated use ConvertToBasicLatinXmlNCName()
		public static string ConvertNameToIdentifier(string name) {
			name = ReplaceNameCamelCaseOpportunitiesRegex.Replace(name.Trim(),"$1$2");
			name = ReplaceNameSpecialCharsIdentifierRegex.Replace(name,"_");
			if ((name.Length > 0) && (char.IsDigit(name[0]))) {
				name = string.Concat("_",name);
			}
			return name;
		}

		/// Convert a text string to an XML NCName (an XML Name without colon characters; BasicLatin characters only).
		/// The allowed characters are: A-Z a-z 0-9 LOW-LINE HYPHEN-MINUS FULL-STOP MIDDLE-DOT
		/// The allowed characters at the first position are A-Z a-z LOW-LINE
		/// - The name is first trimmed (leading and trailing whitespace is removed).
		/// - CamelCase opportunities are replaced as such
		/// - Any not allowed character is replaced with LOW LINE (underscore).
		/// - If the first character is not allowed at that position, a LOW LINE is prepended
		public static string ConvertToBasicLatinXmlNCName(string name) {
			name = ReplaceNameCamelCaseOpportunitiesRegex.Replace(name.Trim(),"$1$2");
			name = ReplaceNonBasicLatinXmlNCNameRegex.Replace(name,"_");
			if (MatchNonBasicLatinXmlNCNameStartCharRegex.IsMatch(name)) {
				name = string.Concat("_",name);
			}
			return name;
		}

		/// Test whether a text string is an XML NCName (an XML Name without colon characters; BasicLatin characters only).
		/// The allowed characters are: A-Z a-z 0-9 LOW-LINE HYPHEN-MINUS FULL-STOP MIDDLE-DOT
		/// The allowed characters at the first position are A-Z a-z LOW-LINE
		public static bool IsBasicLatinXmlNCName(string name) {
			return !ReplaceNonBasicLatinXmlNCNameRegex.IsMatch(name)
					&& !MatchNonBasicLatinXmlNCNameStartCharRegex.IsMatch(name);
		}


		/// Default constructor
		public Reader() : base() {
		}

		/// Initializing constructor
		public Reader(System.Text.Encoding defaultEncoding = null) : base(defaultEncoding) {
		}

		///
		/// Import the specified document into the DocumentList.
		/// @TODO do we need this?
//		public void ImportDocument(Document document) {
//			if (CurrentItemList != null && (document != null)) {
//				CurrentItemList.Add(document);
//				// count the imported items
//				ItemCount++;
//			}
//		}

		///
		/// Import the specified DDLDocument into the DocumentList.
		/// The DDLDocument is wrapped in a Document.
		/// @param root the DDL document root node to import
		/// @return the imported Document
		/// @exception InvalidOperationException if the reader has no CurrentItemList
		public Document ImportDocument(DDLDocument root) {
			Document document = null;
			if (root != null) {
				document = new Document();
				document.RootNode = root;
				document.FileInfo = this.FileInfo;
				if (CurrentItemList == null) {
					throw new InvalidOperationException("the reader has no DocumentList attached");
				}
				CurrentItemList.Add(document);
				// count the imported items
				ItemCount++;
			}
			return document;
		}

		///
		/// Import a document from the TextReader into the DocumentList.
		/// @param reader the text reader
		public Document ImportDocument(TextReader reader) {
			DDLDocument root = (DDLDocument)_Serializer.Deserialize(reader);
			return ImportDocument(root);
		}

		///
		/// Import a document from the specified file into the DocumentList.
		/// @param file the file of the document to import
		public Document ImportDocument(System.IO.FileInfo file) {
			this.FileInfo = file;
			Document result = null;
			try {
				this.TextReader = new System.IO.StreamReader(file.FullName, this.DefaultEncoding);
				result = ImportDocument(this.TextReader);
			}
			finally {
				this.FileInfo = null;
				this.TextReader = null;
			}
			return result;
		}

		///
		/// Import a document from the specified file into the DocumentList.
		/// @param filename the name (and path0 of the file of the document to import
		public Document ImportDocument(string filename) {
			return ImportDocument(new System.IO.FileInfo(filename));
		}
	}

	///
	/// Reference to the BehaviorDefinition that is refined.
	///
	public partial class Refines : BehaviorReference {

        /// Default constructor
		public Refines() : base() {
		}
		
        /// Initializing constructor
		/// @param set the UUID (or UUIDname) of the BehaviorSet (max length = 36)
		/// @param name the name of the behavior
		/// @exception XmlException if set is not a NMTOKEN or name is not an NCName
		/// @exception ArgumentException if set.Length > 36
		public Refines(string set, string name) : base(set,name) {
		}
	}

    public partial class Section : IdentifiedNode {
       
		/// Default constructor
		public Section() : base() {
		}

		/// Initializing constructor
		/// @param id the identifier of the node
		/// @exception XmlException if the identifier is not valid
		public Section(string id) : base(id) {
		}

		/// Get the child node with the specified index.
		/// @note The itemsField is an object[], so left-out of the children for now
		/// @return the node with the specified index, or null if index out of range
		public override Node GetChildNode(int index) {
			int count = base.GetChildNodeCount();
			if ((index >= 0) && (index < count)) {
				return base.GetChildNode(index);
			}
			index -= count;
			count = GetChildNodeCountOf(hdField);
			if ((index >= 0) && (index < count)) {
				return hdField;
			}
			//index -= count;
			//count = GetChildNodeCountOf(itemsField);
			//if ((index >= 0) && (index < count)) {
			//	return itemsField[index];
			//}
			return null;
		}

		/// Get the number of child nodes
		/// @note The itemsField is an object[], so left-out of the children for now
		public override int GetChildNodeCount() {
			return base.GetChildNodeCount()
					+ GetChildNodeCountOf(hdField);
					//+ GetChildNodeCountOf(itemsField);
		}

		protected override void UpdateChildNodes() {
			base.UpdateChildNodes();
			UpdateChildNodesIn(hdField);
			UpdateChildNodesIn(itemsField);
		}
    }

	/// A language specific text string.
	/// The string is identified with a key in the LanguageSet.
	///
    public partial class String : IdentifiedLeafNode {
		
		/// Default constructor
		public String() : base() {
		}
		
		/// Initializing constructor.
		/// @param key the NCName identifier of the string
		/// @exception XmlException if the key is not a valid XML NCName
		public String(string key, string value) : base(null,value) {
			System.Xml.XmlConvert.VerifyNCName(key);
			this.key = key;
		}
		
		public override string ToString() {
			return this.Value;
		}
	}

	/// A NodeIterator is used to enumerate a node tree in document order using the view
	/// defined by an optional filter.
	///
	/// This class has the interface and behavior of a W3 Document Object Model NodeIterator,
	/// without the WhatToShow feature.
	/// It also has an System.Collections.Generic.IEnumerator<Node> interface, providing support
	/// for use in C# foreach loops.
	public class NodeIterator : acn.ddl.INodeIterator, System.Collections.IEnumerable {
		private INodeFilter _filter = null;
		
		/// Initializing constructor
		public NodeIterator(Node root, INodeFilter filter = null) {
			this.rootNode = root;
			// position the iterator before the first node (root node)
			this.currentNode = null;
			this.referenceNode = rootNode;
			// as if latest action was previousNode()
			this.MovingForward = false;
			this._filter = filter;
		}

		/// The 'current node' of the iterator, i.e. the last value returned by nextNode() or
		/// previousNode(). Notice the difference between last node returned (= the referenceNode),
		/// and last value returned (= currentNode), which may be null when begin or end
		/// of the collection is reached.
		/// When the iterator points in the collection, currentNode equals referenceNode.
		public Node currentNode { get; protected set; }

		/// Get the element in the collection at the current position of the enumerator.
		/// Returns null if the enumerator is invalid or outside the collection.
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.collections.generic.ienumerator-1.current
		Node IEnumerator<acn.ddl.Node>.Current {
			get {
				return currentNode;
			}
		}

		/// Get the element in the collection at the current position of the enumerator.
		/// IEnumerator.Current
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.collections.ienumerator.current
		/// @exception InvalidOperationException if the IEnumerator is not in the collection.
		object IEnumerator.Current {
			get {
				if (currentNode == null) {
					throw new InvalidOperationException("iterator is not in the collection");
				}
				return currentNode;
			}
		}

		/// The filter used to hide nodes from the view.
		public INodeFilter filter { get { return _filter; } }

		/// Latest action was nextNode(), moving the referenceNode in forward direction.
		protected bool MovingForward { get; set; }

		/// The node that indicates the position of the iterator.
		/// The position of a NodeIterator can best be described with respect to the last node returned,
		/// which we will call the reference node. When an iterator is created, the first node is the reference node,
		/// and the iterator is positioned before the reference node.
		/// The referenceNode may be invisible, e.g. at initialisation, or when the referenceNode is removed
		/// from the tree.
		/// @see https://www.w3.org/TR/DOM-Level-2-Traversal-Range/traversal.html#Traversal-NodeIterator
		public Node referenceNode { get; protected set; }

		/// The root node of the iterator, as specified when it was created.
		Node INodeIterator.root { get { return rootNode; } }
		
		/// The root node of the iterator, as specified when it was created.
		public Node rootNode { get; protected set; }

		/// Detaches the NodeIterator from the set which it iterated over,
		/// releasing any computational resources and placing the iterator in the INVALID state.
		/// After detach() has been invoked, calls to nextNode() or previousNode() will raise an InvalidOperationException.
		void INodeIterator.detach() {
			this.rootNode = null;
			this.currentNode = null;
			this.referenceNode = null;
        }
		
		/// Destruction of the object. It is invalidated.
		void IDisposable.Dispose() {
			((INodeIterator)this).detach();
		}

		/// In case this object is directly used in 'foreach', the GetEnumerator() operation is required.
		System.Collections.IEnumerator System.Collections.IEnumerable.GetEnumerator() {
			return (System.Collections.IEnumerator)this;
		}

		/// Advances the enumerator to the next element of the collection.
		/// Enumerators are positioned before the first element until the first MoveNext() call.
		/// IEnumerator.MoveNext()
		///
		/// @see https://docs.microsoft.com/en-us/dotnet/api/system.collections.ienumerator.movenext
		/// @exception No InvalidOperationException if the collection was modified after the enumerator was created.
		/// @return true if the enumerator was successfully advanced to the next element;
		///    false if the enumerator has passed the end of the collection.
		public bool MoveNext() {
			Node next = nextNode();
			return next != null;
		}
		
		/// IEnumerator.Reset()
		/// Sets the enumerator to its initial position, before the first element in the collection.
		/// https://docs.microsoft.com/en-us/dotnet/api/system.collections.ienumerator.reset
		public void Reset() {
			currentNode = null;
			referenceNode = rootNode;
			// as if latest action was previousNode()
			MovingForward = false;
		}
		
		/// Check is the specified node is visible in the view of the iterator
		/// @param node the node to evaluate
		/// @return the result of the filter
		/// @exception ArgumentNullException if node is null
		protected NodeFilterResult isVisible(Node node) {
			NodeFilterResult result = NodeFilterResult.FILTER_ACCEPT;
			if (node == null) {
				throw new ArgumentNullException("node");
			}
			// check the filter
			if (filter != null) {
				result = filter.acceptNode(node);
			}
			return result;
		}

		/// Returns the next (visible) node in the set and advances the position of the iterator in the set.
		/// After a NodeIterator is created, the first call to nextNode() returns the first node in the set.
		/// @return The next Node in the set being iterated over, or null if there are no more members in that set.
		/// @exception InvalidOperationException if this method is called after the detach method was invoked.
		public Node nextNode() {
			if (this.rootNode == null) {
				throw new InvalidOperationException("NodeIterator has no root node");
			}
			if (referenceNode == null) {
				// should never happen
				referenceNode = rootNode;
			}
			// locate next visible node
			Node parent = referenceNode;
			int count = parent.GetChildNodeCount();
			int index = 0;
			if (!MovingForward) {
				// change of direction: return the referenceNode (if visible)
				MovingForward = true;
				switch (isVisible(referenceNode)) {
				case NodeFilterResult.FILTER_ACCEPT:
					currentNode = referenceNode;
					return currentNode;
				case NodeFilterResult.FILTER_REJECT:
					// ignore children of this node as well, proceed with next sibling of referenceNode
					parent = referenceNode;
					count = 0;
					index = 0;
					break;
				case NodeFilterResult.FILTER_SKIP:
					// this node is not shown, but its children might
					parent = referenceNode;
					count = parent.GetChildNodeCount();
					index = 0;
					break;
				}
			}
			while (parent != null) {
				// first locate first (visible) child
				for (int i = index; i < count; i++) {
					Node result = parent.GetChildNode(i);
					switch (isVisible(result)) {
					case NodeFilterResult.FILTER_ACCEPT:
						referenceNode = result;
						currentNode = referenceNode;
						return currentNode;
					case NodeFilterResult.FILTER_REJECT:
						// ignore children of this node as well, proceed with next child
						break;
					case NodeFilterResult.FILTER_SKIP:
						// this node is not shown, but its children might
						parent = result;
						count = parent.GetChildNodeCount();
						// continue this loop counting from 0 with new parent
						i = -1;
						continue;
					}
				}
				if ((parent == rootNode) || (parent.ParentNode == null)) {
					// no more nodes
					parent = null;
				}
				else {
					// apparently no visible child found, try next sibling of the parent
					index = parent.GetChildNodeIndex() + 1;
					parent = parent.ParentNode;
					count = parent.GetChildNodeCount();
					for (int i = index; i < count; i++) {
						Node result = parent.GetChildNode(i);
						switch (isVisible(result)) {
						case NodeFilterResult.FILTER_ACCEPT:
							referenceNode = result;
							currentNode = referenceNode;
							return currentNode;
						case NodeFilterResult.FILTER_REJECT:
							// ignore children of this node as well, proceed with next sibling
							break;
						case NodeFilterResult.FILTER_SKIP:
							// this node is not shown, but its children might
							parent = result;
							count = parent.GetChildNodeCount();
							index = 0;
							// break this for loop to proceed with the locate first (visible) child loop
							i = count;
							break;
						}
					}
				}
			}
			currentNode = null;
			return currentNode;
		}

		/// Returns the previous node in the set and moves the position of the NodeIterator backwards in the set.
		/// @return The previous Node in the set being iterated over, or null if there are no more members in that set.
		/// @exception InvalidOperationException if this method is called after the detach method was invoked.
		public Node previousNode() {
			if (this.rootNode == null) {
				throw new InvalidOperationException("NodeIterator has no root node");
			}
			if (referenceNode == null) {
				// should never happen
				referenceNode = rootNode;
			}
			// determine 'currentNode'
			currentNode = referenceNode;
			if (MovingForward) {
				// change of direction: return the referenceNode (if visible)
				MovingForward = false;
				switch (isVisible(currentNode)) {
				case NodeFilterResult.FILTER_ACCEPT:
					referenceNode = currentNode;
					return currentNode;
				case NodeFilterResult.FILTER_REJECT:
				case NodeFilterResult.FILTER_SKIP:
					// proceed with previous sibling of referenceNode
					break;
				}
			}
			// locate the previous visible node
			while (currentNode != null) {
				// find (last child of) previous sibling
				if ((currentNode == rootNode) || (currentNode.ParentNode == null)) {
					// no more nodes
					currentNode = null;
				}
				else {
					// get previous sibling of the currentNode
					int index = currentNode.GetChildNodeIndex() - 1;
					currentNode = currentNode.ParentNode;
					if (index < 0) {
						// no previous sibling of the 'previous' current node: check the node itself
						switch (isVisible(currentNode)) {
						case NodeFilterResult.FILTER_ACCEPT:
							referenceNode = currentNode;
							return currentNode;
						case NodeFilterResult.FILTER_REJECT:
						case NodeFilterResult.FILTER_SKIP:
							// proceed with previous sibling of currentNode
							continue;
						}
					}
					while (index >= 0) {
						// there is a previous sibling
						currentNode = currentNode.GetChildNode(index);
						// determine visibility of the (children of the) sibling
						switch (isVisible(currentNode)) {
						case NodeFilterResult.FILTER_REJECT:
							// this node nor its children are shown, proceed with the previous sibling
							index = -1;
							break;
						case NodeFilterResult.FILTER_ACCEPT:
							index = currentNode.GetChildNodeCount() - 1;
							if (index < 0) {
								// no children, but node itself is visible: return that
								referenceNode = currentNode;
								return currentNode;
							}
							break;
						case NodeFilterResult.FILTER_SKIP:
							// test the last child of the currentNode
							index = currentNode.GetChildNodeCount() - 1;
							break;
						}
					}
				}
			}
			return currentNode;
		}
	}


	/// A TreeWalker is used to navigate a node tree using the view defined by WhatToShow
	/// and an optional filter.
	///
	/// This class has the interface and behavior of a W3 Document Object Model TreeWalker.
	/// A TreeWalker is positioned on the first (root) node at construction.
	public class TreeWalker : acn.ddl.ITreeWalker {
		/// The root node of the tree
		private Node _rootNode = null;
		/// The current node of the TreeWalker.
		/// @note This node might be hidden by the filter or even outside of the root node tree
		private Node _currentNode = null;
		private INodeFilter _filter = null;

		/// Initializing constructor
		/// @exception System.NotSupportedException on setting root to null
		public TreeWalker(Node root, INodeFilter filter = null) {
			this._rootNode = root;
			this._filter = filter;
			this.currentNode = root;
		}

		/// The node at which the TreeWalker is currently positioned.
		/// Alterations to the node tree may cause the current node to no longer be accepted by the
		/// TreeWalker's associated filter. currentNode may also be explicitly set to any node, whether
		/// or not it is within the subtree specified by the root node or would be accepted by the filter
		/// and whatToShow flags. Further traversal occurs relative to currentNode even if it is not part
		/// of the current view, by applying the filters in the requested direction;
		/// if no traversal is possible, currentNode is not changed.
		/// @exception System.NotSupportedException on setting currentNode to null
		public Node currentNode {
			get { return _currentNode; }
			set {
				if (value == null) {
					throw new System.NotSupportedException("currentNode cannot be null");
				}
				_currentNode = value;
			}
		}

		/// The filter used to hide nodes from the view.
		public INodeFilter filter { get { return _filter; } }

		/// The root node of the TreeWalker, as specified when it was created.
		public Node root { get { return _rootNode; } }

		/// Check is the specified node is visible in the view of the TreeWalker
		/// @param node the node to evaluate
		/// @return the result of the filter
		private NodeFilterResult isVisible(Node node) {
			NodeFilterResult result = NodeFilterResult.FILTER_ACCEPT;
			if (node == null) {
				result = NodeFilterResult.FILTER_REJECT;
			}
			else if (filter != null) {
				// check the filter
				result = filter.acceptNode(node);
			}
			return result;
		}

		/// Moves the TreeWalker to the first visible child of the current node, and returns the new node.
		/// If the current node has no visible children, returns null, and retains the current node.
		/// @return The new node, or null if the current node has no visible children in the TreeWalker's logical view.
		public Node firstChild() {
			int count = currentNode.GetChildNodeCount();
			for (int i = 0; i < count; i++) {
				Node result = currentNode.GetChildNode(i);
				if (isVisible(result) == NodeFilterResult.FILTER_ACCEPT) {
					currentNode = result;
					return result;
				}
			}
			return null;
		}

		/// Moves the TreeWalker to the last visible child of the current node, and returns the new node.
		/// If the current node has no visible children, returns null, and retains the current node.
		/// @return The new node, or null if the current node has no children in the TreeWalker's logical view.
		public Node lastChild() {
			int count = currentNode.GetChildNodeCount();
			for (int i = count - 1; i >= count; i--) {
				Node result = currentNode.GetChildNode(i);
				if (isVisible(result) == NodeFilterResult.FILTER_ACCEPT) {
					currentNode = result;
					return result;
				}
			}
			return null;
		}
		
		/// Moves the TreeWalker to the next visible node in document order relative to the current node, and returns the new node.
		/// If the current node has no next node, or if the search for nextNode attempts to step upward from the TreeWalker's root node,
		/// returns null, and retains the current node.
		/// @return The new node, or null if the current node has no next node in the TreeWalker's logical view.
		public Node nextNode() {
			Node parent = currentNode;
			int count = parent.GetChildNodeCount();
			int index = 0;
			while (parent != null) {
				// first locate first (visible) child
				for (int i = index; i < count; i++) {
					Node result = parent.GetChildNode(i);
					switch (isVisible(result)) {
					case NodeFilterResult.FILTER_ACCEPT:
						currentNode = result;
						return result;
					case NodeFilterResult.FILTER_REJECT:
						// ignore children of this node as well, proceed with next child
						break;
					case NodeFilterResult.FILTER_SKIP:
						// this node is not shown, but its children might
						parent = result;
						count = parent.GetChildNodeCount();
						// continue this loop counting from 0 with new parent
						i = -1;
						continue;
					}
				}
				if ((parent == root) || (parent.ParentNode == null)) {
					// no more nodes
					parent = null;
				}
				else {
					// apparently no visible child found, try next sibling of the parent
					index = parent.GetChildNodeIndex() + 1;
					parent = parent.ParentNode;
					count = parent.GetChildNodeCount();
					for (int i = index; i < count; i++) {
						Node result = parent.GetChildNode(i);
						switch (isVisible(result)) {
						case NodeFilterResult.FILTER_ACCEPT:
							currentNode = result;
							return result;
						case NodeFilterResult.FILTER_REJECT:
							// ignore children of this node as well, proceed with next sibling
							break;
						case NodeFilterResult.FILTER_SKIP:
							// this node is not shown, but its children might
							parent = result;
							count = parent.GetChildNodeCount();
							index = 0;
							// break this for loop to proceed with the locate first (visible) child loop
							i = count;
							break;
						}
					}
				}
			}
			return null;
		}
		
		/// Moves the TreeWalker to the next sibling of the current node, and returns the new node.
		/// If the current node has no visible next sibling, returns null, and retains the current node.
		/// @return The new node, or null if the current node has no next sibling. in the TreeWalker's logical view.
		public Node nextSibling() {
			Node parent = (currentNode == root ? null : currentNode.ParentNode);
			if (parent != null) {
				int count = parent.GetChildNodeCount();
				for (int i = currentNode.GetChildNodeIndex() + 1; i < count; i++) {
					// locate next visible sibling
					Node result = parent.GetChildNode(i);
					if (isVisible(result) == NodeFilterResult.FILTER_ACCEPT) {
						currentNode = result;
						return result;
					}
				}
			}
			return null;
		}
		
		/// Moves to and returns the closest visible ancestor node of the current node.
		/// If the search for parentNode attempts to step upward from the TreeWalker's root node,
		/// or if it fails to find a visible ancestor node, this method retains the current position and returns null.
		/// @return The new parent node, or null if the current node has no parent in the TreeWalker's logical view.
		public Node parentNode() {
			Node result = (currentNode == root ? null : currentNode.ParentNode);
			while (result != null) {
				if (isVisible(result) == NodeFilterResult.FILTER_ACCEPT) {
					currentNode = result;
					break;
				}
				result = (result == root ? null : result.ParentNode);
			}
			return result;
		}
		
		/// Moves the TreeWalker to the previous sibling of the current node, and returns the new node. If the current node has no visible previous sibling, returns null, and retains the current node.
		/// @return The new node, or null if the current node has no previous sibling. in the TreeWalker's logical view.
		public Node previousSibling() {
			Node parent = (currentNode == root ? null : currentNode.ParentNode);
			if (parent != null) {
				int count = parent.GetChildNodeCount();
				for (int i = currentNode.GetChildNodeIndex() - 1; i >= 0; i--) {
					// locate previous visible sibling
					Node result = parent.GetChildNode(i);
					if (isVisible(result) == NodeFilterResult.FILTER_ACCEPT) {
						currentNode = result;
						return result;
					}
				}
			}
			return null;
		}
		
		/// Moves the TreeWalker to the previous visible node in document order relative to the current node, and returns the new node.
		/// If the current node has no previous node, or if the search for previousNode attempts to step upward from the TreeWalker's root node,
		/// returns null, and retains the current node.
		/// @return The new node, or null if the current node has no previous node in the TreeWalker's logical view.
		public Node previousNode() {
			Node parent = currentNode;
			while (parent != null) {
				// find (last child of) previous sibling
				if ((parent == root) || (parent.ParentNode == null)) {
					// no more nodes
					parent = null;
				}
				else {
					// get previous sibling of the currentNode
					int index = parent.GetChildNodeIndex() - 1;
					parent = parent.ParentNode;
					if (index < 0) {
						// no previous sibling of the 'previous' current node: check the node itself
						switch (isVisible(parent)) {
						case NodeFilterResult.FILTER_ACCEPT:
							currentNode = parent;
							return parent;
						case NodeFilterResult.FILTER_REJECT:
						case NodeFilterResult.FILTER_SKIP:
							// proceed with previous sibling of currentNode
							continue;
						}
					}
					while (index >= 0) {
						// there is a previous sibling
						parent = parent.GetChildNode(index);
						// determine visibility of the (children of the) sibling
						switch (isVisible(parent)) {
						case NodeFilterResult.FILTER_REJECT:
							// this node nor its children are shown, proceed with the previous sibling
							index = -1;
							break;
						case NodeFilterResult.FILTER_ACCEPT:
							index = parent.GetChildNodeCount() - 1;
							if (index < 0) {
								// no children, but node itself is visible: return that
								currentNode = parent;
								return currentNode;
							}
							break;
						case NodeFilterResult.FILTER_SKIP:
							// test the last child of the currentNode
							index = parent.GetChildNodeCount() - 1;
							break;
						}
					}
				}
			}
			return null;
		}
	}

    public partial class UseProtocol : IdentifiedNode {

        /// Default constructor
		public UseProtocol() : base() {
		}
		
        /// Initializing constructor
		/// @param name the name of the protocol
		public UseProtocol(string name) : base() {
			this.nameField = name;
		}
	}

    public partial class UUIDName : IdentifiedNode {

		/// Cached value of the referenced module
		private acn.ddl.Module moduleField;

        /// Default constructor
		public UUIDName() : base() {
		}
		
        /// Initializing constructor
		/// @param uuid the UUID of the UUIDname
		/// @param name the name of the UUIDname
		public UUIDName(string uuid, string name) : base() {
			nameField = name;
			uUIDField = NormalizeUUID(uuid);
		}
		
		///
		/// Get or load the Module that this UUIDName represents.
		public acn.ddl.Module GetReferencedModule() {
			if (moduleField == null) {
				acn.ddl.Document doc = GetDocument();
				if (doc != null) {
					acn.ddl.DocumentList docs = doc.ItemList as acn.ddl.DocumentList;
					if (docs != null) {
						// search for the file by module name
						acn.ddl.Document otherdoc = docs.GetOrLoadDocumentByModuleName(this.name);
						if (otherdoc == null) {
							// search for the file by module UUID
							otherdoc = docs.GetOrLoadDocumentByModuleName(this.UUID);
						}
						if ((otherdoc != null) && (otherdoc.RootNode != null)) {
							moduleField = otherdoc.RootNode.Module;
						}
						if (moduleField == null) {
							// @todo load document from file
							throw new InvalidOperationException(string.Format("cannot find module '{0}' ({1})",this.name,this.UUID));
						}
						// check that the module is actually the referenced module
						if (string.Compare(moduleField.UUID,this.UUID,StringComparison.OrdinalIgnoreCase) != 0) {
							throw new InvalidOperationException(string.Format("file '{0}' contains module '{1}' rather than '{2}'",otherdoc.FileInfo,moduleField.UUID,this.UUID));
						}
					}
				}
			}
			return moduleField;
		}

		/// Test whether the specified string is a UUID.
		/// @note The ACN DDL specification puts length restrictions on the name of a UUIDName to easily
		///   distinguish a name and UUID in 'set' attributes.
		///   We do not apply these length restrictions and distinguish a UUID with a regex.
		public static bool IsUUID(string uuid) {
			return (!string.IsNullOrEmpty(uuid) && (uuid.Length == 36) && (nl.nlsw.Identifiers.UrnUri.UuidRegex.Match(uuid).Success));
		}
		
		/// Test if the specified id is represented by this UUIDName.
		public bool Matches(string id) {
			return (this.name == id || this.UUID == id);
		}
		
		/// Normalize the (possibly) specified UUID string.
		/// If the specified string represents a UUID, it is normalized to lower case representation,
		/// otherwise it is returned unchanged.
		/// @param uuid a string that my represent a UUID
		/// @return the normalized UUID, or the unmodified input if it is not a UUID
		public static string NormalizeUUID(string uuid) {
			return IsUUID(uuid) ? uuid.ToLowerInvariant() : uuid;
		}
    }

	/// Immediate property Value representation.
	/// @todo provide ToString() and FromString() conversions of the object binary data
    public partial class Value : IdentifiedLeafNode {

		/// A regex for matching a value of type ValueDataType.@object.
		/// The hex-encoded octets may be separated for readability with spaces, periods, commas, or hyphens.
		public static readonly Regex ObjectStringRegex = new Regex(@"([0-9a-fA-F]{2}[\s\.,\-]*)*",
			RegexOptions.Compiled|RegexOptions.CultureInvariant);

        /// Default constructor
		public Value() : base() {
		}
		
        /// Initializing constructor
		/// @param type the type of the value
		/// @param value the value of the Value
		public Value(acn.ddl.ValueDataType type, string value = null) : base(null,value) {
			this.type = type;
		}
		
		/// Set the value of the Value.
		/// Verifies and encodes the value based on the ValueDataType.
		/// @param value the new value
		/// @param verify verify the value in stead of setting it
		/// @exception FormatException the data format is invalid for the data type
		/// @exception OverflowException the value does not fit in the data type range
		/// @exception InvalidOperationException the verification of the value fails
		public void SetValue(string value, bool verify = false) {
			// verify the string value based on the value type
			switch (this.type) {
			case acn.ddl.ValueDataType.@uint:
				{
					// what about hex numbers?
					// UInt32 result = Convert.ToUInt32(value);
					break;
				}
			case acn.ddl.ValueDataType.sint:
				{
					int result = Convert.ToInt32(value);
					break;
				}
			case acn.ddl.ValueDataType.@float:
				{
					double result = Convert.ToDouble(value);
					break;
				}
			case acn.ddl.ValueDataType.@string:
				break;
			case acn.ddl.ValueDataType.@object:
				if (!string.IsNullOrEmpty(value) && !ObjectStringRegex.Match(value).Success) {
					throw new FormatException(string.Format("invalid object value format: {0}",value));
				}
				break;
			}
			if (string.CompareOrdinal(this.Value,value) != 0) {
				if (verify) {
					throw new InvalidOperationException(string.Format("immediate '{0}' value is '{1}', expected '{2}'", this.type,this.Value,value));
				}
				this.Value = value;
				NotifyNodeChanged();
			}
		}
		
		/// Best thing to return from a Value is ... its Value.
		public override string ToString() {
			return this.Value;
		}
	}

	///
	/// Base class for writing a Document to string.
	/// Creating an XmlDocument is also supported.
	/// @todo specialize into TextWriter and XmlWriter ?
	///
	public class Writer : nl.nlsw.Items.Writer {
		/// The ISO language code for label text strings.
		private string _LanguageCode = "en";
		
		/// XML Serializer
		private XmlSerializer _Serializer = new System.Xml.Serialization.XmlSerializer(typeof(DDLDocument));

		/// A regex for matching or replacing special characters in an XML Name that are not
		/// allowed in a strict identifier (not containing FULL STOPs).
		/// XML Name special characters are COLON, HYPHEN-MINUS, FULL STOP, and MIDDLE DOT
		public static readonly Regex ReplaceXmlNameSpecialCharsIdentifierRegex = new Regex(@"[:\-\.\u00B7]",
			RegexOptions.Compiled|RegexOptions.CultureInvariant);

		/// A regex for matching or replacing characters in a string that are not
		/// allowed in a strict C identifier (pre-C99, i.e. no Universal Character names yet).
		public static readonly Regex ReplaceInvalidCIdentifierCharsRegex = new Regex(@"[^a-zA-Z0-9_]",
			RegexOptions.Compiled|RegexOptions.CultureInvariant);


		/// A regex for matching or replacing special characters in an XML Name that are not
		/// allowed in an identifier string (that may contain FULL STOPs).
		/// XML Name special characters are COLON, HYPHEN-MINUS, and MIDDLE DOT
		public static readonly Regex ReplaceXmlNameSpecialCharsIdentifierStringRegex = new Regex(@"[:\-\u00B7]",
			RegexOptions.Compiled|RegexOptions.CultureInvariant);

		/// A regex for matching or replacing special characters in an XML Name that are not
		/// allowed in a filename string (that may contain HYPHEN-MINUS, and FULL STOPs).
		/// XML Name special characters are COLON, and MIDDLE DOT
		public static readonly Regex ReplaceXmlNameSpecialCharsFilenameStringRegex = new Regex(@"[:\u00B7]",
			RegexOptions.Compiled|RegexOptions.CultureInvariant);



		/// Convert an XML Name to a strict identifier (a C identifier).
		/// XML Name special characters (COLON, HYPHEN-MINUS, FULL STOP, MIDDLE DOT) are replaced with LOW LINE (underscore)
		public static string ConvertXmlNameToIdentifier(string xmlname) {
			return ReplaceXmlNameSpecialCharsIdentifierRegex.Replace(xmlname,"_");
		}
		
		/// Convert an arbitrary name to a strict C identifier.
		/// First, any invalid character is replaced by an underscore.
		/// Second, underscores at the beginning of the name are removed. (These identifiers are
		///    reserved and must be avoided for normal programming.)
		/// Third, a digit at the beginning is replaced with its name, followed by an underscore
		/// @note The name might be transformed into an identifier that will collide with other
		/// identifiers, e.g. with a C keyword.
		/// @exception InvalidOperationException if the conversion ends up with an empty string
		/// @param name the arbitrary name
		/// @return a strict C identifier
		public static string ConvertToCIdentifier(string name) {
			string result = ReplaceInvalidCIdentifierCharsRegex.Replace(name,"_");
			if (result != null) {
				result = result.TrimStart('_');
			}
			if (!string.IsNullOrEmpty(result)) {
				if (System.Char.IsDigit(result[0])) {
					int digit = (int)Char.GetNumericValue(result[0]);
					if ((digit >= 0) && (digit <= 9)) {
						string[] digitus = {
							"nul_","one_","two_","three_","four_","five_","six_",
							"seven_","eight_","nine_"
						};
						result = string.Concat(digitus[digit],result.Substring(1));
					}
					else {
						throw new InvalidOperationException(string.Format("that 's odd '{0}' IsDigit but not in '0'..'9'",result[0]));
					}
				}
			}
			if (string.IsNullOrEmpty(result)) {
				throw new InvalidOperationException(string.Format("empty identifier after conversion of '{0}'",name));
			}
			return result;
		}
		
// 00A8, 00AA, 00AD, 00AF, 00B2-00B5, 00B7-00BA, 00BC-00BE, 00C0-00D6, 00D8-00F6, 00F8-00FF
// 
// 0100-167F, 1681-180D, 180F-1FFF
// 
// 200B-200D, 202A-202E, 203F-2040, 2054, 2060-206F
// 
// 2070-218F, 2460-24FF, 2776-2793, 2C00-2DFF, 2E80-2FFF
// 
// 3004-3007, 3021-302F, 3031-303F
// 
// 3040-D7FF
// 
// F900-FD3D, FD40-FDCF, FDF0-FE44, FE47-FFFD
// 
// 10000-1FFFD, 20000-2FFFD, 30000-3FFFD, 40000-4FFFD, 50000-5FFFD,
//   60000-6FFFD, 70000-7FFFD, 80000-8FFFD, 90000-9FFFD, A0000-AFFFD,
//   B0000-BFFFD, C0000-CFFFD, D0000-DFFFD, E0000-EFFFD		

		/// Convert an XML Name to an identifier string (that may contain FULL STOPs).
		/// XML Name special characters (COLON, HYPHEN-MINUS, MIDDLE DOT) are replaced with LOW LINE (underscore)
		public static string ConvertXmlNameToIdentifierString(string xmlname) {
			return ReplaceXmlNameSpecialCharsIdentifierStringRegex.Replace(xmlname,"_");
		}

		/// Convert an XML Name to a file name string (that may contain HYPHEN-MINUS, and FULL STOPs).
		/// XML Name special characters (COLON, MIDDLE DOT) are replaced with LOW LINE (underscore)
		public static string ConvertXmlNameToFilenameString(string xmlname) {
			return ReplaceXmlNameSpecialCharsFilenameStringRegex.Replace(xmlname,"_");
		}

		/// Use the module names (as used internally and specified in the UUIDname element)
		/// also for the (external) module file name.
		public bool PrettyFileNames { get; set; }
		
		/// The current device
		public Device CurrentDevice {
			get { return CurrentModule as Device; }
		}

		/// The current DocumentList from which the modules are written
		public acn.ddl.DocumentList CurrentDocumentList {
			get { return (CurrentItem != null) ? CurrentItem.ItemList as acn.ddl.DocumentList : null; }
		}

		/// The current module
		public Module CurrentModule {
			get { return (CurrentDocument != null && CurrentDocument.RootNode != null) ? CurrentDocument.RootNode.Module : null; }
		}

		/// The document being written
		public Document CurrentDocument {
			get { return CurrentItem as Document; }
			set { base.CurrentItem = value; }
		}
		
		/// The ISO language code of the language to use for label texts.
		public string LanguageCode {
			get { return _LanguageCode; }
			set { _LanguageCode = value; }
		}
		
		/// Default constructor
		/// Uses the invariant culture, for persistent storage.
		public Writer() : base(System.Globalization.CultureInfo.InvariantCulture) {
		}

		/// Write the specified Document.
		public void WriteDocument(acn.ddl.Document document) {
			if ((document != null) && (document.RootNode != null)) {
				// quick fix: make sure the html namespace is added, @todo do only if needed
				document.RootNode.XmlNamespaces.Add("html","http://www.w3.org/1999/xhtml");
				_Serializer.Serialize(this,document.RootNode,document.RootNode.XmlNamespaces);
			}
		}
	}
}
