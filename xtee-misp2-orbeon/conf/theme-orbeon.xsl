<!--
  Copyright (C) 2010 Orbeon, Inc.

  This program is free software; you can redistribute it and/or modify it under the terms of the
  GNU Lesser General Public License as published by the Free Software Foundation; either version
  2.1 of the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU Lesser General Public License for more details.

  The full text of the license is available at http://www.gnu.org/copyleft/lesser.html
  -->
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:version="java:org.orbeon.oxf.common.Version">

    <!-- Try to obtain a meaningful title for the example -->
    <xsl:variable name="title" select="if (/xhtml:html/xhtml:head/xhtml:title != '')
                                       then /xhtml:html/xhtml:head/xhtml:title
                                       else if (/xhtml:html/xhtml:body/xhtml:h1)
                                            then (/xhtml:html/xhtml:body/xhtml:h1)[1]
                                            else '[Untitled]'" as="xs:string"/>
    <!-- Orbeon Forms version -->
    <xsl:variable name="orbeon-forms-version" select="version:getVersionString()" as="xs:string"/>

    <!-- - - - - - - Themed page template - - - - - - -->
    <xsl:template match="/">
        <xhtml:html>
            <xsl:apply-templates select="/xhtml:html/@*"/>
            <xhtml:head>
                <!-- Add meta as early as possible -->
                <xsl:apply-templates select="/xhtml:html/xhtml:head/xhtml:meta"/>
                <xhtml:title><xsl:value-of select="$title"/></xhtml:title>
                <!-- NOTE: The XForms engine may place additional scripts and stylesheets here as needed -->
                <xhtml:link rel="stylesheet" type="text/css" href="/resources/EE/css/xforms.css" media="screen"/>
                <xhtml:link rel="stylesheet" type="text/css" href="/resources/EE/css/xforms-pdf.css" media="print"/>
                <!-- <xhtml:link rel="stylesheet" href="/config/theme/orbeon.css" type="text/css" media="all"/> -->
                <!-- Handle head elements except scripts -->
                <xsl:apply-templates select="/xhtml:html/xhtml:head/(xhtml:link | xhtml:style)"/>
                <!-- Orbeon Forms version -->
                <xhtml:meta name="generator" content="{$orbeon-forms-version}"/>
                <!-- Favicon -->
				<xhtml:script type="text/javascript" src="/resources/jscript/jquery-1.7.1.min.js"></xhtml:script>
				<xhtml:script type="text/javascript" src="/resources/jscript/orbeon-functions.js"></xhtml:script>
				<xhtml:script type="text/javascript" src="/resources/jscript/innerXHTML.js"></xhtml:script>			     
            </xhtml:head>
			
			<!-- From http://orbeon-forms-ops-users.24843.n4.nabble.com/Form-hidden-after-updating-to-orbeon-3-9-0-pre-201103180400-CE-td3388622.html -->
			<xsl:apply-templates select="/xhtml:html/xhtml:body"/>
            <xsl:apply-templates select="/xhtml:html/xhtml:script"/>
			
        </xhtml:html>
    </xsl:template>

    <!-- Simply copy everything that's not matched -->
    <xsl:template match="@*|node()" priority="-2">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>
