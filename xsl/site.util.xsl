<?xml version="1.0" encoding="ISO-8859-1"?>
<!--
 site.util.xsl

 Een XSL-T stylesheet met utility templates.

 Copyright 2003-2014 NewLife Software, Holland

 Auteur: E.K.H. van der Pols
-->

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:site="http://ns.nlsw.nl/2010/site"
  exclude-result-prefixes="site">

<!-- test filename utility templates -->

<!--xsl:template name="test-file-name">
	<xsl:variable name="sample0" select="'/'"/>
	<xsl:variable name="sample1" select="'base/../hello/../world/./path/filename.ext'"/>
	<xsl:variable name="sample2" select="'/absolute-path/hello/../file/ext'"/>
	<xsl:variable name="sample3" select="'//server/absolute-path/file'"/>
	<xsl:variable name="sample4" select="'http://server/absolute-path/file'"/>

	<div><xsl:value-of select="$sample0"/></div>
	<div>filename:<xsl:call-template name="site:get-filename"><xsl:with-param name="path" select="$sample0"/></xsl:call-template></div>
	<div><xsl:call-template name="site:get-path"><xsl:with-param name="path" select="$sample0"/></xsl:call-template></div>
	<div>dir:<xsl:call-template name="site:get-dir"><xsl:with-param name="path" select="$sample0"/></xsl:call-template></div>
	<div><xsl:call-template name="site:get-solved-path"><xsl:with-param name="path" select="$sample0"/></xsl:call-template></div>
	<br/>
	<div><xsl:value-of select="$sample1"/></div>
	<div><xsl:call-template name="site:get-filename"><xsl:with-param name="path" select="$sample1"/></xsl:call-template></div>
	<div><xsl:call-template name="site:get-path"><xsl:with-param name="path" select="$sample1"/></xsl:call-template></div>
	<div style="background-color:cyan"><xsl:call-template name="site:get-dir"><xsl:with-param name="path" select="$sample1"/></xsl:call-template></div>
	<div><xsl:call-template name="site:get-solved-path"><xsl:with-param name="path" select="$sample1"/></xsl:call-template></div>
	<br/>
	<div><xsl:value-of select="$sample2"/></div>
	<div><xsl:call-template name="site:get-filename"><xsl:with-param name="path" select="$sample2"/></xsl:call-template></div>
	<div><xsl:call-template name="site:get-path"><xsl:with-param name="path" select="$sample2"/></xsl:call-template></div>
	<div><xsl:call-template name="site:get-dir"><xsl:with-param name="path" select="$sample2"/></xsl:call-template></div>
	<div><xsl:call-template name="site:get-solved-path"><xsl:with-param name="path" select="$sample2"/></xsl:call-template></div>
	<br/>
	<div><xsl:value-of select="$sample3"/></div>
	<div><xsl:call-template name="site:get-filename"><xsl:with-param name="path" select="$sample3"/></xsl:call-template></div>
	<div><xsl:call-template name="site:get-path"><xsl:with-param name="path" select="$sample3"/></xsl:call-template></div>
	<div><xsl:call-template name="site:get-dir"><xsl:with-param name="path" select="$sample3"/></xsl:call-template></div>
	<div><xsl:call-template name="site:get-solved-path"><xsl:with-param name="path" select="$sample3"/></xsl:call-template></div>
	<br/>
	<div><xsl:value-of select="$sample4"/></div>
	<div><xsl:call-template name="site:get-filename"><xsl:with-param name="path" select="$sample4"/></xsl:call-template></div>
	<div><xsl:call-template name="site:get-path"><xsl:with-param name="path" select="$sample4"/></xsl:call-template></div>
	<div><xsl:call-template name="site:get-dir"><xsl:with-param name="path" select="$sample4"/></xsl:call-template></div>
	<div><xsl:call-template name="site:get-solved-path"><xsl:with-param name="path" select="$sample4"/></xsl:call-template></div>
</xsl:template-->

	<!-- === identity copy template === -->

	<xsl:template mode="copy" match="@*|*|text()|processing-instruction()|comment()" >
		<xsl:param name="base"/>
		<xsl:param name="item"/>
		<xsl:copy>
			<xsl:apply-templates mode="copy" select="@*|*|text()|processing-instruction()|comment()">
				<xsl:with-param name="base" select="$base"/>
				<xsl:with-param name="item" select="$item"/>
			</xsl:apply-templates>
		</xsl:copy>
	</xsl:template>

	<!-- === count number of IDREFS (recursively) === -->

	<xsl:template name="site:count-idrefs">
		<xsl:param name="keys" select="'id title'"/>
		<xsl:param name="count" select="0"/>
		<!-- parse list of IDREFS recursively -->
		<xsl:variable name="token">
			<xsl:if test="substring-before($keys,' ')"><xsl:value-of select="substring-before($keys,' ')"/></xsl:if>
			<xsl:if test="not(substring-before($keys,' '))"><xsl:value-of select="$keys"/></xsl:if>
		</xsl:variable>
		<xsl:if test="string($token)">
			<xsl:call-template name="site:count-idrefs">
				<xsl:with-param name="count" select="number($count) + 1"/>
				<xsl:with-param name="keys" select="substring-after($keys,' ')"/>
			</xsl:call-template>
		</xsl:if>
		<xsl:if test="not(string($token))"><xsl:value-of select="$count"/></xsl:if>
	</xsl:template>

	<!-- === site:get-path - remove filename from full path === -->

	<xsl:template name="site:get-path">
		<xsl:param name="path"/>
		<!-- parse path recursively -->
		<xsl:variable name="token" select="substring-before($path,'/')"/>
		<xsl:if test="$token or starts-with($path,'/')">
			<xsl:value-of select="concat($token,'/')"/>
			<xsl:call-template name="site:get-path">
				<xsl:with-param name="path" select="substring-after($path,'/')"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>

	<!-- === site:get-dir - remove filename (and path separator) from full path === -->

	<xsl:template name="site:get-dir">
		<xsl:param name="path"/>
		<xsl:param name="separator" select="'/'"/>
		<!-- parse path recursively -->
		<xsl:variable name="token" select="substring-before($path,$separator)"/>
		<xsl:variable name="next-token" select="substring-after($path,$separator)"/>
		<xsl:if test="$token or starts-with($path,$separator)">
			<xsl:value-of select="$token"/>
			<xsl:if test="contains($next-token,$separator) or starts-with($path,$separator)"><xsl:value-of select="$separator"/></xsl:if>
			<xsl:call-template name="site:get-dir">
				<xsl:with-param name="path" select="$next-token"/>
				<xsl:with-param name="separator" select="$separator"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>

	<!-- === site:get-filename - remove path from full filename  === -->

	<xsl:template name="site:get-filename">
		<xsl:param name="path"/>
		<!-- parse path recursively -->
		<xsl:variable name="token" select="substring-before($path,'/')"/>
		<xsl:if test="$token or starts-with($path,'/')">
			<xsl:call-template name="site:get-filename">
				<xsl:with-param name="path" select="substring-after($path,'/')"/>
			</xsl:call-template>
		</xsl:if>
		<xsl:if test="not($token) and not(starts-with($path,'/'))">
			<xsl:value-of select="$path"/>
		</xsl:if>
	</xsl:template>

	<!-- === site:get-solved-path - remove '..' and '.' from path where possible === -->

	<xsl:template name="site:get-solved-path">
		<xsl:param name="path"/>
		<xsl:param name="result" select="''"/>
		<xsl:param name="separator" select="'/'"/>
		<!-- parse path recursively -->
		<xsl:variable name="token" select="substring-before($path,$separator)"/>
		<xsl:variable name="newpath" select="substring-after($path,$separator)"/>

		<xsl:choose>
			<xsl:when test="($path='.') or ($path='')"><xsl:value-of select="$result"/></xsl:when>

			<xsl:when test="($path='..') and ($result!='')">
				<xsl:variable name="previous-token">
					<xsl:call-template name="site:get-filename"><xsl:with-param name="path" select="$result"/></xsl:call-template>
				</xsl:variable>
				<xsl:choose>
					<xsl:when test="$previous-token != '..' and $previous-token!=''">
						<!-- merge previous with .. -->
						<xsl:call-template name="site:get-dir">
							<xsl:with-param name="path" select="$result"/>
							<xsl:with-param name="separator" select="$separator"/>
						</xsl:call-template>
					</xsl:when>
					<xsl:otherwise><xsl:value-of select="concat($result,$separator,$path)"/></xsl:otherwise>
				</xsl:choose>
			</xsl:when>

			<xsl:when test="(($token!='') or starts-with($path,$separator)) and ($newpath!='')">
				<xsl:call-template name="site:get-solved-path">
					<xsl:with-param name="path" select="$newpath"/>
					<xsl:with-param name="separator" select="$separator"/>
					<xsl:with-param name="result">
						<xsl:choose>
							<xsl:when test="(string($result)='') and starts-with($path,$separator)">
								<xsl:value-of select="concat($token,$separator)"/>
							</xsl:when>
							<xsl:when test="(($result=$separator) or ($result=concat($separator,$separator))) and not(starts-with($path,$separator))">
								<xsl:value-of select="concat($result,$token)"/>
							</xsl:when>
							<xsl:when test="string($result)=''">
								<xsl:value-of select="$token"/>
							</xsl:when>
							<xsl:when test="$token='.'">
								<xsl:value-of select="$result"/>
							</xsl:when>
							<xsl:when test="$token = '..'">
								<xsl:variable name="previous-token">
									<xsl:call-template name="site:get-filename"><xsl:with-param name="path" select="$result"/></xsl:call-template>
								</xsl:variable>
								<xsl:choose>
									<xsl:when test="$previous-token != '..' and $previous-token!=''">
										<!-- merge previous with .. -->
										<xsl:call-template name="site:get-dir">
											<xsl:with-param name="path" select="$result"/>
											<xsl:with-param name="separator" select="$separator"/>
										</xsl:call-template>
									</xsl:when>
									<xsl:otherwise><xsl:value-of select="concat($result,$separator,$token)"/></xsl:otherwise>
								</xsl:choose>
							</xsl:when>
							<xsl:otherwise><xsl:value-of select="concat($result,$separator,$token)"/></xsl:otherwise>
						</xsl:choose>
					</xsl:with-param>
				</xsl:call-template>
			</xsl:when>
			<xsl:when test="$result!=''">
				<xsl:value-of select="concat($result,$separator,$path)"/>
			</xsl:when>
			<xsl:otherwise><xsl:value-of select="$path"/></xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!--
		site:get-common-base - determine the common base path of the specified paths
		@note UNTESTED
		@param p1 the first path to process
		@param p2 the second path to process
  -->
	<xsl:template name="site:get-common-base">
		<xsl:param name="p1"/>
		<xsl:param name="p2"/>
		<xsl:param name="result" select="''"/>
		<xsl:variable name="p1-token" select="substring-before($p1,'/')"/>
		<xsl:variable name="p2-token" select="substring-before($p2,'/')"/>
		<xsl:variable name="p1-rest" select="substring-after($p2,'/')"/>
		<xsl:variable name="p2-rest" select="substring-after($p2,'/')"/>

		<xsl:choose>
			<xsl:when test="($p1='') or ($p2='') or (($p1-token != $p2-token) and ($result=''))">
				<xsl:value-of select="$result"/>
			</xsl:when>
			<xsl:when test="($p1-token != $p2-token) and ($result!='')">
				<xsl:value-of select="concat($result,'/')"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:call-template name="site:get-common-base">
					<xsl:with-param name="p1" select="$p1-rest"/>
					<xsl:with-param name="p2" select="$p2-rest"/>
					<xsl:with-param name="result"><xsl:value-of select="concat($result,$p1-token,'/')"/></xsl:with-param>
				</xsl:call-template>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!--
		site:get-path-to-root - determine the path to get to the root (base) of the specified path
		@param path the path to process (should not contain '..')
  -->
	<xsl:template name="site:get-path-to-root">
		<xsl:param name="path"/>
		<xsl:param name="result" select="''"/>
		<xsl:variable name="path-token" select="substring-before($path,'/')"/>
		<xsl:variable name="path-rest" select="substring-after($path,'/')"/>
		<xsl:choose>
			<xsl:when test="$path=''">
				<xsl:value-of select="$result"/>
			</xsl:when>
			<xsl:when test="$path-token='..'">
				<xsl:message terminate="yes"><xsl:value-of select="concat('path ',$path,' contains &quot;..&quot;, apply solve-path first')"/></xsl:message>
			</xsl:when>
			<xsl:when test="($path-token='.')">
				<xsl:call-template name="site:get-path-to-root">
					<xsl:with-param name="path" select="$path-rest"/>
					<xsl:with-param name="result" select="$result"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<xsl:call-template name="site:get-path-to-root">
					<xsl:with-param name="path" select="$path-rest"/>
					<xsl:with-param name="result">
						<xsl:value-of select="concat($result,'../')"/>
					</xsl:with-param>
				</xsl:call-template>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- site:is-absolute-uri -->

	<xsl:template name="site:is-absolute-uri">
		<xsl:param name="uri"/>
		<xsl:if test="contains($uri, ':') or starts-with($uri,'/')">
			<xsl:value-of select="true()"/>
		</xsl:if>
	</xsl:template>

	<!-- site:get-uri-scheme -->

	<xsl:template name="site:get-uri-scheme">
		<xsl:param name="uri"/>
		<xsl:if test="contains($uri, ':')">
			<xsl:value-of select="substring-before($uri, ':')"/>
		</xsl:if>
	</xsl:template>

	<!-- site:get-uri-authority -->

	<xsl:template name="site:get-uri-authority">
		<xsl:param name="uri"/>
		<xsl:variable name="a">
			<xsl:choose>
				<xsl:when test="contains($uri, ':')">
					<xsl:if test="substring(substring-after($uri, ':'), 1, 2) = '//'">
							<xsl:value-of select="substring(substring-after($uri, ':'), 3)"/>
					</xsl:if>
				</xsl:when>
				<xsl:otherwise>
					<xsl:if test="substring($uri, 1, 2) = '//'">
						<xsl:value-of select="substring($uri, 3)"/>
					</xsl:if>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="contains($a, '/')">
				<xsl:value-of select="substring-before($a, '/')" />
			</xsl:when>
			<xsl:when test="contains($a, '?')">
				<xsl:value-of select="substring-before($a, '?')" />
			</xsl:when>
			<xsl:when test="contains($a, '#')">
				<xsl:value-of select="substring-before($a, '#')" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$a" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- site:get-uri-path -->

	<xsl:template name="site:get-uri-path">
		<xsl:param name="uri"/>

		<xsl:variable name="p">
			<xsl:choose>
				<xsl:when test="contains($uri, '//')">
					<xsl:if test="contains(substring-after($uri, '//'), '/')">
						<xsl:value-of select="concat('/', substring-after(substring-after($uri, '//'), '/'))"/>
					</xsl:if>
				</xsl:when>
				<xsl:otherwise>
					<xsl:choose>
						<xsl:when test="contains($uri, ':')">
							<xsl:value-of select="substring-after($uri, ':')"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="$uri"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<xsl:choose>
			<xsl:when test="contains($p, '?')">
				<xsl:value-of select="substring-before($p, '?')" />
			</xsl:when>
			<xsl:when test="contains($p, '#')">
				<xsl:value-of select="substring-before($p, '#')" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$p" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- site:get-uri-query -->

	<xsl:template name="site:get-uri-query">
		<xsl:param name="uri"/>

		<xsl:variable name="q" select="substring-after($uri, '?')"/>

		<xsl:choose>
			<xsl:when test="contains($q, '#')">
				<xsl:value-of select="substring-before($q, '#')"/>
			</xsl:when>
			<xsl:otherwise><xsl:value-of select="$q"/></xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- site:get-uri-fragment -->

	<xsl:template name="site:get-uri-fragment">
		<xsl:param name="uri"/>
		<xsl:value-of select="substring-after($uri, '#')"/>
	</xsl:template>

	<!-- site:resolve-scheme - resolves a uri with a specific scheme -->

	<xsl:template name="site:resolve-scheme">
		<xsl:param name="uri"/>
		<xsl:param name="base"/>
		<xsl:param name="scheme"/>
		<xsl:value-of select="$uri"/>
	</xsl:template>


	<!-- site:resolve-uri - resolves conform rfc2396.txt -->

	<xsl:template name="site:resolve-uri">
		<xsl:param name="uri"/>
		<xsl:param name="base"/>
		<xsl:param name="base-id"/>

		<xsl:param name="scheme">
			<xsl:call-template name="site:get-uri-scheme">
				<xsl:with-param name="uri" select="$uri"/>
			</xsl:call-template>
		</xsl:param>
		<xsl:param name="authority">
			<xsl:call-template name="site:get-uri-authority">
				<xsl:with-param name="uri" select="$uri"/>
			</xsl:call-template>
		</xsl:param>
		<xsl:param name="path">
			<xsl:call-template name="site:get-uri-path">
				<xsl:with-param name="uri" select="$uri"/>
			</xsl:call-template>
		</xsl:param>
		<xsl:param name="query">
			<xsl:call-template name="site:get-uri-query">
				<xsl:with-param name="uri" select="$uri"/>
			</xsl:call-template>
		</xsl:param>
		<xsl:param name="fragment">
			<xsl:call-template name="site:get-uri-fragment">
				<xsl:with-param name="uri" select="$uri"/>
			</xsl:call-template>
		</xsl:param>

		<xsl:choose>
			<xsl:when test="string-length($scheme)">
				<xsl:call-template name="site:resolve-scheme">
					<xsl:with-param name="uri" select="$uri"/>
					<xsl:with-param name="base" select="$base"/>
					<xsl:with-param name="scheme" select="$scheme"/>
					<xsl:with-param name="authority" select="$authority"/>
					<xsl:with-param name="path" select="$path"/>
					<xsl:with-param name="query" select="$query"/>
					<xsl:with-param name="fragment" select="$fragment"/>
					<xsl:with-param name="base-id" select="$base-id"/>
				</xsl:call-template>
			</xsl:when>

			<!-- alleen #fragment, blijft altijd alleen #fragment -->
			<xsl:when test="not(string-length($authority))
				and not(string-length($path)) and not(string-length($query))">
				<xsl:if test="string-length($fragment)">
					<xsl:value-of select="concat('#', $fragment)"/>
				</xsl:if>
			</xsl:when>

			<xsl:otherwise>
				<xsl:variable name="result-scheme">
					<xsl:call-template name="site:get-uri-scheme">
						<xsl:with-param name="uri" select="$base"/>
					</xsl:call-template>
				</xsl:variable>
				<xsl:variable name="result-authority">
					<xsl:choose>
						<xsl:when test="string-length($authority)">
							<xsl:value-of select="$authority"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:call-template name="site:get-uri-authority">
								<xsl:with-param name="uri" select="$base"/>
							</xsl:call-template>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:variable>
				<xsl:variable name="result-path">
					<xsl:choose>
						<!-- don't normalize absolute paths -->
						<xsl:when test="starts-with($path, '/')">
							<xsl:value-of select="$path" />
						</xsl:when>
						<xsl:otherwise>
							<xsl:call-template name="site:get-solved-path">
								<xsl:with-param name="path" select="concat($base,$path)"/>
							</xsl:call-template>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:variable>

				<xsl:if test="string-length($result-scheme)">
					<xsl:value-of select="concat($result-scheme,':')"/>
				</xsl:if>
				<xsl:if test="string-length($result-authority)">
					<xsl:value-of select="concat('//',$result-authority)"/>
				</xsl:if>
				<xsl:value-of select="$result-path"/>
				<xsl:if test="string-length($query)">
					<xsl:value-of select="concat('?', $query)"/>
				</xsl:if>
				<xsl:if test="string-length($fragment)">
					<xsl:value-of select="concat('#', $fragment)"/>
				</xsl:if>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>


	<!-- === quick version of site:resolve-uri, mainly for adjusting relative filenames === -->

	<xsl:template name="site:fix-path">
		<xsl:param name="path"/>
		<xsl:param name="base" select="'../'"/>
		<xsl:choose>
			<!-- don't adjust absolute uri paths -->
			<xsl:when test="($path='') or contains($path, ':') or starts-with($path, '/')">
				<xsl:value-of select="$path" />
			</xsl:when>
			<xsl:otherwise>
				<!-- fix relative path -->
				<xsl:call-template name="site:get-solved-path">
					<xsl:with-param name="path" select="concat($base,$path)"/>
				</xsl:call-template>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- === string replace template === -->

	<xsl:template name="site:string-replace">
		<xsl:param name="string"/>
		<xsl:param name="key"/>
		<xsl:param name="replacement"/>
		<xsl:variable name="front" select="substring-before($string,$key)"/>
		<xsl:choose>
			<xsl:when test="contains($string,$key)">
				<xsl:value-of select="concat(substring-before($string,$key),$replacement)"/>
				<xsl:call-template name="site:string-replace">
					<xsl:with-param name="string" select="substring-after($string,$key)"/>
					<xsl:with-param name="key" select="$key"/>
					<xsl:with-param name="replacement" select="$replacement"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise><xsl:value-of select="$string"/></xsl:otherwise>
		</xsl:choose>
	</xsl:template>

</xsl:stylesheet>