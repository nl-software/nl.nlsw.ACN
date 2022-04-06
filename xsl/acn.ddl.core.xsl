<?xml version="1.0" encoding="UTF-8"?>
<!--
 acn.ddl.core.xsl

 An XSL-T stylesheet with common templates for processing an ACN Device Description Language Module file.

 @date 2021-10-26-17
 @author Ernst van der Pols
-->

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:site="http://ns.nlsw.nl/2010/site"
		xmlns:ddl="http://www.esta.org/acn/namespace/ddl/2008/"
		xmlns:cia="https://www.can-cia.org/CANopen"
		xmlns:krohne="https://www.krohne.com/gdc"
		xmlns:html="http://www.w3.org/1999/xhtml"
 		xmlns:xlink="http://www.w3.org/1999/xlink"
		xmlns:exslt="http://exslt.org/common"
		exclude-result-prefixes="site ddl cia xlink html exslt">

<!-- import utilities template -->
<xsl:import href="site.util.xsl"/>


<xsl:param name="source" select="string('00000000-0000-0000-0000-000000000000.xml')"/>
<!-- $base is the base URI of the xml document (at target location) -->
<xsl:param name="base" select="''" />
<!-- file name extension of target (source) files -->
<xsl:param name="filename-extension" select="'.ddl.xml'" />
<!-- set these paths relative to the target location -->
<xsl:param name="project-path" select="'../'" />
<xsl:param name="ddl-path" select="concat($project-path,'ddl/')" />
<xsl:param name="target-path" select="concat($project-path,'ddl/')" />
<xsl:param name="res" select="concat($project-path,'res/')" />
<xsl:param name="style" select="concat($project-path,'style/')" />
<xsl:param name="images" select="concat($project-path,'data/files/')" />
<xsl:param name="language" select="'en'" />
<xsl:param name="filename-mode" select="'UUIDname'" /><!-- filename is 'UUIDname' or 'UUID' -->

<xsl:param name="device-common-root" select="''"/>
<xsl:param name="device-common-bset" select="concat($device-common-root,'acn.dms.bset')"/>

<xsl:variable name="root" select="/ddl:DDL"/>
<xsl:variable name="title" select="/ddl:DDL/*[1]/ddl:label"/>

<xsl:variable name="ns-ddl" select="'http://www.esta.org/acn/namespace/ddl/2008/'"/>

<!-- === common module element referencing === -->

<xsl:template match="*" mode="link-in-list">
	<xsl:if test="position() &gt; 1"><xsl:text>, </xsl:text></xsl:if>
	<xsl:apply-templates select="." mode="link"/>
</xsl:template>

<xsl:template match="*" mode="full-node-name">
	<xsl:variable name="parent" select=".."/>
	<!--xsl:if test=".."><xsl:apply-templates select=".." mode="full-node-name"/><xsl:value-of select="'.'"/></xsl:if-->
	<xsl:value-of select="concat(count(ancestor-or-self::node()),' nodes before ',name())"/>
	<xsl:value-of select="concat(count($parent/ancestor-or-self::node),' nodes before ',$parent/@xml:id)"/>
</xsl:template>

<!-- === identity copy template for constructing an expanded object tree (arrays are expanded) === -->

<xsl:template match="@*|node()" mode="copy-properties">
	<xsl:param name="indices"/>
	<xsl:param name="parameters"/>
	<xsl:copy>
		<xsl:apply-templates select="@*|node()" mode="copy-properties">
			<xsl:with-param name="indices" select="$indices"/>
			<xsl:with-param name="parameters" select="$parameters"/>
		</xsl:apply-templates>
	</xsl:copy>
</xsl:template>

<!-- === identity copy template for constructing an enhanced object tree (addresses are calculated) === -->

<xsl:template match="@*|node()" mode="copy-update-address">
	<xsl:copy>
		<xsl:apply-templates select="@*|node()" mode="copy-update-address"/>
	</xsl:copy>
</xsl:template>

<!-- === debug template for showing a node tree (e.g. a RTF) === -->

<xsl:template match="*" mode="full-node-tree">
	<xsl:param name="indent" select="'  '"/>
	<xsl:variable name="parent" select=".."/>
	<!--xsl:value-of select="concat($indent, namespace-uri(.),':',local-name(.),' ',name(),' ')"/-->
	<xsl:value-of select="concat($indent,name(),'')"/>
	<xsl:for-each select="@*"><xsl:value-of select="concat(' @',name(),'=',.)"/></xsl:for-each>
	<xsl:if test="*">
		<xsl:value-of select="concat(' =','[&#xA;')"/>
		<xsl:apply-templates select="*" mode="full-node-tree">
			<xsl:with-param name="indent" select="concat($indent,'  ')"/>
		</xsl:apply-templates>
		<xsl:value-of select="concat($indent,']')"/>
	</xsl:if>
	<xsl:if test="not(*) and text()"><xsl:value-of select="concat(' = &quot;',text(),'&quot;')"/></xsl:if>
	<xsl:value-of select="'&#xA;'"/>
</xsl:template>

<!-- === ddl:DDL === -->

<xsl:template match="ddl:DDL">
  	<xsl:apply-templates select="ddl:behaviorset | ddl:device | ddl:languageset"/>
</xsl:template>

<!-- === ddl module (behaviorset, device, languageset) identifier === -->

<xsl:template match="ddl:behaviorset | ddl:device | ddl:languageset" mode="id">
	<xsl:choose><xsl:when test="@xml:id"><xsl:value-of select="@xml:id"/></xsl:when>
	<xsl:otherwise><xsl:value-of select="concat('module-',@UUID)"/></xsl:otherwise></xsl:choose>
</xsl:template>

<xsl:template match="ddl:behaviorset | ddl:device | ddl:languageset | ddl:property | ddl:includedev" mode="title">
	<xsl:choose><xsl:when test="ddl:label"><xsl:apply-templates select="ddl:label" mode="text"/></xsl:when>
	<xsl:otherwise><xsl:apply-templates select="." mode="id"/></xsl:otherwise></xsl:choose>
</xsl:template>

<!-- === ddl:alternatefor === -->

<xsl:template match="ddl:alternatefor" mode="link">
	<xsl:variable name="url"><xsl:apply-templates select="@UUID" mode="url"/></xsl:variable>
	<a href="{$url}" title="{$url}"><xsl:value-of select="@UUID"/></a>
</xsl:template>


<!-- === ddl:behavior === -->

<xsl:template match="ddl:behavior|ddl:refines" mode="document-url">
	<xsl:apply-templates select="@set" mode="document-url"/>
</xsl:template>

<xsl:template match="ddl:behavior|ddl:refines" mode="is">
	<xsl:param name="name"/>
	<xsl:param name="set" select="'acnbase.bset'"/>
	<xsl:variable name="result">
		<xsl:choose>
			<xsl:when test="(@name=$name) and (@set=$set)"><xsl:value-of select="'true'"/></xsl:when>
			<xsl:otherwise>
				<xsl:variable name="bname" select="@name"/>
				<xsl:variable name="url"><xsl:apply-templates select="." mode="document-url"/></xsl:variable>
				<xsl:variable name="bset" select="document($url)/ddl:DDL/ddl:behaviorset"/>
				<xsl:variable name="bh" select="$bset/ddl:behaviordef[@name=$bname]"/>
				<xsl:if test="not($bh)">
					<xsl:value-of select="concat('[ ERROR: behaviordef ',@name,' not found in ',@set,' ]')"/>
				</xsl:if>
				<!--xsl:value-of select="concat('/*',$name,'*/')"/-->
				<xsl:apply-templates select="$bh/ddl:refines[1]" mode="is">
					<xsl:with-param name="name" select="$name"/>
					<xsl:with-param name="set" select="$set"/>
				</xsl:apply-templates>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:choose>
		<xsl:when test="$result='true'"><xsl:value-of select="$result"/></xsl:when>
		<xsl:when test="following-sibling::ddl:behavior | following-sibling::ddl:refines">
			<xsl:apply-templates select="following-sibling::ddl:behavior[1] | following-sibling::ddl:refines[1]" mode="is">
				<xsl:with-param name="name" select="$name"/>
				<xsl:with-param name="set" select="$set"/>
			</xsl:apply-templates>
		</xsl:when>
	</xsl:choose>
</xsl:template>


<xsl:template match="ddl:behavior" mode="link">
	<xsl:variable name="url"><xsl:apply-templates select="@set" mode="url"/></xsl:variable>
	<a href="{$url}#{@name}" title="{$url}#{@name}"><xsl:value-of select="concat('',@name)"/></a>
</xsl:template>

<xsl:template match="ddl:behavior|ddl:refines" mode="property-flags">
	<xsl:param name="flags" select="''"/>
	<xsl:variable name="new-flags">
		<xsl:choose>
			<xsl:when test="@name='persistent' and @set='acnbase.bset'"><xsl:value-of select="'pfPersistent'"/></xsl:when>
			<xsl:when test="@name='volatile' and @set='acnbase.bset'"><xsl:value-of select="'pfVolatile'"/></xsl:when>
			<xsl:when test="@name='constant' and @set='acnbase.bset'"><xsl:value-of select="'pfConstant'"/></xsl:when>
			<xsl:when test="starts-with(@name,'warning') and @set=$device-common-bset"><xsl:value-of select="'pfWarning'"/></xsl:when>
			<xsl:when test="starts-with(@name,'alarm') and @set=$device-common-bset"><xsl:value-of select="'pfAlarm'"/></xsl:when>
			<xsl:when test="@name='fault.critical' and @set=$device-common-bset"><xsl:value-of select="'pfCriticalFault'"/></xsl:when>
			<xsl:when test="@name='fault.persistent' and @set=$device-common-bset"><xsl:value-of select="'pfPersistentFault'"/></xsl:when>
			<xsl:when test="starts-with(@name,'fault') and @set=$device-common-bset"><xsl:value-of select="'pfFault'"/></xsl:when>
			<xsl:when test="starts-with(@name,'user.') and @set=$device-common-bset">
        <!-- flag the user access rights -->
        <xsl:value-of select="concat('pf',substring-after(@name,'user.'))"/>
      </xsl:when>
      
			<xsl:otherwise>
				<xsl:variable name="name" select="@name"/>
				<xsl:variable name="url"><xsl:apply-templates select="." mode="document-url"/></xsl:variable>
				<xsl:variable name="bset" select="document($url)/ddl:DDL/ddl:behaviorset"/>
				<xsl:variable name="bh" select="$bset/ddl:behaviordef[@name=$name]"/>
				<xsl:if test="not($bh)">
					<xsl:value-of select="concat('&#x26A0;[ ERROR: behaviordef ',@name,' not found in ',@set,' ]&#x26D4;')"/>
				</xsl:if>
				<xsl:apply-templates select="$bh/ddl:refines[1]" mode="property-flags"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:variable name="combined-flags">
		<xsl:choose>
			<xsl:when test="contains($flags,$new-flags)"><xsl:value-of select="$flags"/></xsl:when>
			<xsl:when test="(string($flags)!='') and (string($new-flags)!='')"><xsl:value-of select="concat($flags,'|',$new-flags)"/></xsl:when>
			<xsl:otherwise><xsl:value-of select="concat($flags,$new-flags)"/></xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:choose>
		<xsl:when test="following-sibling::ddl:behavior | following-sibling::ddl:refines">
			<xsl:apply-templates select="following-sibling::ddl:behavior[1] | following-sibling::ddl:refines[1]" mode="property-flags">
				<xsl:with-param name="flags" select="$combined-flags"/>
			</xsl:apply-templates>
		</xsl:when>
		<xsl:otherwise><xsl:value-of select="$combined-flags"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:behavior|ddl:refines" mode="property-type">
	<xsl:variable name="name" select="@name"/>
	<xsl:variable name="result">
		<xsl:choose>
			<xsl:when test="starts-with(@name,'type.')">
				<xsl:choose>
					<xsl:when test="@name='type.boolean' and @set=$device-common-bset">tcBoolean</xsl:when>
					<xsl:when test="@name='type.string' and @set='acnbase.bset'">tcString</xsl:when>
					<xsl:when test="@name='type.string' and @set=$device-common-bset">tcString</xsl:when>
					<xsl:when test="starts-with(@name,'type.string') and @set=$device-common-bset">tcString</xsl:when><!-- fallback for other string lengths -->
					<xsl:when test="@name='type.float' and @set='acnbase.bset'">tcFloat32</xsl:when>
					<xsl:when test="@name='type.enum' and @set='acnbase.bset'">
						<!-- get the enumSelector::choice child property defining the enumeration -->
            <xsl:variable name="type-id">
              <xsl:choose>
              <!-- quick hack: propertypointer resolvement for shared enum type based on ".Selector" id -->
              <xsl:when test="../ddl:propertypointer[contains(@xml:id,'.Selector')]">
                <xsl:variable name="ref" select="../ddl:propertypointer[contains(@xml:id,'.Selector')]/@ref"/>
                <xsl:variable name="choice" select="//ddl:property[@xml:id=$ref]/ddl:property[ddl:behavior[@name='choice']]"/>
                <xsl:apply-templates select="$choice" mode="id"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:variable name="choice" select="../ddl:property[ddl:behavior[@name='enumSelector']]/ddl:property[ddl:behavior[@name='choice']]"/>
                <xsl:apply-templates select="$choice" mode="id"/>
              </xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
						<xsl:value-of select="'tcEnum-'"/><xsl:call-template name="c-type-specifier">
							<xsl:with-param name="name" select="$type-id"></xsl:with-param>
						</xsl:call-template>
					</xsl:when>
					<xsl:when test="@name='type.varBinob' and @set='acnbase.bset'">tcObjectRef</xsl:when>
					<xsl:when test="@name='type.float32' and @set=$device-common-bset">tcFloat32</xsl:when>
					<xsl:when test="@name='type.float64' and @set=$device-common-bset">tcFloat64</xsl:when>
					<xsl:when test="@name='type.boolean16' and @set=$device-common-bset">tcUInt16</xsl:when>
					<xsl:when test="@name='type.char' and @set=$device-common-bset">tcChar</xsl:when>
					<xsl:when test="@name='type.int8' and @set=$device-common-bset">tcInt8</xsl:when>
					<xsl:when test="@name='type.int16' and @set=$device-common-bset">tcInt16</xsl:when>
					<xsl:when test="@name='type.int32' and @set=$device-common-bset">tcInt32</xsl:when>
					<xsl:when test="@name='type.int64' and @set=$device-common-bset">tcInt64</xsl:when>
					<xsl:when test="@name='type.uint8' and @set=$device-common-bset">tcUInt8</xsl:when>
					<xsl:when test="@name='type.uint16' and @set=$device-common-bset">tcUInt16</xsl:when>
					<xsl:when test="@name='type.uint32' and @set=$device-common-bset">tcUInt32</xsl:when>
					<xsl:when test="@name='type.uint64' and @set=$device-common-bset">tcUInt64</xsl:when>
					<xsl:otherwise>tcEmpty</xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<xsl:otherwise>
				<xsl:variable name="url"><xsl:apply-templates select="." mode="document-url"/></xsl:variable>
				<xsl:variable name="bset" select="document($url)/ddl:DDL/ddl:behaviorset"/>
				<xsl:variable name="bh" select="$bset/ddl:behaviordef[@name=$name]"/>
				<xsl:if test="not($bh)">
					<xsl:value-of select="concat('ERROR_behaviordef_',@name,'_not_found_in_',@set)"/>
				</xsl:if>
				<!--xsl:value-of select="concat('/*',$name,'*/')"/-->
				<xsl:apply-templates select="$bh/ddl:refines[1]" mode="property-type"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:choose>
		<xsl:when test="$result!=''"><xsl:value-of select="$result"/></xsl:when>
		<xsl:when test="following-sibling::ddl:behavior | following-sibling::ddl:refines">
			<xsl:apply-templates select="following-sibling::ddl:behavior[1] | following-sibling::ddl:refines[1]" mode="property-type"/>
		</xsl:when>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:behavior|ddl:refines" mode="property-unit">
	<xsl:variable name="name" select="@name"/>
	<xsl:variable name="result">
		<xsl:choose>
			<xsl:when test="@set=$device-common-bset">
				<xsl:choose>
					<xsl:when test="@name='angle'">rad</xsl:when>
					<xsl:when test="@name='current'">A</xsl:when>
					<xsl:when test="@name='currentRMS'">A</xsl:when>
					<xsl:when test="@name='voltage'">V</xsl:when>
					<xsl:when test="@name='voltageRMS'">V</xsl:when>
					<xsl:when test="@name='energykWh'">kWh</xsl:when>
					<xsl:when test="@name='temperature'">&#xB0;C</xsl:when>
					<xsl:when test="@name='frequency'">Hz</xsl:when>
					<xsl:when test="@name='frequency.angular'">rad/s</xsl:when>
					<xsl:when test="@name='power'">W</xsl:when>
					<xsl:when test="@name='period'">s</xsl:when>
				</xsl:choose>
			</xsl:when>
			<xsl:otherwise>
				<xsl:variable name="url"><xsl:apply-templates select="." mode="document-url"/></xsl:variable>
				<xsl:variable name="bset" select="document($url)/ddl:DDL/ddl:behaviorset"/>
				<xsl:variable name="bh" select="$bset/ddl:behaviordef[@name=$name]"/>
				<xsl:if test="not($bh)">
					<xsl:value-of select="concat('[ ERROR: behaviordef ',@name,' not found in ',@set,' ]')"/>
				</xsl:if>
				<!--xsl:value-of select="concat('/*',$name,'*/')"/-->
				<xsl:apply-templates select="$bh/ddl:refines[1]" mode="property-unit"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:choose>
		<xsl:when test="$result!=''"><xsl:value-of select="$result"/></xsl:when>
		<xsl:when test="following-sibling::ddl:behavior | following-sibling::ddl:refines">
			<xsl:apply-templates select="following-sibling::ddl:behavior[1] | following-sibling::ddl:refines[1]" mode="property-unit"/>
		</xsl:when>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:behavior" mode="url">
	<xsl:apply-templates select="@set" mode="url"/>
</xsl:template>

<!-- === ddl:behaviordef === -->

<xsl:template match="ddl:behaviordef" mode="id">
	<xsl:choose><xsl:when test="@xml:id"><xsl:value-of select="@xml:id"/></xsl:when>
	<xsl:otherwise><xsl:value-of select="@name"/></xsl:otherwise></xsl:choose>
</xsl:template>

<xsl:template match="ddl:behaviordef" mode="link">
	<xsl:variable name="id"><xsl:apply-templates select="." mode="id"/></xsl:variable>
	<a href="#{$id}"><xsl:value-of select="@name"/></a>
</xsl:template>

<!-- === ddl:behaviorset === -->

<!-- === ddl:device === -->

<xsl:template match="ddl:device" mode="c-type-specifier">
	<xsl:call-template name="c-type-specifier">
		<xsl:with-param name="name"><xsl:apply-templates select="." mode="id"/></xsl:with-param>
	</xsl:call-template>
</xsl:template>

<xsl:template match="ddl:device" mode="cpp-namespace-name">
	<xsl:call-template name="cpp-namespace-name">
		<xsl:with-param name="id"><xsl:apply-templates select="." mode="id"/></xsl:with-param>
	</xsl:call-template>
</xsl:template>

<xsl:template match="ddl:device" mode="comment">
	<xsl:param name="indent" select="''"/>
	<xsl:param name="delimiter"/>
  <xsl:variable name="descr" select="ddl:property[(@valuetype='immediate') and ddl:behavior[@set='acn.dms.bset' and @name='description']]/ddl:value"/>
	<xsl:variable name="title"><xsl:apply-templates select="." mode="title"/></xsl:variable>
	<xsl:call-template name="comment">
		<xsl:with-param name="text">
      <xsl:value-of select="concat('&#xA;',$title,'&#xA;')"/>
      <xsl:if test="$descr"><xsl:value-of select="concat('&#xA;',$descr,'&#xA;')"/></xsl:if>
    </xsl:with-param>
		<xsl:with-param name="indent" select="$indent"/>
		<xsl:with-param name="delimiter" select="$delimiter"/>
	</xsl:call-template>
</xsl:template>

<xsl:template match="ddl:device" mode="hash-code">
	<xsl:call-template name="get-hash">
		<xsl:with-param name="text" select="concat(@xml:id,@UUID,@date,@provider)"/>
	</xsl:call-template>
</xsl:template>

<xsl:template match="ddl:device" mode="file-basename">
	<xsl:variable name="name"><xsl:apply-templates select="." mode="id"/></xsl:variable>
	<xsl:choose>
		<xsl:when test="starts-with($name,$device-common-root)"><xsl:value-of select="substring-after($name, $device-common-root)"/></xsl:when>
		<xsl:otherwise><xsl:value-of select="$name"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:device" mode="name">
	<xsl:apply-templates select="." mode="id"/>
</xsl:template>

<xsl:template match="ddl:device" mode="object.identifier">
	<xsl:value-of select="ddl:property[@valuetype='immediate' and ddl:behavior[@name='object.identifier']]/ddl:value"/>
</xsl:template>

<xsl:template match="ddl:device" mode="properties.with.behavior">
	<xsl:param name="starts-with-name"/>
	<xsl:param name="set" select="'acnbase.bset'"/>
	<xsl:copy-of select=".//ddl:property[ddl:behavior[starts-with(@name,$starts-with-name) and @set=$set]]"/>
</xsl:template>

<xsl:template match="ddl:device" mode="type">
	<xsl:apply-templates select="." mode="id"/>
</xsl:template>

<xsl:template match="ddl:device" mode="url">
	<xsl:variable name="id" select="@xml:id"/>
	<xsl:choose>
		<xsl:when test="ddl:UUIDname[@name=$id]"><xsl:apply-templates select="$id" mode="url"><xsl:with-param name="UUIDnames" select="ddl:UUIDname"/></xsl:apply-templates></xsl:when>
		<xsl:otherwise><xsl:apply-templates select="@UUID" mode="url"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:device" mode="document-url">
	<xsl:variable name="id" select="@xml:id"/>
	<xsl:choose>
		<xsl:when test="ddl:UUIDname[@name=$id]"><xsl:apply-templates select="$id" mode="document-url"><xsl:with-param name="UUIDnames" select="ddl:UUIDname"/></xsl:apply-templates></xsl:when>
		<xsl:otherwise><xsl:apply-templates select="@UUID" mode="document-url"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<!-- ==== ddl:device template for retrieving a result tree fragment with all referenced devices ===== -->

<xsl:template match="ddl:device" mode="copy-devices">
	<xsl:param name="parameters"/>
	<xsl:copy>
		<xsl:apply-templates select="@*|ddl:UUIDname|ddl:label" mode="copy-properties"/>
	</xsl:copy>
	<xsl:apply-templates select="ddl:includedev" mode="copy-devices">
		<xsl:with-param name="parameters" select="$parameters"/>
	</xsl:apply-templates>
</xsl:template>

<xsl:template match="ddl:includedev" mode="copy-devices">
	<xsl:param name="parameters"/>
	<xsl:variable name="url"><xsl:apply-templates select="@UUID" mode="document-url"/></xsl:variable>
	<xsl:variable name="device" select="document($url)/ddl:DDL/ddl:device"/>
	<xsl:apply-templates select="$device" mode="copy-devices">
		<xsl:with-param name="parameters" select="$parameters"/>
	</xsl:apply-templates>
</xsl:template>

<!-- ==== ddl:device: template for retrieving a result tree fragment with all expanded object properties ===== -->

<xsl:template match="ddl:device" mode="copy-properties">
	<xsl:param name="parameters"/>
	<xsl:copy>
		<xsl:apply-templates select="@*|ddl:label" mode="copy-properties"/>
		<xsl:apply-templates select="ddl:property|ddl:includedev" mode="copy-properties">
			<xsl:with-param name="parameters" select="$parameters"/>
		</xsl:apply-templates>
	</xsl:copy>
</xsl:template>

<xsl:template match="ddl:property" mode="copy-properties">
	<xsl:param name="indices" select="'0,'"/>
	<xsl:param name="index" select="number(substring-before($indices,','))"/>
	<xsl:param name="parameters"/>
	<xsl:copy>
		<xsl:if test="@array and (number($index) &lt; number(@array))">
			<!-- add the index as attribute to the result tree -->
			<xsl:attribute name="index"><xsl:value-of select="$index"/></xsl:attribute>
		</xsl:if>
		<xsl:apply-templates select="@*" mode="copy-properties"/>
		<!-- add the url base as attribute -->
		<xsl:attribute name="x-url"><xsl:apply-templates select="." mode="url"/></xsl:attribute>
		<xsl:apply-templates select="*" mode="copy-properties">
			<xsl:with-param name="indices">
				<xsl:if test="@array"><xsl:value-of select="concat($index,',',$indices)"/></xsl:if>
				<xsl:if test="not(@array)"><xsl:value-of select="$indices"/></xsl:if>
			</xsl:with-param>
			<xsl:with-param name="parameters" select="$parameters"/>
		</xsl:apply-templates>
	</xsl:copy>
	<xsl:if test="@array and (($index + 1) &lt; number(@array))">
		<xsl:apply-templates select="." mode="copy-properties">
			<xsl:with-param name="indices" select="$indices"/>
			<xsl:with-param name="index" select="$index + 1"/>
			<xsl:with-param name="parameters" select="$parameters"/>
		</xsl:apply-templates>
	</xsl:if>
</xsl:template>

<xsl:template match="ddl:includedev" mode="copy-properties">
	<xsl:param name="indices" select="'0,'"/>
	<xsl:param name="index" select="number(substring-before($indices,','))"/>
	<xsl:param name="parameters"/>
	<xsl:variable name="url"><xsl:apply-templates select="@UUID" mode="document-url"/></xsl:variable>
	<xsl:variable name="device" select="document($url)/ddl:DDL/ddl:device"/>
	<!-- create a property as container for the device, representing the class object -->
	<xsl:element name="property" namespace="{namespace-uri(.)}">
		<xsl:attribute name="url"><xsl:value-of select="$url"/></xsl:attribute>
		<xsl:if test="@array and (number($index) &lt; number(@array))">
			<!-- add the index as attribute to the result tree -->
			<xsl:attribute name="index"><xsl:value-of select="$index"/></xsl:attribute>
		</xsl:if>
		<xsl:apply-templates select="@xml:id|ddl:label" mode="copy-properties"/>
		<xsl:apply-templates select="ddl:protocol" mode="copy-properties"/>
		<!-- @todo ddl:setparam processing -->
		<xsl:apply-templates select="$device/*" mode="copy-properties">
			<xsl:with-param name="indices">
				<xsl:if test="@array"><xsl:value-of select="concat($index,',',$indices)"/></xsl:if>
				<xsl:if test="not(@array)"><xsl:value-of select="$indices"/></xsl:if>
			</xsl:with-param>
			<xsl:with-param name="parameters" select="$parameters"/>
		</xsl:apply-templates>
	</xsl:element>
	<xsl:if test="@array and (($index + 1) &lt; number(@array))">
		<xsl:apply-templates select="." mode="copy-properties">
			<xsl:with-param name="indices" select="$indices"/>
			<xsl:with-param name="index" select="$index + 1"/>
			<xsl:with-param name="parameters" select="$parameters"/>
		</xsl:apply-templates>
	</xsl:if>
</xsl:template>

<!-- === @date === -->

<xsl:template match="@date">
	<xsl:value-of select="."/>
</xsl:template>

<!-- === ddl:extends === -->

<xsl:template match="ddl:extends" mode="link">
	<xsl:variable name="url"><xsl:apply-templates select="@UUID" mode="url"/></xsl:variable>
	<a href="{$url}" title="{$url}"><xsl:value-of select="@UUID"/></a>
</xsl:template>

<!-- === ddl:hd === -->

<!-- === ddl:label === -->

<xsl:template match="ddl:label" mode="text">
	<xsl:param name="lang" select="$language"/>
	<xsl:param name="key" select="@key"/>
	<xsl:param name="languageset" select="*[false()]"/><!--empty node set-->
	<xsl:variable name="languages" select="$languageset/ddl:language"/>
	<xsl:variable name="language" select="$languageset/ddl:language[starts-with(@lang,$lang)]"/>
	<xsl:choose>
    <xsl:when test="text() != ''"><xsl:value-of select="text()"/></xsl:when>
		<xsl:when test="$language[1]/ddl:string[@key=$key]"><!-- primary language string -->
			<xsl:value-of select="$language[1]/ddl:string[@key=$key]"/>
		</xsl:when>
		<xsl:when test="$language[@altlang]"><!-- alt. language string -->
			<xsl:apply-templates select="." mode="text">
				<xsl:with-param name="lang" select="$language[@altlang][1]/@altlang"/>
				<xsl:with-param name="languageset" select="$languageset"/>
				<xsl:with-param name="key" select="$key"/>
			</xsl:apply-templates>
		</xsl:when>
		<xsl:when test="not($languages) and @set"><!-- get string from language set -->
			<xsl:variable name="url"><xsl:apply-templates select="@set" mode="document-url"/></xsl:variable>
			<xsl:apply-templates select="." mode="text">
				<xsl:with-param name="key" select="$key"/>
				<xsl:with-param name="languageset" select="document($url)/ddl:DDL/ddl:languageset"/>
			</xsl:apply-templates>
		</xsl:when>
		<xsl:otherwise><span class="error"><xsl:value-of select="concat('ERROR: ',$key,' not found in languageset ',@set)"/></span></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<!-- === ddl:language === -->

<xsl:template match="ddl:language" mode="id">
	<xsl:choose><xsl:when test="@xml:id"><xsl:value-of select="@xml:id"/></xsl:when>
	<xsl:otherwise><xsl:value-of select="concat('lang-',@lang)"/></xsl:otherwise></xsl:choose>
</xsl:template>

<xsl:template match="ddl:language" mode="link">
	<xsl:variable name="id"><xsl:apply-templates select="." mode="id"/></xsl:variable>
	<a href="#{$id}"><xsl:value-of select="@lang"/></a>
</xsl:template>

<!-- === ddl:languageset === -->


<!-- === ddl:@address | ddl:@loc === -->

<xsl:template match="@loc | @address" mode="dechex">
	<xsl:value-of select="concat(.,', ')"/><xsl:call-template name="FormatHex"><xsl:with-param name="number" select="number(.)"/></xsl:call-template>
</xsl:template>

<xsl:template match="@loc | @address" mode="hex">
	<xsl:call-template name="FormatHex"><xsl:with-param name="number" select="number(.)"/></xsl:call-template>
</xsl:template>

<!-- === ddl:p === -->


<!-- === ddl:includedev === -->

<xsl:template match="ddl:includedev" mode="type">
	<xsl:variable name="url"><xsl:apply-templates select="@UUID" mode="document-url"/></xsl:variable>
	<xsl:variable name="device" select="document($url)/ddl:DDL/ddl:device"/>
	<xsl:apply-templates select="$device" mode="type"/>
</xsl:template>

<xsl:template match="ddl:includedev" mode="file-basename">
	<xsl:variable name="url"><xsl:apply-templates select="@UUID" mode="document-url"/></xsl:variable>
	<xsl:variable name="device" select="document($url)/ddl:DDL/ddl:device"/>
	<xsl:apply-templates select="$device" mode="file-basename"/>
</xsl:template>

<!-- === ddl:parameter === -->

<!-- === ddl:property === -->

<xsl:template match="ddl:property | ddl:includedev" mode="c-declaration-specifiers">
	<xsl:variable name="type"><xsl:apply-templates select="." mode="c-type-specifier"/></xsl:variable>
	<xsl:value-of select="$type"/>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="c-type-specifier">
	<xsl:call-template name="c-type-specifier">
		<xsl:with-param name="name"><xsl:apply-templates select="." mode="type"/></xsl:with-param>
	</xsl:call-template>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="array">
	<xsl:choose>
		<xsl:when test="@array"><xsl:value-of select="@array"/></xsl:when>
		<xsl:otherwise><xsl:value-of select="1"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="flags">
	<xsl:variable name="result">
		<xsl:apply-templates select="ddl:behavior[1]" mode="property-flags"/>
	</xsl:variable>
	<xsl:choose>
		<xsl:when test="contains($result,'|')"><xsl:value-of select="concat('(PropertyFlags)(',$result,')')"/></xsl:when>
		<xsl:when test="$result!=''"><xsl:value-of select="$result"/></xsl:when>
		<xsl:otherwise><xsl:value-of select="'pfNone'"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:property" mode="has-behavior">
	<xsl:param name="name"/>
	<xsl:param name="set" select="'acnbase.bset'"/>
	<xsl:apply-templates select="ddl:behavior[1]" mode="is">
		<xsl:with-param name="name" select="$name"/>
		<xsl:with-param name="set" select="$set"/>
	</xsl:apply-templates>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="id">
	<xsl:choose>
		<xsl:when test="@xml:id"><xsl:value-of select="@xml:id"/></xsl:when>
		<xsl:when test="ddl:label/@key"><xsl:value-of select="ddl:label/@key"/></xsl:when>
		<xsl:otherwise><xsl:value-of select="concat('prop-',position())"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="c-identifier">
	<xsl:call-template name="c-identifier">
		<xsl:with-param name="id"><xsl:apply-templates select="." mode="id"/></xsl:with-param>
	</xsl:call-template>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="c-declarator">
	<xsl:param name="property-type" select="''"/>
	<xsl:param name="language" select="'c'"/>
	<!-- declarator part: {<pointer>}? -->
	<xsl:choose>
	<xsl:when test="($language='c') and ($property-type = 'tcString')">
		<!-- constant unbounded strings are implemented in C as "char *" -->
		<xsl:variable name="is-constant"><xsl:apply-templates select="." mode="has-behavior">
			<xsl:with-param name="name" select="'constant'"/>
		</xsl:apply-templates></xsl:variable>
		<xsl:variable name="max" select="ddl:property[@valuetype='immediate' and ddl:behavior[(@set='acn.dms.bset') and (@name = 'limitMaxCodeUnits')]]"/>
		<xsl:if test="$is-constant and not($max)"><xsl:value-of select="'* '"/></xsl:if>
	</xsl:when>
	<xsl:when test="$property-type = 'tcObjectRef'"><xsl:value-of select="'* '"/></xsl:when>
	</xsl:choose>
	
	<!-- direct-declarator part -->
	<xsl:apply-templates select="." mode="c-direct-declarator">
		<xsl:with-param name="property-type" select="$property-type"/>
		<xsl:with-param name="language" select="$language"/>
	</xsl:apply-templates>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="c-direct-declarator">
	<xsl:param name="property-type" select="''"/>
	<xsl:param name="language" select="'c'"/>
	<!-- simple declarator part: identifier -->
	<xsl:apply-templates select="." mode="c-identifier"/>
	<!-- optionally followed by array declarator of the data type (typ. for char[]) -->
	<xsl:if test="($language='c') and ($property-type = 'tcString')">
		<xsl:variable name="type-array">
			<xsl:variable name="max" select="ddl:property[@valuetype='immediate' and ddl:behavior[(@set='acn.dms.bset') and (@name = 'limitMaxCodeUnits')]]"/>
			<xsl:value-of select="number($max/ddl:value) + 1"/>
		</xsl:variable>
		<xsl:if test="number($type-array) &gt; 1"><xsl:value-of select="concat('[',$type-array,']')"/></xsl:if>
	</xsl:if>
	<!-- optionally followed by array declarator of the property -->
	<xsl:if test="@array"><xsl:value-of select="concat('[',@array,']')"/></xsl:if>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="comment">
	<xsl:param name="indent" select="''"/>
	<xsl:param name="delimiter"/>
  <xsl:variable name="descr" select="ddl:property[(@valuetype='immediate') and ddl:behavior[@set='acn.dms.bset' and @name='description']]/ddl:value"/>
	<xsl:call-template name="comment">
		<xsl:with-param name="text">
      <xsl:apply-templates select="." mode="title"/>
      <xsl:if test="$descr"><xsl:value-of select="concat('&#xA;&#xA;',$descr)"/></xsl:if>
    </xsl:with-param>
		<xsl:with-param name="indent" select="$indent"/>
    <xsl:with-param name="delimiter" select="$delimiter"/>
	</xsl:call-template>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="link">
	<xsl:variable name="url"><xsl:apply-templates select="." mode="url"/></xsl:variable>
	<xsl:variable name="name"><xsl:apply-templates select="." mode="name"/></xsl:variable>
	<xsl:variable name="full-name"><xsl:apply-templates select="." mode="full-name"/></xsl:variable>
	<a href="{$url}" title="{$full-name}"><xsl:value-of select="$name"/></a>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="deep-link">
	<xsl:variable name="url"><xsl:apply-templates select="." mode="url"/></xsl:variable>
	<xsl:variable name="name"><xsl:apply-templates select="." mode="name"/></xsl:variable>
	<xsl:variable name="full-name"><xsl:apply-templates select="." mode="full-name"/></xsl:variable>
	<xsl:variable name="display-full-name">
		<xsl:choose>
			<xsl:when test="starts-with($full-name,$device-common-root)"><xsl:value-of select="substring-after($full-name,$device-common-root)"/></xsl:when>
			<xsl:otherwise><xsl:value-of select="$full-name"/></xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:if test="string($display-full-name) != string($name)">
		<xsl:value-of select="substring-before($display-full-name,$name)"/>
	</xsl:if><a href="{$url}" title="{$full-name}"><xsl:value-of select="$name"/></a>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="name">
	<xsl:apply-templates select="." mode="id"/>
	<xsl:choose>
		<xsl:when test="@index"><xsl:value-of select="concat('[',@index,']')"/></xsl:when>
		<xsl:when test="@array &gt; 1"><xsl:value-of select="concat('[',@array,']')"/></xsl:when>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="full-name">
	<xsl:choose>
		<xsl:when test="parent::ddl:property"><xsl:apply-templates select="parent::ddl:property[1]" mode="full-name"/><xsl:value-of select="'.'"/></xsl:when>
		<xsl:when test="parent::ddl:includedev"><xsl:apply-templates select="parent::ddl:includedev" mode="full-name"/><xsl:value-of select="'.'"/></xsl:when>
		<xsl:when test="parent::ddl:device"><xsl:apply-templates select="parent::ddl:device" mode="name"/><xsl:value-of select="'.'"/></xsl:when>
	</xsl:choose>
	<xsl:apply-templates select="." mode="name"/>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="full-variable-name">
	<xsl:choose>
		<xsl:when test="parent::ddl:property"><xsl:apply-templates select="parent::ddl:property" mode="full-variable-name"/><xsl:value-of select="'.'"/></xsl:when>
		<xsl:when test="parent::ddl:includedev"><xsl:apply-templates select="parent::ddl:includedev" mode="full-variable-name"/><xsl:value-of select="'.'"/></xsl:when>
		<xsl:when test="parent::ddl:device[ddl:property[@valuetype='immediate' and ddl:behavior[@name='object.identifier']]]"><xsl:apply-templates select="parent::ddl:device" mode="object.identifier"/><xsl:value-of select="'.'"/></xsl:when>
		<xsl:when test="parent::ddl:device">
			<xsl:call-template name="c-identifier">
				<xsl:with-param name="id"><xsl:apply-templates select="ancestor::ddl:device" mode="name"/></xsl:with-param>
			</xsl:call-template>
			<xsl:value-of select="'.'"/>
		</xsl:when>
	</xsl:choose>
	<xsl:call-template name="c-identifier">
		<xsl:with-param name="id"><xsl:apply-templates select="." mode="name"/></xsl:with-param>
	</xsl:call-template>
</xsl:template>

<xsl:template match="ddl:property" mode="property-number-name">
	<xsl:variable name="full-name"><xsl:apply-templates select="." mode="full-name"/></xsl:variable>
	<xsl:variable name="name">
		<xsl:choose>
			<xsl:when test="starts-with($full-name,$device-common-root)"><xsl:value-of select="substring-after($full-name,$device-common-root)"/></xsl:when>
			<xsl:otherwise><xsl:value-of select="$full-name"/></xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:value-of select="concat('pn',translate($name,'.-[]','___'))"/>
</xsl:template>

<xsl:template match="ddl:property" mode="type">
	<xsl:apply-templates select="ddl:behavior[1]" mode="property-type"/>
</xsl:template>

<xsl:template match="ddl:property" mode="unit">
	<xsl:apply-templates select="ddl:behavior[1]" mode="property-unit"/>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="variable-name">
	<xsl:variable name="name"><xsl:apply-templates select="." mode="full-variable-name"/></xsl:variable>
	<xsl:variable name="root">
		<xsl:call-template name="c-identifier"><xsl:with-param name="id" select="$device-common-root"/></xsl:call-template>
	</xsl:variable>
	<xsl:choose>
		<xsl:when test="starts-with($name,$root)"><xsl:value-of select="substring-after($name,$root)"/></xsl:when>
		<xsl:otherwise><xsl:value-of select="$name"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="JSON">
	<xsl:param name="indent" select="'  '"/>
	<xsl:param name="parameters"/>
	<xsl:if test="ddl:protocol[starts-with(@name,'DMS')]">
		<xsl:value-of select="concat($indent,'&quot;',@xml:id,'&quot;: ')"/>
		<xsl:if test="@array"><xsl:value-of select="'['"/></xsl:if>
		<xsl:apply-templates select="." mode="JSON.value">
			<xsl:with-param name="indent" select="$indent"/>
			<xsl:with-param name="parameters" select="$parameters"/>
		</xsl:apply-templates>
		<xsl:if test="@array"><xsl:value-of select="']'"/></xsl:if>
		<xsl:if test="(position() &lt; last())"><xsl:text>,</xsl:text><xsl:value-of select="'&#xA;'"/></xsl:if>
	</xsl:if>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="JSON.value">
	<xsl:param name="indent" select="'  '"/>
	<xsl:param name="index" select="number(0)"/>
	<xsl:param name="parameters"/>
	<xsl:choose>
		<xsl:when test="@UUID"><!--ddl:includedev-->
			<xsl:variable name="url"><xsl:apply-templates select="@UUID" mode="document-url"/></xsl:variable>
			<xsl:variable name="device" select="document($url)/ddl:DDL/ddl:device"/>
			<xsl:value-of select="concat('{','&#xA;')"/>
			<xsl:if test="$device/ddl:useprotocol[starts-with(@name,'DMS')]">
				<xsl:apply-templates select="$device/ddl:property|$device/ddl:includedev" mode="JSON">
					<xsl:with-param name="indent" select="concat($indent,'  ')"/>
					<xsl:with-param name="parameters" select="ddl:setparam"/>
				</xsl:apply-templates>
			</xsl:if>
			<xsl:value-of select="concat('&#xA;',$indent,'}')"/>
		</xsl:when>
		<xsl:when test="@valuetype='NULL'"><xsl:value-of select="'null'"/></xsl:when>
		<xsl:when test="count(ddl:value) = 1">
			<xsl:apply-templates select="ddl:value" mode="JSON.value">
				<xsl:with-param name="parameters" select="$parameters"/>
			</xsl:apply-templates>
		</xsl:when>
		<xsl:when test="@array and ddl:value">
			<xsl:apply-templates select="ddl:value[position() = ($index + 1)]" mode="JSON.value">
				<xsl:with-param name="parameters" select="$parameters"/>
			</xsl:apply-templates>
		</xsl:when>
		<xsl:when test="./ddl:property[(@valuetype='immediate') and ddl:behavior[@name='initializer']]">
			<xsl:apply-templates select="./ddl:property[(@valuetype='immediate') and ddl:behavior[@name='initializer']]" mode="JSON.value">
				<xsl:with-param name="parameters" select="$parameters"/>
			</xsl:apply-templates>
		</xsl:when>
		<xsl:when test="@valuetype='network'"><i>&quot;<xsl:apply-templates select="." mode="name"/>&quot;</i></xsl:when>
		<xsl:when test="@valuetype='immediate'">
			<xsl:apply-templates select="ddl:value" mode="JSON.value">
				<xsl:with-param name="parameters" select="$parameters"/>
			</xsl:apply-templates>
		</xsl:when>
		<xsl:when test="@valuetype='implied'"><i><xsl:value-of select="concat('&quot;','implied','&quot;')"/></i></xsl:when>
		<xsl:otherwise><xsl:value-of select="concat('&quot;','&quot;')"/></xsl:otherwise>
	</xsl:choose>
	<xsl:if test="@array and (($index + 1) &lt; number(@array))"><xsl:value-of select="', '"/>
		<xsl:apply-templates select="." mode="JSON.value">
			<xsl:with-param name="indent" select="$indent"/>
			<xsl:with-param name="index" select="$index + 1"/>
				<xsl:with-param name="parameters" select="$parameters"/>
		</xsl:apply-templates>
	</xsl:if>
</xsl:template>

<xsl:template match="ddl:property | ddl:includedev" mode="url">
	<xsl:choose>
		<xsl:when test="@x-url"><xsl:value-of select="@x-url"/></xsl:when>
		<xsl:otherwise>
			<xsl:variable name="id"><xsl:apply-templates select="." mode="id"/></xsl:variable>
			<xsl:variable name="url">
				<xsl:choose>
					<xsl:when test="ancestor-or-self::*/@url"><xsl:value-of select="ancestor-or-self::*/@url"/></xsl:when>
					<xsl:otherwise><xsl:apply-templates select="ancestor::ddl:device" mode="url"/></xsl:otherwise>
				</xsl:choose>
			</xsl:variable>
			<xsl:value-of select="concat($url,'#',$id)"/>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<!-- === ddl:propertypointer === -->

<xsl:template match="ddl:propertypointer" mode="link">
	<xsl:variable name="url"><xsl:apply-templates select="@set" mode="url"/></xsl:variable>
	<a href="{$url}#{@ref}" title="{$url}#{@ref}"><xsl:value-of select="concat('',@ref)"/></a>
</xsl:template>


<!-- === ddl:propref_DMP === -->

<xsl:template match="ddl:propref_DMP">
	<xsl:if test="string(../@name) != 'ESTA.DMP'"><span class="error">protocol should be ESTA.DMP</span></xsl:if>
	<xsl:variable name="abs">
		<xsl:choose><xsl:when test="@abs='true'"><xsl:value-of select="'absolute'"/></xsl:when><xsl:otherwise><xsl:value-of select="'relative'"/></xsl:otherwise></xsl:choose>
	</xsl:variable>
	<xsl:variable name="access"><xsl:apply-templates select="." mode="access"/></xsl:variable>
	<xsl:variable name="loc"><xsl:apply-templates select="@loc" mode="dechex"/></xsl:variable>
	<xsl:variable name="size"><xsl:apply-templates select="." mode="size"/></xsl:variable>
	<xsl:value-of select="concat(': address=',$loc,' (',$abs,'); access=',$access,'; size=',$size,'.')"/>
</xsl:template>

<xsl:template match="ddl:propref_DMP" mode="DMP-tr">
	<xsl:variable name="property" select="(ancestor::ddl:property|ancestor::ddl:includedev)[1]"/>
	<!-- todo: recursively include properties of child device -->
	<tr><td align="right"><xsl:apply-templates select="@loc" mode="dechex"/></td><td><xsl:apply-templates select="$property" mode="link"/></td>
	<td><xsl:apply-templates select="$property/ddl:behavior"/></td>
	<td><xsl:apply-templates select="." mode="access"/></td><td align="right"><xsl:apply-templates select="." mode="size"/></td></tr>
</xsl:template>

<xsl:template match="ddl:propref_DMP" mode="access">
	<xsl:variable name="read"><xsl:choose><xsl:when test="@read='true'"><xsl:value-of select="'read'"/></xsl:when><xsl:otherwise><xsl:value-of select="'-'"/></xsl:otherwise></xsl:choose></xsl:variable>
	<xsl:variable name="write"><xsl:choose><xsl:when test="@write='true'"><xsl:value-of select="'write'"/></xsl:when><xsl:otherwise><xsl:value-of select="'-'"/></xsl:otherwise></xsl:choose></xsl:variable>
	<xsl:variable name="event"><xsl:choose><xsl:when test="@event='true'"><xsl:value-of select="'event'"/></xsl:when><xsl:otherwise><xsl:value-of select="'-'"/></xsl:otherwise></xsl:choose></xsl:variable>
	<xsl:value-of select="concat($read,'/',$write,'/',$event)"/>
</xsl:template>

<xsl:template match="ddl:propref_DMP" mode="size">
	<xsl:choose>
		<xsl:when test="@varsize='true'"><xsl:value-of select="'variable'"/></xsl:when>
		<xsl:when test="not(@size) or (number(@size)=1)"><xsl:value-of select="'1 byte'"/></xsl:when>
		<xsl:otherwise><xsl:value-of select="concat(@size,' bytes')"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<!-- === ddl:propref_IO === -->

<xsl:template match="ddl:propref_IO" mode="copy-properties">
	<xsl:param name="indices"/>
	<xsl:param name="parameters"/>
	<xsl:variable name="index" select="number(substring-before($indices,','))"/>
	<xsl:choose>
		<xsl:when test="not(@index) or (@index = $index)">
			<xsl:copy>
				<xsl:apply-templates select="@*|node()" mode="copy-properties"/>
			</xsl:copy>
		</xsl:when>
		<xsl:otherwise>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:propref_IO" mode="channel">
	<xsl:variable name="index" select="../../@index"/>
	<xsl:choose>
		<xsl:when test="$index and not(@index)"><xsl:value-of select="@channel + $index"/></xsl:when>
		<xsl:otherwise><xsl:value-of select="@channel"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:propref_IO" mode="range">
	<xsl:variable name="property" select="../.."/>
	<xsl:variable name="protocol" select=".."/>
	<!-- a range is specified with a single propref_IO per array property -->
	<xsl:if test="$property/@array and (number($property/@array) &gt; 1) and (count($protocol/ddl:propref_IO) = 1)"><xsl:value-of select="concat('..',(@channel + $property/@array - 1))"/></xsl:if>
</xsl:template>

<xsl:template match="ddl:propref_IO" mode="module-channel">
	<xsl:variable name="channel"><xsl:apply-templates select="." mode="channel"/></xsl:variable>
	<xsl:if test="@module"><xsl:value-of select="concat(@module,'_',@type,'_BASE + ')"/></xsl:if>
	<xsl:value-of select="$channel"/>
</xsl:template>

<xsl:template match="ddl:propref_IO" mode="flags">
	<xsl:param name="source" select="."/>
	<xsl:variable name="source-flags">
		<xsl:choose>
			<xsl:when test="($source/@invert='true')">sfInvert</xsl:when>
		</xsl:choose>
	</xsl:variable>
	<xsl:variable name="access">
		<xsl:choose>
			<xsl:when test="(@read='true') and (@write='true')">sfReadWrite</xsl:when>
			<xsl:when test="(@read='true')">sfRead</xsl:when>
			<xsl:when test="(@write='true')">sfWrite</xsl:when>
		</xsl:choose>
	</xsl:variable>
	<xsl:choose>
		<xsl:when test="$access!='' and $source-flags!=''"><xsl:value-of select="concat('(IOSignalFlags)(',$access,'|',$source-flags,')')"/></xsl:when>
		<xsl:when test="$access!=''"><xsl:value-of select="$access"/></xsl:when>
		<xsl:otherwise>sfNone</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:propref_IO" mode="class">
	<xsl:choose>
		<xsl:when test="@class"><xsl:value-of select="concat('sc',@class)"/></xsl:when>
		<xsl:when test="(@type='AI') or (@type='AO')"><xsl:value-of select="concat('sc','Float')"/></xsl:when>
		<xsl:when test="(@type='DI') or (@type='DO')"><xsl:value-of select="concat('sc','Boolean')"/></xsl:when>
		<xsl:otherwise>scNone</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<!-- === krohne:GDC === -->

<xsl:template match="krohne:GDC">
	<xsl:if test="string(../@name) != 'KROHNE.GDC'"><span class="error">protocol should be KROHNE.GDC</span></xsl:if>
	<xsl:if test="position() = 1"><xsl:value-of select="': objectNo='"/></xsl:if>
	<xsl:if test="position() &gt; 1"><xsl:value-of select="','"/></xsl:if>
	<xsl:variable name="objectNo"><xsl:apply-templates select="@objectNo" mode="dechex"/></xsl:variable>
	<xsl:variable name="subNo"><xsl:if test="@subNo"><xsl:value-of select="concat(':',@subNo)"/></xsl:if></xsl:variable>
	<xsl:value-of select="concat($objectNo,$subNo)"/>
	<xsl:if test="position() = last()"><xsl:value-of select="'.'"/></xsl:if>
</xsl:template>

<xsl:template match="krohne:GDC" mode="copy-properties">
	<xsl:param name="indices"/>
	<xsl:param name="parameters"/>
	<xsl:variable name="index" select="number(substring-before($indices,','))"/>
	<xsl:if test="(count(../krohne:GDC)=1) or ($index=count(./preceding-sibling::krohne:GDC))">
		<xsl:copy>
			<xsl:apply-templates select="@*|node()" mode="copy-properties"/>
		</xsl:copy>
	</xsl:if>
</xsl:template>

<!-- === cia:CANopen === -->

<xsl:template match="cia:CANopen">
	<xsl:if test="string(../@name) != 'CANopen'"><span class="error">protocol should be CANopen</span></xsl:if>
	<xsl:if test="position() = 1"><xsl:value-of select="': index='"/></xsl:if>
	<xsl:if test="position() &gt; 1"><xsl:value-of select="','"/></xsl:if>
	<xsl:variable name="access"><xsl:if test="@access"><xsl:text>(</xsl:text><xsl:apply-templates select="." mode="access"/><xsl:text>)</xsl:text></xsl:if></xsl:variable>
	<xsl:variable name="index"><xsl:apply-templates select="@index" mode="dechex"/></xsl:variable>
	<xsl:variable name="sub-index"><xsl:if test="@sub"><xsl:value-of select="concat(':',@sub)"/></xsl:if></xsl:variable>
	<xsl:value-of select="concat($index,$sub-index,$access)"/>
	<xsl:if test="position() = last()"><xsl:value-of select="'.'"/></xsl:if>
</xsl:template>

<xsl:template match="cia:CANopen" mode="copy-properties">
	<xsl:param name="indices"/>
	<xsl:param name="parameters"/>
	<xsl:variable name="index" select="number(substring-before($indices,','))"/>
	<xsl:if test="(count(../cia:CANopen)=1) or ($index=count(./preceding-sibling::cia:CANopen))">
		<xsl:copy>
			<xsl:apply-templates select="@*|node()" mode="copy-properties"/>
		</xsl:copy>
	</xsl:if>
</xsl:template>

<xsl:template match="cia:CANopen" mode="tr">
	<!--xsl:variable name="property" select="(ancestor::ddl:property)[1]"/-->
	<xsl:variable name="property" select="../.."/>
	<!-- todo: recursively include properties of child device -->
	<xsl:if test="$property/@index=0">
		<!--  @sub='0x01' -->
		<tr>
		<td align="right"><xsl:apply-templates select="." mode="node"/></td>
		<td align="right"><xsl:apply-templates select="@index" mode="dechex"/></td>
		<td align="right"><xsl:value-of select="'0'"/><!--xsl:apply-templates select="@sub" mode="dechex"/--></td>
		<td><xsl:apply-templates select="." mode="category"/></td>
		<td><xsl:value-of select="concat($property/@xml:id,'')"/></td>
		<td><xsl:value-of select="concat('type','.','uint8')"/><!--xsl:apply-templates select="$property/ddl:behavior" mode="link-in-list"/--></td>
		<td><xsl:apply-templates select="." mode="access"/></td></tr>
		<td><xsl:apply-templates select="." mode="pdo"/></td>
	</xsl:if>
	<tr>
	<td align="right"><xsl:apply-templates select="." mode="node"/></td>
	<td align="right"><xsl:apply-templates select="@index" mode="dechex"/></td>
	<td align="right"><xsl:apply-templates select="@sub" mode="dechex"/></td>
	<td><xsl:apply-templates select="." mode="category"/></td>
	<td><xsl:apply-templates select="$property" mode="link"/></td>
	<td><xsl:apply-templates select="$property/ddl:behavior" mode="link-in-list"/></td>
	<td><xsl:apply-templates select="." mode="access"/></td>
	<td><xsl:apply-templates select="." mode="pdo"/></td>
	</tr>
</xsl:template>

<xsl:template match="cia:CANopen" mode="category">
	<xsl:variable name="property" select="../.."/>
	<xsl:choose>
		<xsl:when test="$property/ddl:behavior[@set='CANopen.bset' and @name='category.mandatory']">M</xsl:when>
		<xsl:when test="$property/ddl:behavior[@set='CANopen.bset' and @name='category.optional']">O</xsl:when>
		<xsl:when test="$property/ddl:behavior[@set='CANopen.bset' and @name='category.conditional']">C</xsl:when>
	</xsl:choose>
</xsl:template>

<xsl:template match="cia:CANopen" mode="access">
	<xsl:value-of select="@access"/>
</xsl:template>

<xsl:template match="cia:CANopen" mode="node">
	<xsl:variable name="node-property" select="ancestor::ddl:property[ddl:protocol[@name='CANopen']/cia:CANopen[@node]]"/>
	<xsl:choose>
		<xsl:when test="@node"><xsl:value-of select="@node"/></xsl:when>
		<xsl:when test="$node-property"><xsl:value-of select="$node-property/ddl:protocol[@name='CANopen']/cia:CANopen[@node]/@node"/></xsl:when>
	</xsl:choose>
</xsl:template>

<xsl:template match="cia:CANopen" mode="pdo">
	<xsl:value-of select="@pdo"/>
</xsl:template>

<!-- === ddl:propref_Modbus === -->

<xsl:template match="ddl:propref_Modbus">
	<xsl:if test="starts-with(string(../@name),'Modbus')"><span class="error">protocol should be Modbus</span></xsl:if>
	<xsl:variable name="address"><xsl:apply-templates select="." mode="address"/></xsl:variable>
	<xsl:variable name="size"><xsl:apply-templates select="." mode="size"/></xsl:variable>
	<xsl:variable name="range">
		<xsl:if test="number($size) &gt; 1"><xsl:value-of select="concat('..',number($address) + number($size) - 1)"/></xsl:if>
	</xsl:variable>
	<xsl:if test="position()=1"><xsl:value-of select="': '"/></xsl:if>
	<xsl:if test="position() &gt; 1"><xsl:value-of select="', '"/></xsl:if>
	<xsl:value-of select="concat(@type,'[',$address,$range,']')"/>
</xsl:template>

<xsl:template match="ddl:propref_Modbus" mode="access">
	<xsl:choose>
		<xsl:when test="(@type='DI') or (@type='IR') or (@type='RDI')">pfRead</xsl:when>
		<xsl:when test="(@type='DO') or (@type='HR')">pfReadWrite</xsl:when>
		<xsl:otherwise>paNone</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:propref_Modbus" mode="copy-update-address">
	<xsl:copy>
		<xsl:copy-of select="@*[name()!='address']"/>
		<!-- calculate the address based on previous node and replace/add as attribute to the result tree -->
		<xsl:attribute name="address"><xsl:apply-templates select="." mode="calculate-address"/></xsl:attribute>
		<xsl:apply-templates select="*" mode="copy-update-address"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="ddl:propref_Modbus" mode="address">
	<xsl:value-of select="@address"/>
</xsl:template>

<xsl:template match="ddl:propref_Modbus" mode="calculate-address">
	<xsl:variable name="type" select="@type"/>
	<xsl:variable name="base-address">
		<xsl:choose>
			<xsl:when test="@address"><xsl:value-of select="@address"/></xsl:when>
			<xsl:when test="preceding::ddl:propref_Modbus[@type=$type]">
				<xsl:variable name="previous" select="preceding::ddl:propref_Modbus[@type=$type][1]"/>
				<xsl:variable name="address"><xsl:apply-templates select="$previous" mode="calculate-address"/></xsl:variable>
				<xsl:variable name="size"><xsl:apply-templates select="$previous" mode="size"/></xsl:variable>
				<xsl:value-of select="number($address) + number($size)"/>
			</xsl:when>
			<xsl:otherwise>0</xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:variable name="property" select="../.."/><!-- get the ancestor property|includedev node -->
	<xsl:choose>
		<xsl:when test="$property/@index">
				<xsl:variable name="index"><xsl:apply-templates select="." mode="index"/></xsl:variable>
				<xsl:variable name="size"><xsl:apply-templates select="." mode="size"/></xsl:variable>
			<xsl:value-of select="number($base-address) + number($index)*number($size)"/>
		</xsl:when>
		<xsl:otherwise><xsl:value-of select="$base-address"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:propref_Modbus" mode="index">
	<xsl:variable name="property" select="../.."/><!-- get the ancestor property|includedev node -->
	<xsl:choose>
		<xsl:when test="$property/@index"><xsl:value-of select="$property/@index"/></xsl:when>
		<xsl:otherwise><xsl:value-of select="0"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:propref_Modbus" mode="size">
	<xsl:choose>
		<xsl:when test="@size.paramname"><!-- resolve using parameters --><xsl:value-of select="@size"/></xsl:when>
		<xsl:when test="@size"><xsl:value-of select="@size"/></xsl:when>
		<xsl:otherwise><xsl:value-of select="1"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:propref_Modbus" mode="size-unit">
	<xsl:variable name="size"><xsl:apply-templates select="." mode="size"/></xsl:variable>
	<xsl:variable name="unit">
		<xsl:choose>
			<xsl:when test="(@type='DI') or (@type='DO')"><xsl:value-of select="'bit'"/></xsl:when>
			<xsl:when test="(@type='RDI')"><xsl:value-of select="'object'"/></xsl:when>
			<xsl:otherwise><xsl:value-of select="'word'"/></xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:choose>
		<xsl:when test="not($size) or (number($size)=1)"><xsl:value-of select="concat('1 ',$unit)"/></xsl:when>
		<xsl:otherwise><xsl:value-of select="concat($size,' ',$unit,'s')"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<!-- === ddl:protocol === -->

<!-- === @provider === -->

<xsl:template match="@provider" mode="link">
	<a href="{.}"><xsl:value-of select="."/></a>
</xsl:template>

<!-- === ddl:refines === -->

<xsl:template match="ddl:refines" mode="link">
	<xsl:variable name="url"><xsl:apply-templates select="@set" mode="url"/></xsl:variable>
	<a href="{$url}#{@name}" title="{$url}#{@name}"><xsl:value-of select="concat(@set,':',@name)"/></a>
</xsl:template>


<!-- === ddl:section === -->

<!-- === ddl:setparam === -->

<!-- === ddl:string === -->

<!-- === ddl:useprotocol === -->

<xsl:template match="ddl:useprotocol" mode="id">
	<xsl:value-of select="@name"/>
</xsl:template>

<xsl:template match="ddl:useprotocol" mode="link">
	<xsl:variable name="id"><xsl:apply-templates select="." mode="id"/></xsl:variable>
	<a href="#{$id}"><xsl:value-of select="@name"/></a>
</xsl:template>

<!-- === @UUID | @set (module reference UUID or UUIDname === -->

<xsl:template match="@UUID | @set">
	<xsl:apply-templates select="." mode="filename"/>
</xsl:template>

<!-- get the (base) filename of the module document based on the specified module identifier -->
<xsl:template match="@UUID | @set | @xml:id" mode="filename">
	<!-- determine the lookup-table for the UUID -->
	<xsl:param name="UUIDnames" select="preceding::ddl:UUIDname"/>
	<xsl:variable name="key" select="."/>
	<xsl:variable name="UUIDname" select="$UUIDnames[@name=$key]|$UUIDnames[@UUID=$key]"/>
	<xsl:choose>
		<xsl:when test="($filename-mode = 'UUID') and $UUIDname">
			<xsl:value-of select="$UUIDname[1]/@UUID"/>
		</xsl:when>
		<xsl:when test="($filename-mode = 'UUIDname') and $UUIDname">
			<xsl:value-of select="$UUIDname[1]/@name"/>
		</xsl:when>
		<xsl:otherwise><xsl:value-of select="$key"/></xsl:otherwise><!-- literal UUID may be used -->
	</xsl:choose>
</xsl:template>

<!-- get the url of the module document relative to this xsl template -->
<xsl:template match="@UUID | @set | @xml:id" mode="document-url">
	<xsl:param name="UUIDnames" select="preceding::ddl:UUIDname"/>
	<xsl:variable name="filename"><xsl:apply-templates select="." mode="filename"><xsl:with-param name="UUIDnames" select="$UUIDnames"/></xsl:apply-templates></xsl:variable>
	<xsl:value-of select="concat($ddl-path,$filename,'.ddl.xml')"/>
</xsl:template>

<!-- get the url of the module document relative to the source file -->
<xsl:template match="@UUID | @set | @xml:id" mode="url">
	<xsl:param name="UUIDnames" select="preceding::ddl:UUIDname"/>
	<xsl:variable name="filename"><xsl:apply-templates select="." mode="filename"><xsl:with-param name="UUIDnames" select="$UUIDnames"/></xsl:apply-templates></xsl:variable>
	<xsl:value-of select="concat($target-path,$filename,$filename-extension)"/>
</xsl:template>


<!-- === ddl:UUIDname === -->

<xsl:template match="ddl:UUIDname" mode="link">
	<xsl:variable name="url"><xsl:apply-templates select="@UUID" mode="url"><xsl:with-param name="UUIDnames" select="."/></xsl:apply-templates></xsl:variable>
  <a href="{$url}" title="{concat($url,' (',@UUID,')')}"><xsl:value-of select="@name"/></a>
</xsl:template>

<!-- === ddl:value === -->

<xsl:template match="ddl:value">
	<xsl:param name="parameters"/>
	<xsl:variable name="value.paramname" select="@value.paramname"/>
	<xsl:choose>
		<xsl:when test="@value.paramname and $parameters and $parameters[@name=$value.paramname]"><i><xsl:value-of select="$parameters[@name=$value.paramname]"/></i></xsl:when>
		<xsl:when test="@value.paramname"><i>&lt;<xsl:value-of select="@value.paramname"/>&gt;</i></xsl:when>
		<xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:value" mode="copy-properties">
	<xsl:param name="indices"/>
	<xsl:param name="parameters"/>
	<xsl:variable name="index" select="number(substring-before($indices,','))"/>
	<xsl:variable name="pos" select="count(./preceding-sibling::ddl:value)"/>
	<xsl:if test="(count(../ddl:value)=1) or ($pos=$index)">
		<xsl:copy>
			<xsl:apply-templates select="@*|node()" mode="copy-properties">
				<xsl:with-param name="indices" select="$indices"/>
				<xsl:with-param name="parameters" select="$parameters"/>
			</xsl:apply-templates>
		</xsl:copy>
	</xsl:if>
</xsl:template>

<xsl:template match="ddl:value" mode="text">
	<xsl:param name="parameters"/>
  <div><xsl:apply-templates select="."><xsl:with-param name="parameters" select="$parameters"/></xsl:apply-templates></div>
</xsl:template>

<xsl:template match="ddl:value" mode="c-constant">
	<xsl:param name="parameters"/>
	<xsl:param name="property-type"/>
	<xsl:variable name="value">
		<xsl:apply-templates select=".">
			<xsl:with-param name="parameters" select="$parameters"/>
		</xsl:apply-templates>
	</xsl:variable>
	<xsl:choose>
		<xsl:when test="(@type='uint') or (@type='sint')">
			<xsl:variable name="stdint-macro">
				<xsl:call-template name="c-stdint-constant-macro">
					<xsl:with-param name="name" select="$property-type"/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:value-of select="concat($stdint-macro,'(',$value,')')"/>
		</xsl:when>
		<xsl:when test="(@type='uint') or (@type='sint') or (@type='float')"><xsl:value-of select="$value"/></xsl:when>
		<xsl:when test="($property-type = 'tcChar')"><xsl:value-of select='concat("&apos;",$value,"&apos;")'/></xsl:when>
		<xsl:when test="($property-type = 'tcBoolean') and (@type='string')"><xsl:value-of select="$value"/></xsl:when>
		<xsl:when test="@type='object'"><xsl:value-of select="concat('&quot;',$value,'&quot;')"/></xsl:when>
		<xsl:otherwise>
			<xsl:value-of select="concat('&quot;',$value,'&quot;')"/><!--todo: escape \ and " -->
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="ddl:value" mode="JSON.value">
	<xsl:param name="parameters"/>
	<xsl:variable name="value">
		<xsl:apply-templates select=".">
			<xsl:with-param name="parameters" select="$parameters"/>
		</xsl:apply-templates>
	</xsl:variable>
	<xsl:choose>
		<xsl:when test="(@type='uint') or (@type='sint') or (@type='float')"><xsl:value-of select="$value"/></xsl:when>
		<xsl:when test="@type='object'"><xsl:value-of select="concat('&quot;',$value,'&quot;')"/></xsl:when>
		<xsl:otherwise>
			<xsl:variable name="is-bool"><xsl:apply-templates select=".." mode="has-behavior">
				<xsl:with-param name="name" select="'type.boolean'"/>
				<xsl:with-param name="set" select="$device-common-bset"/>
			</xsl:apply-templates></xsl:variable>
			<xsl:choose>
				<xsl:when test="@type='string' and ($is-bool='true')"><xsl:value-of select="$value"/></xsl:when>
				<xsl:otherwise><xsl:value-of select="concat('&quot;',$value,'&quot;')"/></xsl:otherwise><!--todo: escape \ and " -->
			</xsl:choose>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<!-- === ddl:@valuetype === -->

<!-- === html:a === -->

<xsl:template match="html:a">
	<a><xsl:copy-of select="@*"/><xsl:apply-templates select="node()"/></a>
</xsl:template>


<!-- === utility templates === -->

<!-- === Output text as comment (on a new line) === -->

<xsl:template name="comment">
	<xsl:param name="indent" select="''"/>
	<xsl:param name="text" select="''"/>
	<xsl:param name="delimiter" select="';'"/>
	<xsl:variable name="comment">
		<xsl:call-template name="site:string-replace">
			<xsl:with-param name="string" select="string($text)"/>
			<xsl:with-param name="key" select="'&#xA;'"/>
			<xsl:with-param name="replacement" select="concat('&#xA;',$indent,$delimiter,' ')"/>
		</xsl:call-template>
	</xsl:variable>
	<xsl:value-of select="concat('&#xA;',$indent,$delimiter,' ',$comment,'&#xA;')"/>
</xsl:template>

<!-- === Convert a DDL identifier (= XML Name) to a Pascal/C#/C/C++ identifier === -->

<xsl:template name="identifier">
	<xsl:param name="id"/>
	<!-- convert regular XML Name special characters (COLON, HYPHEN-MINUS, MIDDLE DOT) to LOW LINE (underscore), except FULL STOP (period) -->
	<xsl:value-of select="translate($id,':-&#xB7;','___')"/>
</xsl:template>

<xsl:template name="c-identifier">
	<xsl:param name="id"/>
	<!-- convert regular XML Name special characters (COLON, HYPHEN-MINUS, FULL STOP, MIDDLE DOT) to LOW LINE (underscore) -->
	<xsl:value-of select="translate($id,':-.&#xB7;','____')"/>
</xsl:template>

<!-- Convert a DDL xml:id with period(s) into a C++ namespace-name --> 
<xsl:template name="cpp-namespace-name">
	<xsl:param name="id"/>
	<xsl:param name="path" select="translate($id,':-&#xB7;','___')"/>
	<xsl:variable name="token" select="substring-before($path,'.')"/>
	<xsl:choose>
		<xsl:when test="$token or starts-with($path,'.')">
			<xsl:value-of select="concat($token,'::')"/>
			<xsl:call-template name="cpp-namespace-name"><xsl:with-param name="path" select="substring-after($path,'.')"/></xsl:call-template>
		</xsl:when>
		<xsl:otherwise><xsl:value-of select="$path"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template name="cpp-name">
	<xsl:param name="namespace-name"/>
	<xsl:variable name="token" select="substring-before($namespace-name,'::')"/>
	<xsl:choose>
		<xsl:when test="$token">
			<xsl:call-template name="cpp-name"><xsl:with-param name="namespace-name" select="substring-after($namespace-name,'::')"/></xsl:call-template>
		</xsl:when>
		<xsl:otherwise><xsl:value-of select="$namespace-name"/></xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template name="cpp-namespace">
	<xsl:param name="namespace-name"/>
	<xsl:variable name="token" select="substring-before($namespace-name,'::')"/>
	<xsl:if test="$token != ''">
		<xsl:value-of select="$token"/>
		<xsl:variable name="remainder">
			<xsl:call-template name="cpp-namespace"><xsl:with-param name="namespace-name" select="substring-after($namespace-name,'::')"/></xsl:call-template>
		</xsl:variable>
		<xsl:if test="$remainder != ''"><xsl:value-of select="concat('::',$remainder)"/></xsl:if>
	</xsl:if>
</xsl:template>

<xsl:template name="cpp-using-namespace">
	<xsl:param name="namespace-name"/>
	<xsl:variable name="namespace"><xsl:call-template name="cpp-namespace"><xsl:with-param name="namespace-name" select="$namespace-name"/></xsl:call-template></xsl:variable>
	<xsl:if test="$namespace">
		<xsl:value-of select="concat('using namespace ',$namespace,';&#xA;')"/>
	</xsl:if>
</xsl:template>

<xsl:template name="cpp-open-namespace">
	<xsl:param name="namespace-name"/>
	<xsl:variable name="token" select="substring-before($namespace-name,'::')"/>
	<xsl:if test="$token">
		<xsl:value-of select="concat('namespace ',$token,' {&#xA;')"/>
		<xsl:call-template name="cpp-open-namespace"><xsl:with-param name="namespace-name" select="substring-after($namespace-name,'::')"/></xsl:call-template>
	</xsl:if>
</xsl:template>

<xsl:template name="cpp-close-namespace">
	<xsl:param name="namespace-name"/>
	<xsl:variable name="token" select="substring-before($namespace-name,'::')"/>
	<xsl:if test="$token">
		<xsl:call-template name="cpp-close-namespace"><xsl:with-param name="namespace-name" select="substring-after($namespace-name,'::')"/></xsl:call-template>
		<xsl:value-of select="concat('} // namespace ',$token,'&#xA;')"/>
	</xsl:if>
</xsl:template>

<!-- get the C type specifier for the specified property-type -->
<xsl:template name="c-type-specifier">
	<xsl:param name="name"/>
	<xsl:choose>
		<xsl:when test="$name='tcEmpty'">void</xsl:when>
		<xsl:when test="$name='tcBoolean'">atomic_bool</xsl:when>
		<xsl:when test="$name='tcString'">char</xsl:when>
		<xsl:when test="$name='tcFloat32'">_Atomic(float)</xsl:when>
		<xsl:when test="$name='tcFloat64'">_Atomic(double)</xsl:when>
		<xsl:when test="$name='tcChar'">atomic_char32_t</xsl:when>
		<xsl:when test="$name='tcObjectRef'">void *</xsl:when>
		<xsl:when test="$name='tcInt8'">atomic_int_least8_t</xsl:when>
		<xsl:when test="$name='tcInt16'">atomic_int_least16_t</xsl:when>
		<xsl:when test="$name='tcInt32'">atomic_int_least32_t</xsl:when>
		<xsl:when test="$name='tcInt64'">atomic_int_least64_t</xsl:when>
		<xsl:when test="$name='tcUInt8'">atomic_uint_least8_t</xsl:when>
		<xsl:when test="$name='tcUInt16'">atomic_uint_least16_t</xsl:when>
		<xsl:when test="$name='tcUInt32'">atomic_uint_least32_t</xsl:when>
		<xsl:when test="$name='tcUInt64'">atomic_uint_least64_t</xsl:when>
		<xsl:when test="starts-with($name,'tcEnum-')"><xsl:value-of select="concat('_Atomic(',substring-after($name,'tcEnum-'),')')"/></xsl:when>
		<xsl:otherwise>
			<xsl:call-template name="c-identifier">
				<xsl:with-param name="id">
					<xsl:choose>
						<xsl:when test="starts-with($name,$device-common-root)"><xsl:value-of select="substring-after($name, $device-common-root)"/></xsl:when>
						<xsl:otherwise><xsl:value-of select="$name"/></xsl:otherwise>
					</xsl:choose>
				</xsl:with-param>
			</xsl:call-template>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<!-- get the C++ type specifier for the specified property-type -->
<xsl:template name="cpp-type-specifier">
	<xsl:param name="name"/>
	<xsl:choose>
		<xsl:when test="$name='tcEmpty'">void</xsl:when>
		<xsl:when test="$name='tcBoolean'">std::atomic_bool</xsl:when>
		<xsl:when test="$name='tcString'">std::string</xsl:when>
		<xsl:when test="$name='tcFloat32'">std::atomic&lt;float&gt;</xsl:when>
		<xsl:when test="$name='tcFloat64'">std::atomic&lt;double&gt;</xsl:when>
		<xsl:when test="$name='tcChar'">std::atomic_char32_t</xsl:when>
		<xsl:when test="$name='tcObjectRef'">void *</xsl:when>
		<xsl:when test="$name='tcInt8'">std::atomic_int_least8_t</xsl:when>
		<xsl:when test="$name='tcInt16'">std::atomic_int_least16_t</xsl:when>
		<xsl:when test="$name='tcInt32'">std::atomic_int_least32_t</xsl:when>
		<xsl:when test="$name='tcInt64'">std::atomic_int_least64_t</xsl:when>
		<xsl:when test="$name='tcUInt8'">std::atomic_uint_least8_t</xsl:when>
		<xsl:when test="$name='tcUInt16'">std::atomic_uint_least16_t</xsl:when>
		<xsl:when test="$name='tcUInt32'">std::atomic_uint_least32_t</xsl:when>
		<xsl:when test="$name='tcUInt64'">std::atomic_uint_least64_t</xsl:when>
		<xsl:when test="starts-with($name,'tcEnum-')"><xsl:value-of select="concat('std::atomic&lt;',substring-after($name,'tcEnum-'),'&gt;')"/></xsl:when>
		<xsl:otherwise>
			<xsl:call-template name="cpp-namespace-name">
				<xsl:with-param name="id" select="$name"/>
			</xsl:call-template>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>


<!-- get the C function macro for minimum-width integer constants for the specified property-type -->
<xsl:template name="c-stdint-constant-macro">
	<xsl:param name="name"/>
	<xsl:choose>
		<xsl:when test="$name='tcInt8'">INT8_C</xsl:when>
		<xsl:when test="$name='tcInt16'">INT16_C</xsl:when>
		<xsl:when test="$name='tcInt32'">INT32_C</xsl:when>
		<xsl:when test="$name='tcInt64'">INT64_C</xsl:when>
		<xsl:when test="$name='tcUInt8'">UINT8_C</xsl:when>
		<xsl:when test="$name='tcUInt16'">UINT16_C</xsl:when>
		<xsl:when test="$name='tcUInt32'">UINT32_C</xsl:when>
		<xsl:when test="$name='tcUInt64'">UINT64_C</xsl:when>
		<xsl:otherwise/>
	</xsl:choose>
</xsl:template>

<!-- === Get a pointer to the C/C++ TypeInfo of the specified type === -->

<xsl:template match="ddl:property | ddl:includedev" mode="c-type-info">
	<xsl:param name="name"/>
	<xsl:param name="language" select="'c'"/>
	<xsl:choose>
		<xsl:when test="($name='tcEmpty') and ($language='cpp')">nullptr</xsl:when>
		<xsl:when test="$name='tcEmpty'">NULL</xsl:when>
		<xsl:when test="$name='tcBoolean'">&amp;TypeBoolean</xsl:when>
		<xsl:when test="$name='tcChar'">&amp;TypeChar</xsl:when>
		<xsl:when test="$name='tcString'">&amp;TypeString</xsl:when>
		<xsl:when test="$name='tcFloat32'">&amp;TypeBinary32</xsl:when>
		<xsl:when test="$name='tcFloat64'">&amp;TypeBinary64</xsl:when>
		<xsl:when test="$name='tcObject'">&amp;TypeObject</xsl:when>
		<xsl:when test="$name='tcObjectRef'">&amp;TypeObjectRef</xsl:when>
		<xsl:when test="$name='tcInt8'">&amp;TypeInt8</xsl:when>
		<xsl:when test="$name='tcInt16'">&amp;TypeInt16</xsl:when>
		<xsl:when test="$name='tcInt32'">&amp;TypeInt32</xsl:when>
		<xsl:when test="$name='tcInt64'">&amp;TypeInt64</xsl:when>
		<xsl:when test="$name='tcUInt8'">&amp;TypeUInt8</xsl:when>
		<xsl:when test="$name='tcUInt16'">&amp;TypeUInt16</xsl:when>
		<xsl:when test="$name='tcUInt32'">&amp;TypeUInt32</xsl:when>
		<xsl:when test="$name='tcUInt64'">&amp;TypeUInt64</xsl:when>
		<xsl:when test="starts-with($name,'tcEnum-')"><xsl:value-of select="concat('(TypeInfo_Handle)&amp;',substring-after($name,'tcEnum-'),'_TypeInfo')"/></xsl:when>
		<xsl:when test="$language='cpp' and (name()='includedev')">
			<xsl:variable name="type">
				<xsl:call-template name="cpp-namespace-name">
					<xsl:with-param name="id" select="$name"/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:value-of select="concat('(TypeInfo_Handle)&amp;',$type,'::_TypeInfo')"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:variable name="type"><!-- enum type -->
				<xsl:call-template name="c-identifier">
					<xsl:with-param name="id" select="$name"/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:value-of select="concat('(TypeInfo_Handle)&amp;',$type,'_TypeInfo')"/>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template name="ConvertDecToHex">
	<xsl:param name="index" />
	<xsl:param name="width" select="4"/>
	<xsl:if test="number($index) = 0">0</xsl:if>
	<xsl:if test="number($index) > 0">
		<xsl:call-template name="ConvertDecToHex">
			<xsl:with-param name="index" select="floor(number($index) div 16)" />
		</xsl:call-template>
		<xsl:choose>
			<xsl:when test="number($index) mod 16 &lt; 10">
				<xsl:value-of select="number($index) mod 16" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:choose>
					<xsl:when test="number($index) mod 16 = 10">A</xsl:when>
					<xsl:when test="number($index) mod 16 = 11">B</xsl:when>
					<xsl:when test="number($index) mod 16 = 12">C</xsl:when>
					<xsl:when test="number($index) mod 16 = 13">D</xsl:when>
					<xsl:when test="number($index) mod 16 = 14">E</xsl:when>
					<xsl:when test="number($index) mod 16 = 15">F</xsl:when>
					<xsl:otherwise>A</xsl:otherwise>
				</xsl:choose>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:if>
</xsl:template>

<xsl:template name="FormatHex">
	<xsl:param name="number"/>
	<xsl:param name="width" select="4"/>
	<xsl:variable name="hexnumber">
		<xsl:call-template name="ConvertDecToHex">
			<xsl:with-param name="index" select="$number" />
		</xsl:call-template>
	</xsl:variable>
	<xsl:variable name="padding">
		<xsl:call-template name="padding">
			<xsl:with-param name="pad" select="'0'"/>
			<xsl:with-param name="width" select="number($width) - string-length($hexnumber)"/>
		</xsl:call-template>
	</xsl:variable>
	<xsl:value-of select="concat('0x',$padding,$hexnumber)"/>
</xsl:template>

<xsl:template name="padding">
	<xsl:param name="pad" select="' '" />
	<xsl:param name="width" select="0"/>
	<xsl:if test="number($width) > 0">
		<xsl:value-of select="$pad"/>
		<xsl:call-template name="padding">
			<xsl:with-param name="pad" select="$pad"/>
			<xsl:with-param name="width" select="number($width) - 1" />
		</xsl:call-template>
	</xsl:if>
</xsl:template>

<!-- ==== hash code generation ===== -->

<xsl:template name="get-hash">
	<xsl:param name="text"/>
	<xsl:param name="value" select="0"/>

	<xsl:if test="not($text)">
	  <xsl:value-of select="number($value) mod 100000"/>
	</xsl:if>
	<!-- parse text (string of characters) recursively -->
	<xsl:if test="$text">
		<xsl:variable name="text1" select="translate($text,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')"/>
		<xsl:variable name="text2" select="translate($text1,'abcdefghijklmnopqrstuvwxyz ()[]{}.,;:/\-_!@#$%*+','01234567890123456789012345')"/>
	  <!--xsl:value-of select="concat($text1,' - -> ',$text2)"/-->

		<xsl:variable name="char" select="substring($text2,1,1)"/>
		<xsl:variable name="rest" select="substring($text2,2,string-length($text2)-1)"/>
		<xsl:if test="$char and contains('0123456789',$char)">
		  <xsl:variable name="result" select="( ($value * 32) + number($char) ) mod 100000"/>

			<xsl:call-template name="get-hash">
				<xsl:with-param name="text" select="$rest"/>
				<xsl:with-param name="value" select="$result"/>
			</xsl:call-template>
  	</xsl:if>
	</xsl:if>
</xsl:template>

</xsl:stylesheet>