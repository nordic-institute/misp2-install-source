SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

DELETE FROM misp2.xslt WHERE portal_id is null and (name='debug' or name='headers' or name='i18n' or name='context' or name='orbeon' or name='attachments');

INSERT INTO misp2.xslt (query_id, xsl, priority, created, name, form_type, in_use, producer_id, url) VALUES (NULL, '<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xforms="http://www.w3.org/2002/xforms"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:xxforms="http://orbeon.org/oxf/xml/xforms"
  xmlns:events="http://www.w3.org/2001/xml-events"
  xmlns:xrd="http://x-road.ee/xsd/x-road.xsd"
  xmlns:xtee="http://x-tee.riik.ee/xsd/xtee.xsd"  
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:f="http://orbeon.org/oxf/xml/formatting"
  xmlns:fr="http://orbeon.org/oxf/xml/form-runner"
>
<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" />

<xsl:param name="query"/>
<xsl:param name="description"/>
<xsl:param name="descriptionEncoded"/>
<xsl:param name="xrdVersion"/>
<xsl:param name="useIssue" select="''false''"/>
<xsl:param name="echoURI" select="''/echo''"/>
<xsl:param name="logURI" select="''/saveQueryLog.action''"/>
<xsl:param name="pdfURI" select="''''"/>
<xsl:param name="basepath" select="''http://localhost:8080/misp2''"/>
<xsl:param name="language" select="''et''"/>
<xsl:param name="mail" select="''kasutaja@domeen.ee''"/>
<xsl:param name="mailEncryptAllowed" select="''false''"/>
<xsl:param name="mailSignAllowed" select="''false''"/>
<xsl:param name="mainServiceName" select="''''"/>
<!-- copy all nodes to proceed -->
<xsl:template match="*|@*|text()" name="copy">
  <xsl:copy>
    <xsl:apply-templates select="*|@*|text()"/>
  </xsl:copy>
</xsl:template>

<xsl:template match="xhtml:html">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:attribute name="lang"><xsl:value-of select="$language"/></xsl:attribute>  
      <xsl:apply-templates select="*|text()"/>
  </xsl:copy>
</xsl:template>  
  
<xsl:template match="xforms:switch">
  <xsl:copy>
    <div id="footer"><span id="footer-left" class="xforms-control xforms-input xforms-static xforms-readonly xforms-type-string"></span><span id="pagenumber"/></div>
    <xsl:apply-templates select="*|text()"/>
  </xsl:copy>
</xsl:template> 
 
<!-- replace classifier src with basepath -->
<xsl:template match="xforms:instance[ends-with(@id, ''.classifier'')]">
  <xsl:variable name="classifierURL" select="concat($basepath, ''/classifier?name='', substring-before(@id, ''.classifier''))"/>
  <xsl:copy>
    <xsl:apply-templates select="@*"/>
    <xsl:attribute name="src">
      <xsl:value-of select="$classifierURL"/>
    </xsl:attribute>
    <xsl:apply-templates select="*|text()"/>
  </xsl:copy>
</xsl:template>

<!-- add to submission logging function and add submission instance for XML button -->
<xsl:template match="xforms:submission[ends-with(@id, ''.submission'')]">
  <xsl:variable name="req" select="substring-before(@id, ''.submission'')"/>
    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()"/>
      <xforms:setvalue ref="instance(''temp'')/pdf/description" value="''{$descriptionEncoded}''" events:event="xforms-submit"/>
      <xforms:setvalue ref="instance(''temp'')/pdf/email" value="''{$mail}''" events:event="xforms-submit"/>
      <xforms:insert context="." origin="xxforms:set-session-attribute(''{$req}.output'', instance(''{$req}.output''))" events:event="xforms-submit-done"/>
	  <!-- Remove all xsi:nil elements, because Orbeon does not handle them as NULLs (element not represented) -->
      <xforms:delete nodeset="instance(''{substring-before(@id, ''.submission'')}.output'')//*[@xsi:nil = ''true'']" events:event="xforms-submit-done"/>
	  
    </xsl:copy>
  <xforms:submission id="{$req}.log" xxforms:show-progress="false"
    action="{$logURI}"
    ref="instance(''temp'')/queryLog"
    method="get"
    replace="none"/>
   <xforms:submission id="{$req}.pdf" xxforms:show-progress="false"
    action="{$pdfURI}&amp;case={$req}.response&amp;"
    ref="instance(''temp'')/pdf"
    method="get"
    replace="all"/>
  <xforms:submission id="{$req}.xml" xxforms:show-progress="false"
    action="{$echoURI}"
    ref="instance(''{$req}.output'')"
    method="post" 
	validate="false"
    replace="all"/>
</xsl:template>

<xsl:template match="xforms:instance[@id=''temp'']"/>
<!-- instance for encrypting the query -->
<xsl:template match="xforms:model">
  <xsl:copy>
    <xsl:apply-templates select="*|@*|text()"/>
    <xforms:instance id="temp">
      <temp>
        <relevant xsi:type="boolean">true</relevant>    
        <logStart/>
        <logEnd/>
        <queryLog>
          <userId/>
          <queryId/>
          <serviceName/>
          <mainServiceName/>
          <description/>
          <queryTimeSec/>
          <consumer/>
		  <unit/>
        </queryLog>
        <pdf>
          <description/>
          <sign xsi:type="boolean">false</sign>
          <encrypt xsi:type="boolean">false</encrypt>
          <sendPdfByMail xsi:type="boolean">false</sendPdfByMail>
          <email/>
        </pdf>
      </temp>
    </xforms:instance>
    <xforms:bind nodeset="instance(''temp'')/pdf/sendPdfByMail" type="xs:boolean"  />
    <xforms:bind nodeset="instance(''temp'')/pdf/sign" type="xs:boolean"  />
    <xforms:bind nodeset="instance(''temp'')/pdf/encrypt" type="xs:boolean"  />
    <xforms:action events:event="xforms-ready">
       <xforms:setfocus control="input-1" />
    </xforms:action>
  </xsl:copy>
</xsl:template>
          
<!-- Add XML and >>> buttons  (in simple query response)-->
<xsl:template match="xforms:case[ends-with(@id, ''.response'')]/xforms:group[@class=''actions'']">
  <xsl:variable name="form" select="substring-before(../@id, ''.response'')"/>
  <xsl:copy>    
    <xsl:apply-templates select="*|@*|text()"/>     
      <xforms:trigger id="{substring-before(../@id, ''.response'')}-buttons_trigger" class="button">
         <xforms:label xml:lang="et">Salvesta...</xforms:label>
         <xforms:label xml:lang="en">Save...</xforms:label>
         <xxforms:show events:event="DOMActivate" dialog="save-dialog-{substring-before(../@id, ''.response'')}"/>
      </xforms:trigger>
      <xxforms:dialog id="save-dialog-{substring-before(../@id, ''.response'')}" class="results-save-dialog" appearance="full" level="modal" close="true" draggable="true" visible="false" neighbor="{substring-before(../@id, ''.response'')}-buttons_trigger">
        <xforms:label xml:lang="et">Teenuse vastuse salvestamine</xforms:label>
        <xforms:label xml:lang="en">Service response saving</xforms:label>
        <xhtml:div id="save">
          <xhtml:div id="pdf">
            <xhtml:h2 xml:lang="et">Salvesta failina</xhtml:h2>
            <xhtml:h2 xml:lang="en">Save to file</xhtml:h2>
            <xforms:trigger class="button">
              <xforms:label>PDF</xforms:label>
              <xforms:setvalue ref="instance(''temp'')/pdf/sendPdfByMail" value="''false''"/>
              <xforms:send events:event="DOMActivate" submission="{substring-before(../@id, ''.response'')}.pdf"/>
            </xforms:trigger>
            <xforms:trigger class="button">
              <xforms:label>XML</xforms:label>
              <xforms:send events:event="DOMActivate" submission="{substring-before(../@id, ''.response'')}.xml"/>
            </xforms:trigger> 
          </xhtml:div>
          <xhtml:div id="email">
            <xforms:input ref="instance(''temp'')/pdf/email" id="email-input-{$form}">
				<xforms:label xml:lang="et">E-post</xforms:label>
				<xforms:label xml:lang="en">E-mail</xforms:label>
			</xforms:input>
            <xsl:if test="$mailSignAllowed">
              <xforms:input ref="instance(''temp'')/pdf/sign" id="sign-input-{$form}">
				<xforms:label xml:lang="et">Signeeritud</xforms:label>
				<xforms:label xml:lang="en">Signed</xforms:label>
			</xforms:input>
            </xsl:if>
            <xsl:if test="$mailEncryptAllowed">
              <xforms:input ref="instance(''temp'')/pdf/encrypt" id="encrypt-input-{$form}">
				<xforms:label xml:lang="et">Krüpteeritud</xforms:label>
				<xforms:label xml:lang="en">Encrypted</xforms:label>
			</xforms:input>
            </xsl:if>
            <xforms:trigger class="button">
              <xforms:label xml:lang="et">Saada PDF e-postile</xforms:label>
              <xforms:label xml:lang="en">Send PDF to e-mail</xforms:label>
              <xxforms:script events:event="DOMActivate">
                sign = ''false'';
                encrypt = ''false'';
                try{
                  emailInput = $("#email-input-<xsl:value-of select="$form"/>>input");
                  signInput = ORBEON.util.Dom.getElementById("sign-input-<xsl:value-of select="$form"/>");
                  encryptInput = ORBEON.util.Dom.getElementById("encrypt-input-<xsl:value-of select="$form"/>");
                 
                }catch(err){  
                  emailInput = $("#email-input-<xsl:value-of select="$form"/>>input");
                  signInput = ORBEON.util.Dom.get("sign-input-<xsl:value-of select="$form"/>");             
                  encryptInput = ORBEON.util.Dom.get("encrypt-input-<xsl:value-of select="$form"/>");
                }                 
                if(emailInput != null){
                   email = $("#email-input-<xsl:value-of select="$form"/>>input").val();
                <xsl:if test="$mailSignAllowed">
                   sign = ORBEON.xforms.Document.getValue("sign-input-<xsl:value-of select="$form"/>");
                </xsl:if>
                <xsl:if test="$mailEncryptAllowed">
                   encrypt = ORBEON.xforms.Document.getValue("encrypt-input-<xsl:value-of select="$form"/>");
                </xsl:if>
                }                
                sendPDFByMail("<xsl:value-of select="concat($form, ''.response'')"/>", email, sign, encrypt, "<xsl:value-of select="$descriptionEncoded"/>");
              </xxforms:script>
            </xforms:trigger>
          </xhtml:div>        
        </xhtml:div>
        <xforms:action events:event="xxforms-dialog-open">
          <xforms:setfocus control="{substring-before(../@id, ''.response'')}-buttons_trigger"/>
        </xforms:action>
      </xxforms:dialog>
  </xsl:copy>
</xsl:template>


<!-- invisible values for query logging -->
<xsl:template match="xforms:case[ends-with(@id, ''.request'')]">
  <xsl:param name="serviceName" select="substring-before(@id, ''.request'')"/>
  <xsl:copy>
    <xsl:apply-templates select="*|@*|text()"/>
   <xsl:if test="$useIssue=''true''">
       <xhtml:br/>
       <xforms:input ref="instance(''{$serviceName}.input'')//xrd:issue" class="issue">
        <xforms:label xml:lang="et">Toimik: </xforms:label>
        <xforms:label xml:lang="en">Issue: </xforms:label>
        <xforms:label xml:lang="ru">Toimik: </xforms:label>
       </xforms:input>
       <xforms:input ref="instance(''{$serviceName}.input'')//xtee:toimik" class="issue">
        <xforms:label xml:lang="et">Toimik: </xforms:label>
        <xforms:label xml:lang="en">Issue: </xforms:label>
        <xforms:label xml:lang="ru">Toimik: </xforms:label>
       </xforms:input>
       <br/>
     </xsl:if>
<!--    <fr:error-summary observer="{$serviceName}-xforms-request-group" id="{$serviceName}-xforms-error-summary">
      <fr:label xml:lang="et">Vormil esinevad vead: </fr:label>
    </fr:error-summary>-->
  </xsl:copy>
</xsl:template>
  
  
  <xsl:template match="xforms:case[ends-with(@id, ''.request'')]//xforms:input">
      <xsl:variable name="nodeset-ref" select="@ref"/>     
      <xsl:variable name="alert-et" select="xforms:alert[@xml:lang=''et'']"/>
      <xsl:variable name="alert-en" select="xforms:alert[@xml:lang=''en'']"/>
      <xsl:variable name="alert-ru" select="xforms:alert[@xml:lang=''ru'']"/>
      <xsl:variable name="alert-default" select="''Väli peab olema täidetud vastavalt reeglitele''"/>
      <xsl:choose>
        <xsl:when test="//xforms:bind[(@constraint!='''' or @required!='''') and @nodeset=$nodeset-ref]/@nodeset!=''''">
           <xsl:copy>
              <xsl:apply-templates select="*|@*"/>
              <xforms:alert><xsl:value-of select="$alert-default"/></xforms:alert>
              <xforms:alert xml:lang="et"><xsl:choose><xsl:when test="$alert-et!=''''"><xsl:value-of select="$alert-et"/></xsl:when><xsl:otherwise><xsl:value-of select="$alert-default"/></xsl:otherwise></xsl:choose></xforms:alert>
             <xforms:alert xml:lang="ru"><xsl:choose><xsl:when test="$alert-ru!=''''"><xsl:value-of select="$alert-ru"/></xsl:when><xsl:otherwise><xsl:value-of select="$alert-default"/></xsl:otherwise></xsl:choose></xforms:alert>
             <xforms:alert xml:lang="en"><xsl:choose><xsl:when test="$alert-en!=''''"><xsl:value-of select="$alert-en"/></xsl:when><xsl:otherwise><xsl:value-of select="$alert-default"/></xsl:otherwise></xsl:choose></xforms:alert>
            </xsl:copy> 
          </xsl:when>
          <xsl:otherwise>
            <xsl:copy>
              <xsl:apply-templates select="*|@*"/>
            </xsl:copy> 
          </xsl:otherwise>
      </xsl:choose>  
   </xsl:template>  
  
<!--<xsl:template match="xforms:submit[ends-with(@submission, ''.submission'')]">
  <xsl:variable name="form" select="substring-before(@submission, ''.submission'')"/>
  <xsl:copy>
    <xsl:apply-templates select="*|@*|text()"/>
    <xforms:dispatch events:event="DOMActivate" name="fr-visit-all" targetid="{$form}-xforms-error-summary"/>
  </xsl:copy>
</xsl:template>
  
<xsl:template match="xforms:case[ends-with(@id, ''.request'')]//xforms:group[@ref=''request''] | xforms:case[ends-with(@id, ''.request'')]//xforms:group[@ref=''keha'']">
  <xsl:copy>
   <xsl:apply-templates select="@*"/>
   <xsl:attribute name="id">
    <xsl:value-of select="concat(substring-before((./ancestor::xforms:case[ends-with(@id, ''request'')]/@id), ''.request''), ''-xforms-request-group'')"/>
   </xsl:attribute>
   <xsl:apply-templates select="*|text()"/>
 </xsl:copy>
</xsl:template>
   -->  
</xsl:stylesheet>', 10, NOW(), 'debug', 0, true, NULL, 'http://www.aktors.ee/support/xroad/xsl/debug.xsl');

INSERT INTO misp2.xslt (query_id, xsl, priority, created, name, form_type, in_use, producer_id, url) VALUES (NULL, '<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xforms="http://www.w3.org/2002/xforms"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:events="http://www.w3.org/2001/xml-events"
  xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
  xmlns:xrd="http://x-road.ee/xsd/x-road.xsd"
  xmlns:xxforms="http://orbeon.org/oxf/xml/xforms"
  xmlns:xtee="http://x-tee.riik.ee/xsd/xtee.xsd"
  xmlns:xrd6="http://x-road.eu/xsd/xroad.xsd"
  xmlns:iden="http://x-road.eu/xsd/identifiers"
  xmlns:repr="http://x-road.eu/xsd/representation.xsd">
  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" />
  <xsl:param name="producer"/>
  <xsl:param name="query"/>
  <xsl:param name="userId"/>
  <xsl:param name="messageMediator"/>
  <xsl:param name="orgCode"/>
  <xsl:param name="queryId"/>
  <xsl:param name="suborgCode"/>
  <xsl:param name="xrdVersion"/>
  <xsl:param name="basepath"/>
  <xsl:param name="descriptionEncoded"/>    
  <xsl:param name="description"/>
  <xsl:param name="portalName"/>
  <xsl:param name="authenticator"/>
  <xsl:param name="userName"/>
  <xsl:param name="userFirstName"/>
  <xsl:param name="userLastName"/>  
  <xsl:param name="version"/>
  <xsl:param name="xroad6-client-xroad-instance"/>
  <xsl:param name="xroad6-client-member-class"/>
  <xsl:param name="xroad6-client-member-code"/>
  <xsl:param name="xroad6-client-subsystem-code"/>
  <xsl:param name="xroad6-represented-party-class"/>
  <xsl:param name="xroad6-represented-party-code"/>
  <xsl:param name="xroad6-represented-party-name"/>
  
  <xsl:template match="*|@*|text()">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="xrd:userId|xtee:isikukood">
    <xsl:copy>
      <xsl:value-of select="$userId"/>
    </xsl:copy>
  </xsl:template>
    
  <xsl:template match="xrd6:client/iden:xRoadInstance">
    <xsl:copy>
      <xsl:value-of select="$xroad6-client-xroad-instance"/>
    </xsl:copy>
  </xsl:template>
    
  <xsl:template match="xrd6:client/iden:memberClass">
    <xsl:copy>
      <xsl:value-of select="$xroad6-client-member-class"/>
    </xsl:copy>
  </xsl:template>
    
  <xsl:template match="xrd6:client/iden:memberCode">
    <xsl:copy>
      <xsl:value-of select="$xroad6-client-member-code"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="xrd6:client/iden:subsystemCode">
    <xsl:copy>
      <xsl:value-of select="$xroad6-client-subsystem-code"/>
    </xsl:copy>
  </xsl:template>

 
  <!-- Remove representedPartyElement if it exists -->
  <xsl:template match="SOAP-ENV:Header/repr:representedParty"/>
  <!-- Append represented party element with class and code elements if the values are given as parameters -->
  <xsl:template match="SOAP-ENV:Header[$xroad6-represented-party-class and $xroad6-represented-party-code]">
     <!-- Copy the element -->
    <xsl:copy>
      <xsl:apply-templates select="@* | *"/> 
      <!-- Add new node (or whatever else you wanna do) -->
      <repr:representedParty>
        <repr:partyClass><xsl:value-of select="$xroad6-represented-party-class"/></repr:partyClass>
        <repr:partyCode><xsl:value-of select="$xroad6-represented-party-code"/></repr:partyCode>
      </repr:representedParty>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="xrd:consumer">
    <xsl:copy>
      <xsl:value-of select="$orgCode"/>
    </xsl:copy>
    <xsl:if test="$suborgCode!=''''">
      <xrd:unit>
        <xsl:value-of select="$suborgCode"/>
      </xrd:unit>
    </xsl:if>
  </xsl:template>

  <xsl:template match="xtee:asutus">
    <xsl:copy>
      <xsl:value-of select="$orgCode"/>
    </xsl:copy>
    <xsl:if test="$suborgCode!=''''">
      <xtee:allasutus>
        <xsl:value-of select="$suborgCode"/>
      </xtee:allasutus>
    </xsl:if>
  </xsl:template>
    
    
  <xsl:template match="xrd:id|xtee:id">
    <xsl:copy>
      <xsl:value-of select="$queryId"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="xtee:ametnik">
    <xsl:copy>
      <xsl:value-of select="substring($userId,3)"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="xtee:autentija|xrd:authenticator">
    <xsl:copy>
      <xsl:value-of select="$authenticator"/>
    </xsl:copy>
  </xsl:template>
    
  <xsl:template match="xtee:ametniknimi|xrd:userName">
    <xsl:copy>
      <xsl:value-of select="$userName"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="xforms:submission[ends-with(@id, ''.submission'')]">
   <xsl:copy>
      <xsl:apply-templates select="@*"/>
     <xsl:choose>
      <xsl:when test="//xforms:bind[@type=''xforms:base64Binary''] or //xforms:bind[@type=''xforms:hexBinary'']"> 
        <xsl:attribute name="action">
          <xsl:value-of select="concat($messageMediator, ''&amp;attachment=true'')"/>
        </xsl:attribute>
       </xsl:when>
       <xsl:otherwise>
         <xsl:attribute name="action">
            <xsl:value-of select="$messageMediator"/>
         </xsl:attribute>
       </xsl:otherwise>     
     </xsl:choose>
      <xsl:apply-templates select="*|text()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="xforms:model/xforms:instance[@id=''temp'']/temp">
    <xsl:copy>      
      <xsl:apply-templates select="*|@*|text()"/>
      <xsl:element name="userFirstName"><xsl:value-of select="$userFirstName"/></xsl:element>
      <xsl:element name="userLastName"><xsl:value-of select="$userLastName"/></xsl:element>
      <xsl:if test="$xroad6-represented-party-name != ''''"> 
        <xsl:element name="unitName"><xsl:value-of select="$xroad6-represented-party-name"/></xsl:element>
      </xsl:if>
    </xsl:copy>
  </xsl:template>  
</xsl:stylesheet>', 20, NOW(), 'headers', 0, true, NULL, 'http://www.aktors.ee/support/xroad/xsl/headers.xsl');
INSERT INTO misp2.xslt (query_id, xsl, priority, created, name, form_type, in_use, producer_id, url) VALUES (NULL, '<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" />
<xsl:param name="language" select="''et''"/>

<!-- Default template, that copies node to output and applies templates to all child nodes. -->
<xsl:template match="@*|*|text()">
  <!--xsl:message><xsl:value-of select="name()" /></xsl:message-->
  <xsl:copy>
    <xsl:apply-templates select="*|@*|text()"/>
  </xsl:copy>
</xsl:template>

<xsl:template match="*[@xml:lang != $language]"/>

</xsl:stylesheet>', 30, NOW(), 'i18n', 0, true, NULL, 'http://www.aktors.ee/support/xroad/xsl/i18n.xsl');
--COALESCE((SELECT in_use FROM misp2.xslt where name='i18n'), false)

INSERT INTO misp2.xslt (query_id, xsl, priority, created, name, form_type, in_use, producer_id, url) VALUES (NULL, '<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:xforms="http://www.w3.org/2002/xforms"
    xmlns:events="http://www.w3.org/2001/xml-events"
    xmlns:xxforms="http://orbeon.org/oxf/xml/xforms"
    xmlns:exf="http://www.exforms.org/exf/1-0"
	xmlns:xs="http://www.w3.org/2001/XMLSchema"
>
<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" />

<!-- Default template, that copies node to output and applies templates to all child nodes. -->
<xsl:template match="@*|*|text()">
  <!--xsl:message><xsl:value-of select="name()" /></xsl:message-->
  <xsl:copy>
    <xsl:apply-templates select="*|@*|text()"/>
  </xsl:copy>
</xsl:template>

<!-- Dummy template to get xxforms namespace mentioned at root level. -->
<xsl:template match="xhtml:html">
  <xsl:copy>
    <xsl:namespace name="xxforms" select="''http://orbeon.org/oxf/xml/xforms''"/>
    <xsl:namespace name="exf" select="''http://www.exforms.org/exf/1-0''"/>
    <xsl:namespace name="xsd" select="''http://www.w3.org/2001/XMLSchema''"/>
    <xsl:apply-templates select="@* | *">
      <xsl:with-param name="heading-level" select="2" tunnel="yes" />
    </xsl:apply-templates>
  </xsl:copy>
</xsl:template>

<!-- Creates heading for a group label. -->
<xsl:template match="xforms:group" mode="group-label-as-heading">
  <xsl:param name="heading-level" tunnel="yes" />
  <xsl:if test="xforms:label">
    <!-- Generate id for the group that can be referenced by label. -->
    <xsl:if test="not(@id)">
      <xsl:attribute name="id" select="generate-id()"/>
    </xsl:if>
    <xsl:element name="h{$heading-level}" namespace="http://www.w3.org/1999/xhtml">
      <xsl:apply-templates select="." mode="copy-label-only" />
    </xsl:element>
  </xsl:if>
</xsl:template>

<!-- Copies only label. -->
<xsl:template match="*" mode="copy-label-only">
  <xsl:choose>
    <!-- Label of trigger is not copied. -->
    <xsl:when test="local-name() = (''trigger'',''submit'') and namespace-uri() = ''http://www.w3.org/2002/xforms''">
    </xsl:when>
    <!-- Add for attribute to all labels. -->
    <xsl:otherwise>
      <xsl:for-each select="xforms:label">
        <xsl:copy>
          <xsl:attribute name="for" select="if (../@id) then ../@id else generate-id(..)"/>
          <xsl:copy-of select="@* | * | text()" />
        </xsl:copy>
      </xsl:for-each>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Creates xforms:output, that outputs the same as label. -->
<xsl:template match="*" mode="copy-header-only">
  <xsl:choose>
    <!-- Label of trigger is not copied. -->
    <xsl:when test="local-name() = (''trigger'',''submit'') and namespace-uri() = ''http://www.w3.org/2002/xforms''">
    </xsl:when>
    <!-- HACK: Add a dummy <xforms:output> around label and help. -->
    <xsl:otherwise>
      <xforms:output value="''''">
        <xsl:copy-of select="xforms:label | xforms:help" />
      </xforms:output>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Copies a node and all of its children except xforms:label. -->
<xsl:template match="*" mode="copy-all-but-label">
  <xsl:variable name="temp">
    <xsl:choose>
      <!-- Trigger is copied intact. -->
      <xsl:when test="local-name() = (''trigger'',''submit'') and namespace-uri(..) = ''http://www.w3.org/2002/xforms''">
        <xsl:copy-of select="." />
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <!-- Generate id for the control that can be referenced by label. -->
          <xsl:if test="not(@id)">
            <xsl:attribute name="id" select="generate-id()"/>
          </xsl:if>
          <xsl:copy-of select="@* | (* except xforms:label) | text()" />
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:apply-templates select="$temp" />
</xsl:template>

<!-- Copies a node and all of its children except xforms:label and xforms:help. -->
<xsl:template match="*" mode="copy-all-but-header">
  <xsl:variable name="temp">
    <xsl:choose>
      <!-- Trigger is copied intact. -->
      <xsl:when test="local-name() = (''trigger'',''submit'') and namespace-uri(..) = ''http://www.w3.org/2002/xforms''">
        <xsl:copy-of select="." />
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:copy-of select="@* | (* except (xforms:label | xforms:help)) | text()" />
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:apply-templates select="$temp" />
</xsl:template>

<!-- Creates vertical table for group with appearance="full". -->
<xsl:template match="xforms:group[@appearance=''full'']" name="group-full">
  <xsl:param name="heading-level" tunnel="yes" />
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="." mode="group-label-as-heading"/>
    <xhtml:table class="group-full">
      <xhtml:tbody>
        <xsl:for-each select="* except (xforms:label | xforms:help | xforms:hint | xforms:alert)">
          <xhtml:tr>
            <xsl:if test="@ref or @nodeset">
              <xsl:attribute name="class" select="concat(''{if (not(.['', if (@ref) then @ref else @nodeset, ''])) then ''''xforms-disabled-subsequent'''' else ''''''''}'')" />
            </xsl:if>
            <xsl:choose>
              <xsl:when test="namespace-uri() != ''http://www.w3.org/2002/xforms'' or local-name() = (''trigger'', ''submit'', ''repeat'') or (local-name() = ''group'' and not(xforms:label))">
                <xhtml:td class="group-full-value" colspan="2">
                  <xsl:apply-templates select=".">
                    <xsl:with-param name="heading-level" select="if (../xforms:label) then $heading-level + 1 else $heading-level" tunnel="yes" />
                  </xsl:apply-templates>
                </xhtml:td>
              </xsl:when>
              <xsl:otherwise>
                <xhtml:th class="group-full-label">
                  <xsl:apply-templates select="." mode="copy-label-only" />
                </xhtml:th>
                <xhtml:td class="group-full-value">
                  <xsl:apply-templates select="." mode="copy-all-but-label">
                    <xsl:with-param name="heading-level" select="if (../xforms:label) then $heading-level + 1 else $heading-level" tunnel="yes" />
                  </xsl:apply-templates>
                </xhtml:td>
              </xsl:otherwise>
            </xsl:choose>
          </xhtml:tr>
        </xsl:for-each>
      </xhtml:tbody>
    </xhtml:table>
  </xsl:copy>
</xsl:template>

<!-- Creates horizontal table for group with appearance="compact". -->
<xsl:template match="xforms:group[@appearance=''compact'']" name="group-compact">
  <xsl:param name="heading-level" tunnel="yes" />
  <!--xsl:message select="concat(''xforms:group[@ref='',@ref,''] and @appearance=compact'')" /-->
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="." mode="group-label-as-heading"/>
    <xhtml:table class="group-compact">
      <xhtml:thead>
        <xhtml:tr>
          <xsl:for-each select="* except (xforms:label | xforms:help | xforms:hint | xforms:alert)">
            <xhtml:th class="group-compact-label">
              <xsl:apply-templates select="." mode="copy-label-only" />
            </xhtml:th>
          </xsl:for-each>
        </xhtml:tr>
      </xhtml:thead>
      <xhtml:tbody>
        <xhtml:tr>
          <xsl:for-each select="* except (xforms:label | xforms:help | xforms:hint | xforms:alert)">
            <xhtml:td class="group-compact-value">
              <xsl:apply-templates select="." mode="copy-all-but-label">
                <xsl:with-param name="heading-level" select="if (../xforms:label) then $heading-level + 1 else $heading-level" tunnel="yes" />
              </xsl:apply-templates>
            </xhtml:td>
          </xsl:for-each>
        </xhtml:tr>
      </xhtml:tbody>
    </xhtml:table>
  </xsl:copy>
</xsl:template>

<!-- No specific layout when appearance="minimal". -->
<xsl:template match="xforms:group[@appearance=''minimal'']" name="group-minimal">
  <xsl:param name="heading-level" tunnel="yes" />
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="." mode="group-label-as-heading"/>
    <xsl:for-each select="* except (xforms:label | xforms:help | xforms:hint | xforms:alert)">
      <xhtml:span class="group-minimal-field">
        <xsl:apply-templates select=".">
          <xsl:with-param name="heading-level" select="if (../xforms:label) then $heading-level + 1 else $heading-level" tunnel="yes" />
        </xsl:apply-templates>
      </xhtml:span>
    </xsl:for-each>
  </xsl:copy>
</xsl:template>

<!-- Determines best layout for xforms:group with no appearance attribute. -->
<xsl:template match="xforms:group">
  <!--xsl:message select="concat(''xforms:group[@ref='',@ref,'']'')" /-->
  <xsl:choose>
    <!-- Ignore xforms:groups with class="help". -->
    <xsl:when test="@class = ''help''">
      <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
      </xsl:copy>
    </xsl:when>
    <!-- If all children are missing xforms:label, then minimal appearance is better choice than full. -->
    <xsl:when test="count(xforms:*[xforms:label]) = 0">
      <xsl:call-template name="group-minimal" />
    </xsl:when>
    <!-- If there are more than one children, that are common UI components, then use full group. -->
    <xsl:when test="count(xforms:* except (xforms:label | xforms:help | xforms:hint | xforms:alert | xforms:group | xforms:repeat | xforms:trigger | xforms:submit)) > 1">
      <xsl:call-template name="group-full" />
    </xsl:when>
    <!-- Otherwise minimal appearance. -->
    <xsl:otherwise>
      <xsl:call-template name="group-minimal" />
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Creates vertical table for repeats with appearance="full". -->
<xsl:template match="xforms:repeat[@appearance=''full'']" name="repeat-full">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xhtml:table class="repeat-full">
      <xhtml:tbody>
        <xsl:for-each select="* except (xforms:label | xforms:help | xforms:hint | xforms:alert)">
          <xhtml:tr>
            <xsl:if test="@ref or @nodeset">
              <xsl:attribute name="class" select="concat(''{if (not(.['', if (@ref) then @ref else @nodeset, ''])) then ''''xforms-disabled-subsequent'''' else ''''''''}'')" />
            </xsl:if>
            <xhtml:th class="repeat-full-label">
              <xsl:apply-templates select="." mode="copy-label-only" />
            </xhtml:th>
            <xhtml:td class="repeat-full-value">
              <xsl:apply-templates select="." mode="copy-all-but-label" />
            </xhtml:td>
          </xhtml:tr>
        </xsl:for-each>
      </xhtml:tbody>
    </xhtml:table>
  </xsl:copy>
</xsl:template>

<!-- Creates horizontal table for repeats with appearance="compact". -->
<xsl:template match="xforms:repeat[@appearance=''compact'']" name="repeat-compact">
  <!--xsl:message select="concat(''xforms:repeat[@nodeset='',@nodeset,''] and @appearance=compact'')" /-->
  <xhtml:div class="{{if (not({@nodeset})) then '' xforms-disabled-subsequent'' else ''''}}">
    <xhtml:table class="repeat-compact">
      <xhtml:thead>
        <xhtml:tr>
          <xsl:for-each select="* except (xforms:label | xforms:help | xforms:hint | xforms:alert | xxforms:variable)">
            <xhtml:th class="repeat-compact-label">
              <xsl:apply-templates select="." mode="copy-header-only" />
            </xhtml:th>
          </xsl:for-each>
        </xhtml:tr>
      </xhtml:thead>
      <xsl:copy>
        <xsl:copy-of select="@*" />
        <xhtml:tbody>
          <xhtml:tr>
            <xsl:for-each select="xxforms:variable">
                <xsl:apply-templates select="." mode="copy-all-but-header" />
            </xsl:for-each>
            <xsl:for-each select="* except (xxforms:variable | xforms:label | xforms:help | xforms:hint | xforms:alert)">
              <xhtml:td class="repeat-compact-value">
                <xsl:apply-templates select="." mode="copy-all-but-header" />
              </xhtml:td>
            </xsl:for-each>     
            <xsl:for-each select="xhtml:tr">
                <xsl:apply-templates select="." mode="copy-all-but-header" />
            </xsl:for-each>
          </xhtml:tr>
        </xhtml:tbody>
      </xsl:copy>
    </xhtml:table>
  </xhtml:div>
</xsl:template>

<!-- Creates horizontal table for repeats with appearance="small". -->
<xsl:template match="xforms:repeat[@appearance='''']" name="repeat-small">
  <!--xsl:message select="concat(''xforms:repeat[@nodeset='',@nodeset,''] and @appearance=compact'')" /-->
  <xhtml:div class="{{if (not({@nodeset})) then '' xforms-disabled-subsequent'' else ''''}}">
    <xhtml:table class="repeat-small">
      <xhtml:thead>
        <xhtml:tr>
          <xsl:for-each select="* except (xforms:label | xforms:help | xforms:hint | xforms:alert | xxforms:variable)">
            <xhtml:th class="repeat-small-label">
              <xsl:apply-templates select="." mode="copy-header-only" />
            </xhtml:th>
          </xsl:for-each>
        </xhtml:tr>
      </xhtml:thead>
      <xsl:copy>
        <xsl:copy-of select="@*" />
        <xhtml:tbody>
          <xhtml:tr>
            <xsl:for-each select="xxforms:variable">
                <xsl:apply-templates select="." mode="copy-all-but-header" />
            </xsl:for-each>
            <xsl:for-each select="* except (xxforms:variable | xforms:label | xforms:help | xforms:hint | xforms:alert)">
              <xhtml:td class="repeat-small-value">
                <xsl:apply-templates select="." mode="copy-all-but-header" />
              </xhtml:td>
            </xsl:for-each>            
          </xhtml:tr>
        </xhtml:tbody>
      </xsl:copy>
    </xhtml:table>
  </xhtml:div>
</xsl:template>

<!-- Every repeat instance in separate block when appearance="minimal". -->
<xsl:template match="xforms:repeat[@appearance=''minimal'']" name="repeat-minimal">
  <!--xsl:message select="concat(''xforms:repeat[@nodeset='',@nodeset,'' and @appearance=minimal]'')" /-->
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:for-each select="* except (xforms:label | xforms:help | xforms:hint | xforms:alert)">
      <xhtml:div>
        <xsl:apply-templates select="."/>
      </xhtml:div>
    </xsl:for-each>
  </xsl:copy>
</xsl:template>

<!-- Determines best layout for xforms:repeat when there is no appearance attribute. -->
<xsl:template match="xforms:repeat">
  <!--xsl:message select="concat(''xforms:repeat[@nodeset='',@nodeset,'']'')" /-->
  <xsl:choose>
    <!-- When there is one child then minimal appearance. -->
    <xsl:when test="count(*) = 1">
      <xsl:call-template name="repeat-minimal" />
    </xsl:when>
    <!-- When there are 3-4 children, then use compact appearance. -->
    <xsl:when test="count(*) &gt; 2 and count(*) &lt; 6">
      <xsl:call-template name="repeat-small" />
    </xsl:when>
    <!-- When there are 5-7 children, then use compact appearance. -->
    <xsl:when test="count(*) &gt; 5 and count(*) &lt; 8">
      <xsl:call-template name="repeat-compact" />
    </xsl:when>
    <!-- Otherwise use full appearance. -->
    <xsl:otherwise>
      <xsl:call-template name="repeat-full" />
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Set texts and lookup instances read-only, this should speed up form a bit. -->
<xsl:template match="xforms:instance[ends-with(@id, ''texts'') or starts-with(@id, ''lookup'')]">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:attribute name="xxforms:readonly" select="''true''" />
    <xsl:apply-templates />
  </xsl:copy>
</xsl:template>

<!-- Set classifier instances as read-only and cached. -->
<xsl:template match="xforms:instance[ends-with(@id, ''classifier'')]">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:attribute name="xxforms:readonly" select="''true''" />
    <xsl:attribute name="xxforms:cache" select="''true''" />
    <xsl:apply-templates />
  </xsl:copy>
</xsl:template>

<xsl:template match="xforms:bind[@type=''xforms:float''] | xforms:bind[@type=''xforms:double'']">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:attribute name="readonly" select="''false''" />
    <xsl:attribute name="calculate" select="''if (translate(., '''','''', ''''.'''') castable as xs:double) then format-number(xs:decimal(xs:double(translate(., '''','''', ''''.''''))), ''''###0.000'''') else ''''''''''" />
    <xsl:apply-templates />
  </xsl:copy>
</xsl:template>
      
<xsl:template match="xforms:bind[@type=''xforms:decimal'']">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:attribute name="readonly" select="''false''" />
    <xsl:attribute name="calculate" select="''if (translate(., '''','''', ''''.'''') castable as xs:double) then format-number(xs:decimal(xs:double(translate(., '''','''', ''''.''''))), ''''###0.00'''') else ''''''''''" />
    <xsl:apply-templates />
  </xsl:copy>
</xsl:template>
      
<xsl:template match="xforms:bind[@type=''xforms:integer'']">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:attribute name="readonly" select="''false''" />
    <xsl:attribute name="calculate" select="''if (translate(., '''','''', ''''.'''') castable as xs:double) then format-number(xs:decimal(xs:double(translate(., '''','''', ''''.''''))), ''''###0'''') else ''''''''''" />
    <xsl:apply-templates />
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>', 40, NOW(), 'orbeon', 0, true, NULL, 'http://www.aktors.ee/support/xroad/xsl/orbeon.xsl');

INSERT INTO misp2.xslt (query_id, xsl, priority, created, name, form_type, in_use, producer_id, url) VALUES (NULL, '<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xforms="http://www.w3.org/2002/xforms"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:events="http://www.w3.org/2001/xml-events"
  xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
  xmlns:xxforms="http://orbeon.org/oxf/xml/xforms">
  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" />

  <xsl:template match="*|@*|text()" name="copy">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()"/>
    </xsl:copy>
  </xsl:template>
   <xsl:template match="xforms:instance[ends-with(@id, ''.input'')]//*">
    <xsl:variable name="nodeset-ref" select="name()"/>
    <xsl:choose>
	  <xsl:when test="//xforms:bind[@type=''xforms:hexBinary'' and @nodeset=$nodeset-ref]">
	    <xsl:copy>
          <xsl:apply-templates select="*|@*|text()"/>
          <xsl:attribute name="hexBinaryFileType">
            <xsl:value-of select="''true''"/>
          </xsl:attribute>  
        </xsl:copy>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:apply-templates select="*|@*|text()"/>
        </xsl:copy> 
      </xsl:otherwise>
    </xsl:choose>
   </xsl:template>
   <xsl:template match="xforms:bind[@type=''xforms:hexBinary'']">
     <xsl:copy>      
       <xsl:apply-templates select="@*"/>
       <xsl:attribute name="type">
         <xsl:value-of select="''xforms:anyURI''"/>
       </xsl:attribute>  
       <xsl:apply-templates select="*|text()"/>
     </xsl:copy>
   </xsl:template>
   
    <xsl:template match="xforms:case[ends-with(@id, ''.response'')]//xforms:trigger[@ref]">
      <xsl:variable name="nodeset-ref" select="@ref"/>
	  <!-- Find itself or first ancestor that is not ''.'', because ''.'' does not mach xforms:bind element and file download content is not replaced -->
      <xsl:variable name="nodeset-name" select="if(@ref = ''.'') then ancestor::*[@ref and @ref != ''.''][1]/@ref else @ref"/>
      <xsl:variable name="label-et" select="xforms:label[@xml:lang=''et'']"/>
      <xsl:variable name="label-en" select="xforms:label[@xml:lang=''en'']"/>
      <xsl:variable name="label-ru" select="xforms:label[@xml:lang=''ru'']"/>
      <xsl:variable name="label-default" select="''Laadi alla''"/>
      <!--DEBUG: <xhtml:script>alert("type-count: <xsl:value-of select="count(//xforms:bind[@type=''xforms:base64Binary''])"/> \nnodeset: <xsl:value-of select="//xforms:bind[@type=''xforms:base64Binary'']/@nodeset"/> nodeset-name: <xsl:value-of select="$nodeset-name"/>");</xhtml:script> -->
       <xsl:choose>
        <xsl:when test="//xforms:bind[@type=''xforms:base64Binary'' and @nodeset=$nodeset-name]">  
          <!--DEBUG: <xhtml:script>alert("2");</xhtml:script>-->  
           <xforms:output ref="{$nodeset-ref}" appearance="xxforms:download">
            <xforms:filename ref="replace(@filename | ../filename, ''&#34;'', '''')"/>
            <xforms:label xml:lang="et"><xsl:choose><xsl:when test="$label-et!=''''"><xsl:value-of select="$label-et"/></xsl:when><xsl:otherwise><xsl:value-of select="$label-default"/></xsl:otherwise></xsl:choose></xforms:label>
            <xforms:label xml:lang="ru"><xsl:choose><xsl:when test="$label-ru!=''''"><xsl:value-of select="$label-ru"/></xsl:when><xsl:otherwise><xsl:value-of select="$label-default"/></xsl:otherwise></xsl:choose></xforms:label>
            <xforms:label xml:lang="en"><xsl:choose><xsl:when test="$label-en!=''''"><xsl:value-of select="$label-en"/></xsl:when><xsl:otherwise><xsl:value-of select="$label-default"/></xsl:otherwise></xsl:choose></xforms:label>
            <xforms:label><xsl:value-of select="$label-default"/></xforms:label>
         </xforms:output> 
        </xsl:when>
        <xsl:otherwise>
            <xsl:copy>
              <xsl:apply-templates select="*|@*"/>
            </xsl:copy> 
          </xsl:otherwise>
      </xsl:choose>  
    </xsl:template>
    
    <xsl:template match="xforms:case[ends-with(@id, ''.response'')]//xforms:output[@ref]">
      <xsl:variable name="nodeset-ref" select="@ref"/> 
      <xsl:variable name="label-et" select="xforms:label[@xml:lang=''et'']"/>
      <xsl:variable name="label-en" select="xforms:label[@xml:lang=''en'']"/>
      <xsl:variable name="label-ru" select="xforms:label[@xml:lang=''ru'']"/>
      <xsl:variable name="label-default" select="''Laadi alla''"/>
      <xsl:choose>
        <xsl:when test="//xforms:bind[@type=''xforms:base64Binary'' and @nodeset=$nodeset-ref]/@nodeset!='''' and not(contains(@mediatype,  ''image''))">
           <xforms:output ref="{$nodeset-ref}" appearance="xxforms:download">
            <xforms:filename ref="@filename | ../filename"/>
            <xforms:label xml:lang="et"><xsl:choose><xsl:when test="$label-et!=''''"><xsl:value-of select="$label-et"/></xsl:when><xsl:otherwise><xsl:value-of select="$label-default"/></xsl:otherwise></xsl:choose></xforms:label>
            <xforms:label xml:lang="ru"><xsl:choose><xsl:when test="$label-ru!=''''"><xsl:value-of select="$label-ru"/></xsl:when><xsl:otherwise><xsl:value-of select="$label-default"/></xsl:otherwise></xsl:choose></xforms:label>
            <xforms:label xml:lang="en"><xsl:choose><xsl:when test="$label-en!=''''"><xsl:value-of select="$label-en"/></xsl:when><xsl:otherwise><xsl:value-of select="$label-default"/></xsl:otherwise></xsl:choose></xforms:label>
            <xforms:label><xsl:value-of select="$label-default"/></xforms:label>
           </xforms:output>
          </xsl:when>
          <xsl:otherwise>
            <xsl:copy>
              <xsl:apply-templates select="*|@*"/>
            </xsl:copy> 
          </xsl:otherwise>
      </xsl:choose>  
   </xsl:template>
</xsl:stylesheet>', 50, NOW(), 'attachments', 0, true, NULL, 'http://www.aktors.ee/support/xroad/xsl/attachments.xsl');
