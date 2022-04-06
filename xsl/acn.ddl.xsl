<?xml version="1.0" encoding="UTF-8"?>
<!--
 acn.ddl.xsl

 An XSL-T stylesheet for viewing an ACN Device Description Language Module file via HTML.

 @date 2019-11-09
 @author Ernst van der Pols
-->

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:site="http://ns.nlsw.nl/2010/site"
		xmlns:ddl="http://www.esta.org/acn/namespace/ddl/2008/"
		xmlns:html="http://www.w3.org/1999/xhtml"
		xmlns:exslt="http://exslt.org/common"
		xmlns:msxsl="urn:schemas-microsoft-com:xslt"
 		xmlns:xlink="http://www.w3.org/1999/xlink"
		exclude-result-prefixes="exslt msxsl site ddl xlink html">

<!-- import conversion template -->
<xsl:import href="acn.ddl-to-html.xsl"/>

<!-- http://www.tkachenko.com/blog/archives/000704.html -->
<!-- @todo move this template to wrapper for usage with browser transformation only, since this is only required for IE -->
<msxsl:script language="JScript" implements-prefix="exslt">
<![CDATA[
 this['node-set'] = function (x) {
  return x;
 }
]]>
</msxsl:script>


</xsl:stylesheet>