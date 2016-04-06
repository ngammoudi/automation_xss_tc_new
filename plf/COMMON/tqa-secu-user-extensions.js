/*
 (C) Copyright MetaCommunications, Inc. 2006.
     http://www.meta-comm.com
     http://engineering.meta-comm.com

Distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND.

Unified file of user contributed extensions in following order
  a) flowcontrol/goto_sel08.js
  b) includeCommand4IDE_1_3/includeCommand_2.3.js
  c) datadriven_v0.2/datadriven_v0.2-core.js
*/

function map_list( list, for_func, if_func )
    {
    var mapped_list = [];
    for ( var i = 0; i < list.length; ++i )
        {
        var x = list[i];
        if( null == if_func || if_func( i, x ) ) 
            mapped_list.push( for_func( i, x ) );
        }
    return mapped_list;
    }

    
// Modified to initialize GoTo labels/cycles list
HtmlRunnerTestLoop.prototype.old_initialize = HtmlRunnerTestLoop.prototype.initialize

HtmlRunnerTestLoop.prototype.initialize = function(htmlTestCase, metrics, seleniumCommandFactory)
    {
    this.gotoLabels  = {};
    this.whileLabels = { ends: {}, whiles: {} };
    
    this.old_initialize(htmlTestCase, metrics, seleniumCommandFactory);
    
    this.initialiseLabels();
    }

HtmlRunnerTestLoop.prototype.initialiseLabels = function()
    {
    var command_rows = map_list( this.htmlTestCase.getCommandRows() 
                               , function(i, x) { 
                                    return x.getCommand()
                                    }
                               );

    var cycles = [];
    for( var i = 0; i < command_rows.length; ++i )
        {
        switch( command_rows[i].command.toLowerCase() )
            {
            case "label":
                this.gotoLabels[ command_rows[i].target ] = i;
                break;
            case "while":
            case "endwhile":
                cycles.push( [command_rows[i].command.toLowerCase(), i] )
                break;
            }
        }        
        
    var i = 0;
    while( cycles.length )
        {
        if( i >= cycles.length )
            throw new Error( "non-matching while/endWhile found" );
            
        switch( cycles[i][0] )
            {
            case "while":
                if(    ( i+1 < cycles.length ) 
                    && ( "endwhile" == cycles[i+1][0] )
                    )
                    {
                    // pair found
                    this.whileLabels.ends[ cycles[i+1][1] ] = cycles[i][1]
                    this.whileLabels.whiles[ cycles[i][1] ] = cycles[i+1][1]
                    
                    cycles.splice( i, 2 );
                    i = 0;
                    }
                else
                    ++i;
                break;
            case "endwhile":
                ++i;
                break;
            }
        }
                    
    }    

HtmlRunnerTestLoop.prototype.continueFromRow = function( row_num ) 
    {
    if(    row_num == undefined
        || row_num == null
        || row_num < 0
        )
        throw new Error( "Invalid row_num specified." );
        
    this.htmlTestCase.nextCommandRowIndex = row_num;
    }
    


// do nothing. simple label
Selenium.prototype.doLabel      = function(){};

Selenium.prototype.doGotolabel  = function( label ) {

    if( undefined == htmlTestRunner.currentTest.gotoLabels[label] ) 
        throw new Error( "Specified label '" + label + "' is not found." );
    
    htmlTestRunner.currentTest.continueFromRow( htmlTestRunner.currentTest.gotoLabels[ label ] );
    };
    
Selenium.prototype.doGoto = Selenium.prototype.doGotolabel;


Selenium.prototype.doGotoIf = function( condition, label ) {
    if( eval(condition) ) 
        this.doGotolabel( label );
    }


    
Selenium.prototype.doWhile = function( condition ) {
    if( !eval(condition) )
        {
        var last_row = htmlTestRunner.currentTest.htmlTestCase.nextCommandRowIndex - 1
        var end_while_row = htmlTestRunner.currentTest.whileLabels.whiles[ last_row ]
        if( undefined == end_while_row ) 
            throw new Error( "Corresponding 'endWhile' is not found." );
        
        htmlTestRunner.currentTest.continueFromRow( end_while_row + 1 );
        }
    }


Selenium.prototype.doEndWhile = function() {
    var last_row = htmlTestRunner.currentTest.htmlTestCase.nextCommandRowIndex - 1
    var while_row = htmlTestRunner.currentTest.whileLabels.ends[ last_row ]
    if( undefined == while_row ) 
        throw new Error( "Corresponding 'While' is not found." );
    
    htmlTestRunner.currentTest.continueFromRow( while_row );
    }
    
    // $Id: includeCommand.js 211 2007-08-10 11:16:25Z rob $
/*extern document, window, XMLHttpRequest, ActiveXObject */
/*extern Selenium, htmlTestRunner, LOG, HtmlTestCaseRow, testFrame, storedVars, URLConfiguration */

/**
 * add the content of another test to the current test
 * target receives the page address (from selenium tests root)
 * text receives vars names and their values for this test
 * as a comma separated list of var_name=value
 *
 * nested include works
 *
 * Take a look at the supplied includeCommand TestSuite.html
 * for more examples
 *
 * example of use
 * in the test :
 * +------------------+----------------------+----------------------+
 * |include           | testpiece.html       | name=joe,userId=3445 |
 * +------------------+----------------------+----------------------+
 * where
 * testpiece.html contains
 * +---------------------------------------------+
 * | this is a piece of test                     |
 * +------------------+-----------------------+--+
 * |open              | myurl?userId=${userId}|  |
 * +------------------+-----------------------+--+
 * |verifyTextPresent | ${name}               |  |
 * +------------------+-----------------------+--+
 * as selenium reach the include commande, it will load 
 * seleniumRoot/tests/testpiece.html into you current test, replacing ${name} with joe and ${userId} with 3445
 * and your test wil become
 * +------------------+----------------------+----------------------+
 * |includeExpanded   | testpiece.html       | name=joe,userId=3445 |
 * +------------------+----------------------+----------------------+
 * |open              | myurl?userId=3445    |                      |
 * +------------------+----------------------+----------------------+
 * |verifyTextPresent | joe                  |                      |
 * +------------------+----------------------+----------------------+
 * moreover if you click on the line with "includeExpanded", it will show/hide included lines !
 *
 * Note on URL to get include document:
 *  relative url's (like testpiece.html in the example above) are relative to the TestSuite
 *
 * @author Alexandre Garel
 * @author Robert Zimmermann
 *
 * Note from Robert Zimmermann:
 *  One thing to the variable handling (that's "name=joe,userId=3445" in the example above)
 *  I recommend to use selenium built-in variables instead of parameters in includeCommand.
 *  Why?: There are escaping issues which selenium built-in variables handle better
 *  Though includeCommand variable-like substitution should work and I didn't remove it for backward compatibility
 *  
 *  Version: 2.3
 */

// The real include selenium-command is placed at the end of this file as
//  jslint complains about undefined functions otherwise
Selenium.prototype.doIncludeCollapsed = function(locator, paramString) {
    // do nothing, as rows are already included	
};

Selenium.prototype.doIncludeExpanded = function(locator, paramString) {
    //store paramString passed to include test case into storedVars
	this.storeParams(paramString);
};
 

function IncludeCommand() {
    // TODO targetRow is needed for fold/unfold, isn't there a better way without this member?
    this.targetRow = null;
}

IncludeCommand.EXPANDED_COMMAND_NAME = "includeExpanded";
IncludeCommand.COLLAPSED_COMMAND_NAME = "includeCollapsed";
IncludeCommand.LOG_PREFIX = "IncludeCommand: ";
IncludeCommand.VERSION = "2.3";

// use a closure here to keep each row actions by them self
// TODO think about example: http://www.jibbering.com/faq/faq_notes/closures.html#clObjI
IncludeCommand.prototype.onClickFactory = function(inclCmdRow, lastInclCmdRow) {
    return (function(e) {
        // change the trailing "Expanded" "Collapsed" of include
        // and choose the display style
        var cmdCol = (inclCmdRow.getElementsByTagName("td"))[0].firstChild;
        var displayMode;
        if ( cmdCol.nodeValue == IncludeCommand.EXPANDED_COMMAND_NAME ) {
            cmdCol.nodeValue = IncludeCommand.COLLAPSED_COMMAND_NAME;
            displayMode = "none";
        } else {
            cmdCol.nodeValue = IncludeCommand.EXPANDED_COMMAND_NAME;
            displayMode = inclCmdRow.style.display;
        }
        
        var ptrRow = inclCmdRow.nextSibling;
        while (ptrRow != lastInclCmdRow.nextSibling) {
            // when I unfold i shall unfold all nested include (no way to know which row they concern
            if (displayMode != "none") {
                cmdCol = (ptrRow.getElementsByTagName("td"))[0].firstChild;
                if (cmdCol.nodeValue == IncludeCommand.COLLAPSED_COMMAND_NAME) {
                    cmdCol.nodeValue = IncludeCommand.EXPANDED_COMMAND_NAME;
                }
            }
            // set display mode for rows
            if (ptrRow.style) {
                ptrRow.style.display = displayMode;
            }
            ptrRow = ptrRow.nextSibling;
        }
    });
};

IncludeCommand.prototype.postProcessIncludeCommandRow = function(includeCmdRow) {
    /**
     * Alter the original include command row to add fold, unfold magic
     *
     * @param includeCmdRow TR DOM-element, the source of the current execution
     */
    // TODO names should be class-constants
    var foldUnfoldToolTipp = "click to fold/unfold included rows";
    var lastInclRow = this.targetRow;
    // command name is changed from 'include' to 'include<TAIL>' to avoid another inclusion during a second pass
    (includeCmdRow.getElementsByTagName("td"))[0].firstChild.nodeValue = IncludeCommand.EXPANDED_COMMAND_NAME;
    includeCmdRow.title = foldUnfoldToolTipp;
    includeCmdRow.alt = foldUnfoldToolTipp;
    
    // adding the fold/unfold trick
    includeCmdRow.onclick = this.onClickFactory(includeCmdRow, lastInclRow);
};

IncludeCommand.extendSeleniumExecutionStack = function(newRows) {
    /**
     * Put the new commands into the current position of the selenium execution stack
     *
     * @param newRows Array of HtmlTestCaseRows to be inserted in seleniums' execution stack
     */
    try {
        //(rz WEB.DE) changed to work with selenium 0.8.0
        // Leave previously run commands as they are
        var seleniumCmdRowsPrev = htmlTestRunner.currentTest.htmlTestCase.commandRows.slice(0, htmlTestRunner.currentTest.htmlTestCase.nextCommandRowIndex);
        var seleniumCmdRowsNext = htmlTestRunner.currentTest.htmlTestCase.commandRows.slice(htmlTestRunner.currentTest.htmlTestCase.nextCommandRowIndex);
        var newCommandRows = seleniumCmdRowsPrev.concat(newRows);
        htmlTestRunner.currentTest.htmlTestCase.commandRows = newCommandRows.concat(seleniumCmdRowsNext);
    } catch(e) {
        LOG.error(IncludeCommand.LOG_PREFIX + "Error adding included commandRows. exception=" + e);
        throw new Error("Error adding included commandRows. exception=" + e);
    }
};

IncludeCommand.prototype.injectIncludeTestrows = function(includeCmdRow, testDocument, testRows) {
    /**
     * Insert new (included) commad rows into current testcase (inject them)
     * This is the part visible in the middle frame of testrunner 
     * Selenium inner execution stack is still to be extended which is done later
     *
     * @param includeCmdRow TR Element of the include commad row wich called this include extension (from here the included rows have to be inserted)
     * @param testDocument DOM-document of the current testcase (needed to copy included command rows)
     * @param testRows prepared testrows to be included
     * @return newRows Array of HtmlTestCaseRow objects ready to be used by selenium
     */
    this.targetRow = includeCmdRow;
    var newRows = new Array();
    
    // TODO: use selenium methods to get to the inner test-rows (tr-elements) of an testcase.
    //       here it is the testcase to be included
    // skip first element as it is empty or <tbody>
    for (var i = 1 ; i < testRows.length; i++) {
        var newRow = testDocument.createElement("tr");
        var newText = testRows[i];
        // inserting
        this.targetRow = this.targetRow.parentNode.insertBefore(newRow, this.targetRow.nextSibling);
        // innerHTML permits us not to interpret the rest of html code
        // note: innerHTML is to be filled after insertion of the element in the document
        // note2 : does not work with internet explorer
        try {
            this.targetRow.innerHTML = newText;
        } catch (e) {
            // doing it the hard way for ie
            // parsing column, doing column per column insertion
            // remove < td>
            newText = newText.replace(/<\s*td[^>]*>/ig,"");
            //Lance: remove </tbody>
            newText = newText.replace(/<\/*tbody*>|<br>/ig,"");
            // split on < td>
            var testCols = newText.split(/<\/\s*td[^>]*>/i);
            for (var j = 0 ; j < testCols.length; j++) {
                var newCol = testDocument.createElement("td");
                var colText = testCols[j];
                newCol = this.targetRow.appendChild(newCol);
                newCol.innerHTML = colText;
            }
        }
        // TODO try to use original HtmlTestCase class instead copying parts of it
        if (newRow.cells.length >= 3) {
            var seleniumRow = new HtmlTestCaseRow(newRow);
            seleniumRow.addBreakpointSupport();
            newRows.push(seleniumRow);
        }
    }
    return newRows;
};

IncludeCommand.getCurrentTestDocument = function() {
    /**
     * Get the current test-case document from selenium
     *
     * @return testDocument the document object of the testcase-frame
     */
    var testDocument;
    try {
        testDocument = testFrame.getDocument();
    }
    catch(e) {
        throw new Error("testDocument not avalaible. Selenium API changed?");
    }
    return testDocument;
};

IncludeCommand.prepareTestCaseAsText = function(responseAsText, paramsArray) {
    /**
     * Prepare the HTML to be included in as text into the current testcase-HTML
     * Strip all but the testrows (tr)
     * Stripped will be:
     *  - whitespace (also new lines and tabs, so be careful wirt parameters relying on this),
     *  - comments (xml comments)                 
     * Replace variable according to include-parameters 
     * note: the include-variables are replaced literally. selenium does it at execution time
     * also note: all selenium-variables are available to the included commands, so mostly no include-parameters are necessary
     *
     * @param responseAsText table to be included as text (string)
     * @return testRows array of tr elements (as string!) containing the commands to be included
     * 
     * TODO:
     *  - selenium already can handle testcase-html. use selenium methods or functions instead
     *  - find better name for requester
     */
    // removing new lines, carret return and tabs from response in order to work with regexp
    var pageText = responseAsText.replace(/\r|\n|\t/g,"");
    // remove comments
    // begin comment, not a dash or if it's a dash it may not be followed by -> repeated, end comment
    pageText = pageText.replace(/<!--(?:[^-]|-(?!->))*-->/g,"");
    // find the content of the test table = <[spaces]table[char but not >]>....< /[spaces]table[chars but not >]>
    var testText = pageText.match(/<\s*table[^>]*>(.*)<\/\s*table[^>]*>/i)[1];

    // Replace <td></td> with <td>&nbsp;</td> for iE - credits Chris Astall
    // rz: somehow in my IE 7 this is not needed but is not bad as well
    testText = testText.replace(/<\s*td[^>]*>\s*<\s*\/td[^>]*>/ig,"<td>&nbsp;</td>");

    /*
     Do not replace else included test case will not work in WHILE loop
     @see Selenium.prototype.doIncludeExpanded
     @see Selenium.prototype.doInclude

    for ( var k = 0 ; k < paramsArray.length ; k++ ) {
       var pair = paramsArray[k];
       testText = testText.replace(pair[0],pair[1]);
    }
    */

    // removes all  < /tr> 
    // in order to split on < tr>
    testText = testText.replace(/<\/\s*tr[^>]*>/ig,"");
    // split on <tr>
    var testRows = testText.split(/<\s*tr[^>]*>/i);
    return testRows;
};

IncludeCommand.getIncludeDocumentBySynchronRequest = function(includeUrl) {
    /**
     * Prepare and do the XMLHttp Request synchronous as selenium should not continue execution meanwhile
     *
     * note: the XMLHttp requester is returned (instead of e.g. its text) to let the caller decide to use xml or text
     *
     * selenium-dependency: uses extended String from htmlutils
     *
     *  TODO use Ajax from prototype like this:
     *   var sjaxRequest = new Ajax.Request(url, {asynchronous:false});
     *   there is discussion about getting rid of prototype.js in developer forum.
     *   the ajax impl in xmlutils.js is not active by default in 0.8.2
     *
     * @param includeUrl URI to the include-document (document has to be from the same domain)
     * @return XMLHttp requester after receiving the response
     */
    var url = IncludeCommand.prepareUrl(includeUrl);
    // the xml http requester to fetch the page to include
    var requester = IncludeCommand.newXMLHttpRequest();
    if (!requester) {
        throw new Error("XMLHttp requester object not initialized");
    }
    requester.open("GET", url, false); // synchron mode ! (we don't want selenium to go ahead)
    try {
        requester.send(null);
    } catch(e) {
      throw new Error("Error while fetching url '" + url + "' details: " + e);
    }
    if ( requester.status != 200 && requester.status !== 0 ) {
        throw new Error("Error while fetching " + url + " server response has status = " + requester.status + ", " + requester.statusText );
    }
    return requester;
};

IncludeCommand.prepareUrl = function(includeUrl) {
    /** Construct absolute URL to get include document
     * using selenium-core handling of urls (see absolutify in htmlutils.js)
     */
    var prepareUrl;
    // htmlSuite mode of SRC? TODO is there a better way to decide whether in SRC mode?
    if (window.location.href.indexOf("selenium-server") >= 0) {
        LOG.debug(IncludeCommand.LOG_PREFIX + "we seem to run in SRC, do we?");
        preparedUrl = absolutify(includeUrl, htmlTestRunner.controlPanel.getTestSuiteName());
    } else {
        preparedUrl = absolutify(includeUrl, selenium.browserbot.baseUrl);
    }
    LOG.debug(IncludeCommand.LOG_PREFIX + "using url to get include '" + preparedUrl + "'");
    return preparedUrl;
};

IncludeCommand.newXMLHttpRequest = function() {
    // TODO should be replaced by impl. in prototype.js or xmlextras.js
    //     but: there is discussion of getting rid of prototype.js
    //     and: currently xmlextras.js is not activated in testrunner of 0.8.2 release
    var requester = 0;
    var exception = '';
    // see http://developer.apple.com/internet/webcontent/xmlhttpreq.html
    // changed order of native and activeX to get it working with native
    //  xmlhttp in IE 7. credits dhwang
    try {
        // for IE/ActiveX
        if(window.ActiveXObject) {
            try {
                requester = new ActiveXObject("Msxml2.XMLHTTP");
            }
            catch(e) {
                requester = new ActiveXObject("Microsoft.XMLHTTP");
            }
        }
        // Native XMLHttp
        else if(window.XMLHttpRequest) {
            requester = new XMLHttpRequest();
        }
    }
    catch(e) {
        throw new Error("Your browser has to support XMLHttpRequest in order to use include \n" + e);
    }
    return requester;
};

IncludeCommand.splitParamStrIntoVariables = function(paramString) {
    /**
     * Split include Parameters-String into an 2-dim array containing Variable-Name and -Value
     *
     * selenium-dependency: uses extended String from htmlutils
     *
     * TODO: write jsunit tests - this could be easy (if there were not the new RegExp)
     *
     * @param includeParameters string the parameters from include call
     * @return new 2-dim Array containing regExpName (to find a matching variablename) and value to be substituted for
     */
    var newParamsArray = new Array();
    // paramString shall contains a list of var_name=value
    var paramListPattern = /([^=,]+=[^=,]*,)*([^=,]+=[^=,]*)/;
    if (! paramString || paramString === "") {
        return newParamsArray;
    } else if (paramString.match( paramListPattern )) {
        // parse parameters to fill newParamsArray
        var pairs = paramString.split(",");
        for ( var i = 0 ; i < pairs.length ; i++ ) {
            var pair = pairs[i];
            var nameValue = pair.split("=");
            //rz: use String.trim from htmlutils.js of selenium to get rid of whitespace in variable-name(s)
            var trimmedNameValue = new String(nameValue[0]).trim();
            // the pattern to substitute is ${var_name}
            var regExpName = new RegExp("\\$\\{" + trimmedNameValue + "\\}", "g");
            
            if (nameValue.length < 3) {
               newParamsArray.push(new Array(regExpName,nameValue[1]));
            } else {
                var varValue = new String(nameValue[1]);
                for (var j = 2; j < nameValue.length; j++) {
                    varValue=varValue.concat("="+nameValue[j]);
                }
                newParamsArray.push(new Array(regExpName,varValue));
            }
        }
    } else {
        throw new Error("Bad format for parameters list : '" + paramString + "'");
    }
    return newParamsArray;
};

IncludeCommand.prototype.doInclude = function(locator, paramString) {
    // TODO check if reordering of these calls can help to "fail fast/early"

    // ask selenium for the current row (<tr> Element of the include command)
    // credits: dhwang
    var currentSelHtmlTestcase = testFrame.getCurrentTestCase();
    var includeCmdRow = currentSelHtmlTestcase.commandRows[currentSelHtmlTestcase.nextCommandRowIndex - 1].trElement;

    if (!includeCmdRow) {
        throw new Error("includeCommand: failed to find include-row in source testtable");
    }

    var paramsArray = IncludeCommand.splitParamStrIntoVariables(paramString);

    // rz: TODO add use of selenium timeout
    var inclDoc = IncludeCommand.getIncludeDocumentBySynchronRequest(locator);

    var includedTestCaseHtml = IncludeCommand.prepareTestCaseAsText(inclDoc.responseText, paramsArray);

    var testDocument = IncludeCommand.getCurrentTestDocument();

    // only member method because targetRow member is set
    var newRows = this.injectIncludeTestrows(includeCmdRow, testDocument, includedTestCaseHtml);

    IncludeCommand.extendSeleniumExecutionStack(newRows);

    // only member method because targetRow member is accessed
    this.postProcessIncludeCommandRow(includeCmdRow);
};

// sakhunzai: include addon fix to work with flow control (include testcase which has goto labels/while loop)
Selenium.prototype.doInclude = function(locator, paramString) {
    LOG.debug(IncludeCommand.LOG_PREFIX + " Version " + IncludeCommand.VERSION);
    var includeCommand = new IncludeCommand();
    includeCommand.doInclude(locator, paramString);
	
    try {
        htmlTestRunner.currentTest.initialiseLabels();
    } 
    catch (e) {
    	LOG.debug("Goto Script not used.");
    }
	//first time included
	this.storeParams(paramString);
};

//store paramString variables into storedVar to be accessible within the included test case
Selenium.prototype.storeParams = function(paramString) {
  var paramPairs = paramString.split(",");
  LOG.info('Include Parms:');
  for ( var i = 0 ; i < paramPairs.length ; i++ ) {
    var paramPair = paramPairs[i].split('='); 	
	this.doStore(paramPair[1],paramPair[0]);
	LOG.info(paramPair[0]+'=>'+paramPair[1]);
  }
};


/************************************ DATADRIVEN EXTENSION START ********************************************/
/*
NAME:
	datadriven
	
	Licensed under Apache License v2
	http://www.apache.org/licenses/LICENSE-2.0

PURPOSE:
	Basic data driven testing.
	
	Full documentation at http://wiki.openqa.org/display/SEL/datadriven
	
	
EXAMPLE USE:
	The structure of your data driven test case will be;
	-------------------------------------------
	COMMAND       |TARGET          |VALUE
	-------------------------------------------
	loadTestData  |<file path>     |
	while         |!testdata.EOF() |
	testcommand1  |                |
	testcommand...|                |
	testcommandn  |                |
	endWhile      |                |
	-------------------------------------------

AUTHOR:
	Jonathan McBrien
	jonathan@mcbrien.org
	2008-10-22: v0.1:	Initial version.
	2009-01-16: v0.2:	Updated for Firefox 3.
				xmlTestData.prototype.load now uses the include extension's getIncludeDocumentBySynchronRequest method for better portability.
				(Why reinvent the wheel? :) - with appreciation to the include extension's authors.)
*/
var XML = {};

XML.serialize = function(node) {
	if (typeof XMLSerializer != "undefined")
		return (new XMLSerializer()).serializeToString(node) ;
	else if (node.xml) return node.xml;
	else throw "XML.serialize is not supported or can't serialize " + node;
}

function xmlTestData() {
	this.xmlDoc = null;
	this.testdata = null;
	this.index = null;
}


xmlTestData.prototype.load = function(xmlloc) {
	LOG.info(" ++ new IncludeCommand");
	loader = new IncludeCommand();
	LOG.info(" -- new IncludeCommand");
	LOG.info(" ++ new IncludeCommand.getIncludeDocumentBySynchronRequest");
	
	var xmlHttpReq = IncludeCommand.getIncludeDocumentBySynchronRequest(xmlloc);
	LOG.info(" -- new IncludeCommand.getIncludeDocumentBySynchronRequest");
	
	LOG.info(" ++ new xmlHttpReq.responseXML");
	
	this.xmlDoc = xmlHttpReq.responseXML;
	LOG.info(" ++ new xmlHttpReq.responseXML");
		
	this.index = 0;
	this.testdata = this.xmlDoc.getElementsByTagName("test");

	if (this.testdata == null || this.testdata.length == 0) {
		throw new Error("Test data couldn't be loaded or test data was empty.");
	}
}

xmlTestData.prototype.EOF = function() {
	if (this.index != null && this.index < this.testdata.length) return false;
	return true;
}

xmlTestData.prototype.more = function() {
	return !this.EOF();
}

xmlTestData.prototype.next = function() {
	if (this.EOF()) {
		LOG.error("No test data.");
		return;
	}
	
	LOG.info(XML.serialize(this.testdata[this.index]));	// Log should anything go wrong while testing with this data.

	if (this.testdata[this.index].attributes.length != this.testdata[0].attributes.length) {
		LOG.error("Inconsistent attribute length in test data.");
		return;
	}
	
	for (i=0; i<this.testdata[this.index].attributes.length; i++){
		if (null == this.testdata[0].getAttribute(this.testdata[this.index].attributes[i].nodeName)) {
			LOG.error("Inconsistent attribute names in test data.");
			return;
		}

		selenium.doStore(this.testdata[this.index].attributes[i].nodeValue, this.testdata[this.index].attributes[i].nodeName);
	}

	this.index++;
}

Selenium.prototype.testdata = null;

Selenium.prototype.doLoadTestData = function(xmlloc) {
	testdata = new xmlTestData();
	testdata.load(xmlloc);
};

Selenium.prototype.doNextTestData = function() {
	testdata.next();
};

Selenium.prototype.doTestDataAtRowIndex = function(rowindex) {
	testdata.lookatrow(rowindex);
};

xmlTestData.prototype.lookatrow = function(rowindex) {
	if (this.EOF()) {
		LOG.error("No test data.");
		return;
	}
	
	LOG.info(XML.serialize(this.testdata[this.index]));	// Log should anything go wrong while testing with this data.
	LOG.info("this.testdata.length: " + this.testdata.length + ",rowindex=" + rowindex);

	if (this.testdata[this.index].attributes.length != this.testdata[0].attributes.length) {
		LOG.error("Inconsistent attribute length in test data.");
		return;
	}
	
	if (this.testdata.length > 0 )
	{
	  if (rowindex>this.testdata.length) rowindex = this.testdata.length ;
	  if (rowindex<1) rowindex = 1;
	  
	  this.index=rowindex-1;
	  LOG.info("this.index:" + this.index);
	  for (i=0; i<this.testdata[this.index].attributes.length; i++){
		  if (null == this.testdata[0].getAttribute(this.testdata[this.index].attributes[i].nodeName)) {
			  LOG.error("Inconsistent attribute names in test data.");
			  return;
		  }

		  selenium.doStore(this.testdata[this.index].attributes[i].nodeValue, this.testdata[this.index].attributes[i].nodeName);
		  LOG.debug("this.testdata[this.index].attributes[i].nodeValue:"+this.testdata[this.index].attributes[i].nodeValue+", this.testdata[this.index].attributes[i].nodeName" + this.testdata[this.index].attributes[i].nodeName);
	  }
	}

	this.index++;
}
/************************************ DATADRIVEN EXTENSION END **********************************************/