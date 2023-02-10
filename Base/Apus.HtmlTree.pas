// Simple HTML parser
// Reference: https://www.w3.org/TR/2016/REC-html51-20161101/syntax.html

// Copyright (C) 2023 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.HtmlTree;
interface
uses Apus.Types, Apus.Structs;

type
 THtmlNode=class;
 THtmlElement=class;

 THtmlNodeVisitor=procedure(node:THtmlNode;context:pointer);
 THtmlElementVisitor=procedure(element:THtmlElement;context:pointer);

 // Base node class
 THtmlNode=class
   parent:THtmlElement;
   text:string;
   constructor Create(parent:THtmlElement;text:string='');
   destructor Destroy; override;
   function Depth:integer; // how many parents the node has
 end;

 // Regular text node
 THtmlText=class(THtmlNode)
 end;

 // Content of foreign elements differs from regular text nodes and is not included in the InnerText
 THtmlForeignContent=class(THtmlNode)
 end;

 // Comment node class
 THtmlComment=class(THtmlNode)
 end;

 // Element node class. Only nodes of this type can have child nodes
 THtmlElement=class(THtmlNode)
   tag:string;
   attributes:TNameValueList;
   children:TArray<THtmlNode>;
   constructor Create(parent:THtmlElement;text:string='');
   destructor Destroy; override;
   procedure AddChild(node:THtmlNode);
   procedure RemoveChild(node:THtmlNode); // remove node from children, but don't delete it
   function InnerText:string;  // return concatenated text of all the children text nodes (recursively)
   procedure Visit(visitor:THtmlNodeVisitor;context:pointer); // call visitor for each child node (recursively)
   procedure VisitElements(visitor:THtmlElementVisitor;context:pointer;tag:string=''); // call visitor for each child element matching criteria
   // Find an element with given tag name, having specified attribute containing spefified text
   function GetElement(tag:string;attribute:string='';contains:string=''):THtmlElement;
   function PrintTree:string; // for debug
   function GetAttribute(aName:string):string;
   function HasAttribute(aName:string):boolean;
   function AttributeContains(aName,substr:string):boolean;
   function ChildElementCount:integer;
   function GetChildElement(index:integer):THtmlElement;
 protected
   function IsVoid:boolean;
   function IsBlock:boolean;
   function IsRawtext:boolean;
   function IsForeign:boolean;
   function CanContain(childTag:string):boolean; // can this element contain a 'childTag' element as a child?
 end;

 // Returns a HTML tree with an empty root element
 function ParseHTML(st:string):THtmlElement;

 function DecodeHTMLString(src:string):string; // replace HTML entities with corresponging characters

implementation
uses SysUtils, Apus.Common;

const
 VOID_ELEMENTS = '|!doctype|area|base|br|col|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr|';
 BLOCK_ELEMENTS = '|address|article|aside|blockquote|canvas|dd|div|dl|dt|fieldset|figcaption|figure|footer|form|h1|h2|h3|h4|h5|h6|header|hr|li|main|nav|noscript|ol|p|pre|section|table|tfoot|ul|video|';
 RAWTEXT_ELEMENTS = '|script|style|textarea|title|';
 FOREIGN_ELEMENTS = '|svg|';

 // Source: https://html.spec.whatwg.org/entities.json
 ENTITIES_LIST : array[0..1898] of WideString=(
   #198'aelig',#38'amp',#193'aacute',#258'abreve',#194'acirc',#1040'acy',#192'agrave',#913'alpha',#256'amacr',#10835'and',#260'aogon',#8289'applyfunction',#197'aring',#8788'assign',#195'atilde',#196'auml',#8726'backslash',#10983'barv',#8966'barwed',#1041'bcy',#8757'because',#8492'bernoullis',#914'beta',#728'breve',#8492'bscr',#8782'bumpeq',#1063'chcy',#169'copy',#262'cacute',#8914'cap',#8517'capitaldifferentiald',#8493'cayleys',#268'ccaron',#199'ccedil',#264'ccirc',#8752'cconint',#266'cdot',#184'cedilla',#183'centerdot',#8493'cfr',#935'chi',#8857'circledot',#8854'circleminus',#8853'circleplus',#8855'circletimes',
   #8754'clockwisecontourintegral',#8221'closecurlydoublequote',#8217'closecurlyquote',#8759'colon',#10868'colone',#8801'congruent',#8751'conint',#8750'contourintegral',#8450'copf',#8720'coproduct',#8755'counterclockwisecontourintegral',#10799'cross',#8915'cup',#8781'cupcap',#8517'dd',#10513'ddotrahd',#1026'djcy',#1029'dscy',#1039'dzcy',#8225'dagger',#8609'darr',#10980'dashv',#270'dcaron',#1044'dcy',#8711'del',#916'delta',#180'diacriticalacute',#729'diacriticaldot',#733'diacriticaldoubleacute',#96'diacriticalgrave',#732'diacriticaltilde',#8900'diamond',#8518'differentiald',#168'dot',#8412'dotdot',#8784'dotequal',#8751'doublecontourintegral',#168'doubledot',#8659'doubledownarrow',#8656'doubleleftarrow',#8660'doubleleftrightarrow',#10980'doublelefttee',#10232'doublelongleftarrow',#10234'doublelongleftrightarrow',#10233'doublelongrightarrow',#8658'doublerightarrow',#8872'doublerighttee',
   #8657'doubleuparrow',#8661'doubleupdownarrow',#8741'doubleverticalbar',#8595'downarrow',#10515'downarrowbar',#8693'downarrowuparrow',#785'downbreve',#10576'downleftrightvector',#10590'downleftteevector',#8637'downleftvector',#10582'downleftvectorbar',#10591'downrightteevector',#8641'downrightvector',#10583'downrightvectorbar',#8868'downtee',#8615'downteearrow',#8659'downarrow',#272'dstrok',#330'eng',#208'eth',#201'eacute',#282'ecaron',#202'ecirc',#1069'ecy',#278'edot',#200'egrave',#8712'element',#274'emacr',#9723'emptysmallsquare',#9643'emptyverysmallsquare',#280'eogon',#917'epsilon',#10869'equal',#8770'equaltilde',#8652'equilibrium',#8496'escr',#10867'esim',#919'eta',#203'euml',#8707'exists',#8519'exponentiale',#1060'fcy',#9724'filledsmallsquare',#9642'filledverysmallsquare',#8704'forall',
   #8497'fouriertrf',#8497'fscr',#1027'gjcy',#62'gt',#915'gamma',#988'gammad',#286'gbreve',#290'gcedil',#284'gcirc',#1043'gcy',#288'gdot',#8921'gg',#8805'greaterequal',#8923'greaterequalless',#8807'greaterfullequal',#10914'greatergreater',#8823'greaterless',#10878'greaterslantequal',#8819'greatertilde',#8811'gt',#1066'hardcy',#711'hacek',#94'hat',#292'hcirc',#8460'hfr',#8459'hilbertspace',#8461'hopf',#9472'horizontalline',#8459'hscr',#294'hstrok',#8782'humpdownhump',#8783'humpequal',#1045'iecy',#306'ijlig',#1025'iocy',#205'iacute',#206'icirc',#1048'icy',#304'idot',#8465'ifr',#204'igrave',#8465'im',#298'imacr',#8520'imaginaryi',#8658'implies',#8748'int',#8747'integral',
   #8898'intersection',#8291'invisiblecomma',#8290'invisibletimes',#302'iogon',#921'iota',#8464'iscr',#296'itilde',#1030'iukcy',#207'iuml',#308'jcirc',#1049'jcy',#1032'jsercy',#1028'jukcy',#1061'khcy',#1036'kjcy',#922'kappa',#310'kcedil',#1050'kcy',#1033'ljcy',#60'lt',#313'lacute',#923'lambda',#10218'lang',#8466'laplacetrf',#8606'larr',#317'lcaron',#315'lcedil',#1051'lcy',#10216'leftanglebracket',#8592'leftarrow',#8676'leftarrowbar',#8646'leftarrowrightarrow',#8968'leftceiling',#10214'leftdoublebracket',#10593'leftdownteevector',#8643'leftdownvector',#10585'leftdownvectorbar',#8970'leftfloor',#8596'leftrightarrow',#10574'leftrightvector',#8867'lefttee',#8612'leftteearrow',#10586'leftteevector',
   #8882'lefttriangle',#10703'lefttrianglebar',#8884'lefttriangleequal',#10577'leftupdownvector',#10592'leftupteevector',#8639'leftupvector',#10584'leftupvectorbar',#8636'leftvector',#10578'leftvectorbar',#8656'leftarrow',#8660'leftrightarrow',#8922'lessequalgreater',#8806'lessfullequal',#8822'lessgreater',#10913'lessless',#10877'lessslantequal',#8818'lesstilde',#8920'll',#8666'lleftarrow',#319'lmidot',#10229'longleftarrow',#10231'longleftrightarrow',#10230'longrightarrow',#10232'longleftarrow',#10234'longleftrightarrow',#10233'longrightarrow',#8601'lowerleftarrow',#8600'lowerrightarrow',#8466'lscr',#8624'lsh',#321'lstrok',#8810'lt',#10501'map',#1052'mcy',#8287'mediumspace',#8499'mellintrf',#8723'minusplus',#8499'mscr',#924'mu',#1034'njcy',#323'nacute',#327'ncaron',#325'ncedil',#1053'ncy',#8203'negativemediumspace',#8203'negativethickspace',
   #8203'negativethinspace',#8203'negativeverythinspace',#8811'nestedgreatergreater',#8810'nestedlessless',#10'newline',#8288'nobreak',#160'nonbreakingspace',#8469'nopf',#10988'not',#8802'notcongruent',#8813'notcupcap',#8742'notdoubleverticalbar',#8713'notelement',#8800'notequal',#8708'notexists',#8815'notgreater',#8817'notgreaterequal',#8825'notgreaterless',#8821'notgreatertilde',#8938'notlefttriangle',#8940'notlefttriangleequal',#8814'notless',#8816'notlessequal',#8824'notlessgreater',#8820'notlesstilde',#8832'notprecedes',#8928'notprecedesslantequal',#8716'notreverseelement',#8939'notrighttriangle',#8941'notrighttriangleequal',#8930'notsquaresubsetequal',#8931'notsquaresupersetequal',#8840'notsubsetequal',#8833'notsucceeds',#8929'notsucceedsslantequal',#8841'notsupersetequal',#8769'nottilde',#8772'nottildeequal',#8775'nottildefullequal',#8777'nottildetilde',#8740'notverticalbar',#209'ntilde',#925'nu',#338'oelig',#211'oacute',#212'ocirc',#1054'ocy',#336'odblac',
   #210'ograve',#332'omacr',#937'omega',#927'omicron',#8220'opencurlydoublequote',#8216'opencurlyquote',#10836'or',#216'oslash',#213'otilde',#10807'otimes',#214'ouml',#8254'overbar',#9182'overbrace',#9140'overbracket',#9180'overparenthesis',#8706'partiald',#1055'pcy',#934'phi',#928'pi',#177'plusminus',#8460'poincareplane',#8473'popf',#10939'pr',#8826'precedes',#10927'precedesequal',#8828'precedesslantequal',#8830'precedestilde',#8243'prime',#8719'product',#8759'proportion',#8733'proportional',#936'psi',#34'quot',#8474'qopf',#10512'rbarr',#174'reg',#340'racute',#10219'rang',#8608'rarr',#10518'rarrtl',#344'rcaron',#342'rcedil',#1056'rcy',
   #8476're',#8715'reverseelement',#8651'reverseequilibrium',#10607'reverseupequilibrium',#8476'rfr',#929'rho',#10217'rightanglebracket',#8594'rightarrow',#8677'rightarrowbar',#8644'rightarrowleftarrow',#8969'rightceiling',#10215'rightdoublebracket',#10589'rightdownteevector',#8642'rightdownvector',#10581'rightdownvectorbar',#8971'rightfloor',#8866'righttee',#8614'rightteearrow',#10587'rightteevector',#8883'righttriangle',#10704'righttrianglebar',#8885'righttriangleequal',#10575'rightupdownvector',#10588'rightupteevector',#8638'rightupvector',#10580'rightupvectorbar',#8640'rightvector',#10579'rightvectorbar',#8658'rightarrow',#8477'ropf',#10608'roundimplies',#8667'rrightarrow',#8475'rscr',#8625'rsh',#10740'ruledelayed',#1065'shchcy',#1064'shcy',#1068'softcy',#346'sacute',#10940'sc',#352'scaron',#350'scedil',#348'scirc',#1057'scy',#8595'shortdownarrow',#8592'shortleftarrow',#8594'shortrightarrow',#8593'shortuparrow',#931'sigma',
   #8728'smallcircle',#8730'sqrt',#9633'square',#8851'squareintersection',#8847'squaresubset',#8849'squaresubsetequal',#8848'squaresuperset',#8850'squaresupersetequal',#8852'squareunion',#8902'star',#8912'sub',#8912'subset',#8838'subsetequal',#8827'succeeds',#10928'succeedsequal',#8829'succeedsslantequal',#8831'succeedstilde',#8715'suchthat',#8721'sum',#8913'sup',#8835'superset',#8839'supersetequal',#8913'supset',#222'thorn',#8482'trade',#1035'tshcy',#1062'tscy',#9'tab',#932'tau',#356'tcaron',#354'tcedil',#1058'tcy',#8756'therefore',#920'theta',#8201'thinspace',#8764'tilde',#8771'tildeequal',#8773'tildefullequal',#8776'tildetilde',#8411'tripledot',#358'tstrok',#218'uacute',#8607'uarr',#10569'uarrocir',#1038'ubrcy',
   #364'ubreve',#219'ucirc',#1059'ucy',#368'udblac',#217'ugrave',#362'umacr',#95'underbar',#9183'underbrace',#9141'underbracket',#9181'underparenthesis',#8899'union',#8846'unionplus',#370'uogon',#8593'uparrow',#10514'uparrowbar',#8645'uparrowdownarrow',#8597'updownarrow',#10606'upequilibrium',#8869'uptee',#8613'upteearrow',#8657'uparrow',#8661'updownarrow',#8598'upperleftarrow',#8599'upperrightarrow',#978'upsi',#933'upsilon',#366'uring',#360'utilde',#220'uuml',#8875'vdash',#10987'vbar',#1042'vcy',#8873'vdash',#10982'vdashl',#8897'vee',#8214'verbar',#8214'vert',#8739'verticalbar',#124'verticalline',#10072'verticalseparator',#8768'verticaltilde',#8202'verythinspace',#8874'vvdash',#372'wcirc',
   #8896'wedge',#926'xi',#1071'yacy',#1031'yicy',#1070'yucy',#221'yacute',#374'ycirc',#1067'ycy',#376'yuml',#1046'zhcy',#377'zacute',#381'zcaron',#1047'zcy',#379'zdot',#8203'zerowidthspace',#918'zeta',#8488'zfr',#8484'zopf',#225'aacute',#259'abreve',#8766'ac',#8767'acd',#226'acirc',#180'acute',#1072'acy',#230'aelig',#8289'af',#224'agrave',#8501'alefsym',#8501'aleph',#945'alpha',#257'amacr',#10815'amalg',#38'amp',#8743'and',#10837'andand',#10844'andd',#10840'andslope',#10842'andv',
   #8736'ang',#10660'ange',#8736'angle',#8737'angmsd',#10664'angmsdaa',#10665'angmsdab',#10666'angmsdac',#10667'angmsdad',#10668'angmsdae',#10669'angmsdaf',#10670'angmsdag',#10671'angmsdah',#8735'angrt',#8894'angrtvb',#10653'angrtvbd',#8738'angsph',#197'angst',#9084'angzarr',#261'aogon',#8776'ap',#10864'ape',#10863'apacir',#8778'ape',#8779'apid',#39'apos',#8776'approx',#8778'approxeq',#229'aring',#42'ast',#8776'asymp',#8781'asympeq',#227'atilde',#228'auml',#8755'awconint',#10769'awint',#10989'bnot',#8780'backcong',#1014'backepsilon',#8245'backprime',#8765'backsim',#8909'backsimeq',#8893'barvee',#8965'barwed',#8965'barwedge',#9141'bbrk',#9142'bbrktbrk',#8780'bcong',#1073'bcy',
   #8222'bdquo',#8757'becaus',#8757'because',#10672'bemptyv',#1014'bepsi',#8492'bernou',#946'beta',#8502'beth',#8812'between',#8898'bigcap',#9711'bigcirc',#8899'bigcup',#10752'bigodot',#10753'bigoplus',#10754'bigotimes',#10758'bigsqcup',#9733'bigstar',#9661'bigtriangledown',#9651'bigtriangleup',#10756'biguplus',#8897'bigvee',#8896'bigwedge',#10509'bkarow',#10731'blacklozenge',#9642'blacksquare',#9652'blacktriangle',#9662'blacktriangledown',#9666'blacktriangleleft',#9656'blacktriangleright',#9251'blank',#9618'blk12',#9617'blk14',#9619'blk34',#9608'block',#8976'bnot',#8869'bot',#8869'bottom',#8904'bowtie',#9559'boxdl',#9556'boxdr',#9558'boxdl',#9555'boxdr',#9552'boxh',#9574'boxhd',#9577'boxhu',#9572'boxhd',#9575'boxhu',#9565'boxul',
   #9562'boxur',#9564'boxul',#9561'boxur',#9553'boxv',#9580'boxvh',#9571'boxvl',#9568'boxvr',#9579'boxvh',#9570'boxvl',#9567'boxvr',#10697'boxbox',#9557'boxdl',#9554'boxdr',#9488'boxdl',#9484'boxdr',#9472'boxh',#9573'boxhd',#9576'boxhu',#9516'boxhd',#9524'boxhu',#8863'boxminus',#8862'boxplus',#8864'boxtimes',#9563'boxul',#9560'boxur',#9496'boxul',#9492'boxur',#9474'boxv',#9578'boxvh',#9569'boxvl',#9566'boxvr',#9532'boxvh',#9508'boxvl',#9500'boxvr',#8245'bprime',#728'breve',#166'brvbar',#8271'bsemi',#8765'bsim',#8909'bsime',#92'bsol',#10693'bsolb',#10184'bsolhsub',#8226'bull',#8226'bullet',#8782'bump',#10926'bumpe',#8783'bumpe',#8783'bumpeq',
   #263'cacute',#8745'cap',#10820'capand',#10825'capbrcup',#10827'capcap',#10823'capcup',#10816'capdot',#8257'caret',#711'caron',#10829'ccaps',#269'ccaron',#231'ccedil',#265'ccirc',#10828'ccups',#10832'ccupssm',#267'cdot',#184'cedil',#10674'cemptyv',#162'cent',#183'centerdot',#1095'chcy',#10003'check',#10003'checkmark',#967'chi',#9675'cir',#10691'cire',#710'circ',#8791'circeq',#8634'circlearrowleft',#8635'circlearrowright',#174'circledr',#9416'circleds',#8859'circledast',#8858'circledcirc',#8861'circleddash',#8791'cire',#10768'cirfnint',#10991'cirmid',#10690'cirscir',#9827'clubs',#9827'clubsuit',#58'colon',#8788'colone',#8788'coloneq',#44'comma',#64'commat',#8705'comp',#8728'compfn',#8705'complement',
   #8450'complexes',#8773'cong',#10861'congdot',#8750'conint',#8720'coprod',#169'copy',#8471'copysr',#8629'crarr',#10007'cross',#10959'csub',#10961'csube',#10960'csup',#10962'csupe',#8943'ctdot',#10552'cudarrl',#10549'cudarrr',#8926'cuepr',#8927'cuesc',#8630'cularr',#10557'cularrp',#8746'cup',#10824'cupbrcap',#10822'cupcap',#10826'cupcup',#8845'cupdot',#10821'cupor',#8631'curarr',#10556'curarrm',#8926'curlyeqprec',#8927'curlyeqsucc',#8910'curlyvee',#8911'curlywedge',#164'curren',#8630'curvearrowleft',#8631'curvearrowright',#8910'cuvee',#8911'cuwed',#8754'cwconint',#8753'cwint',#9005'cylcty',#8659'darr',#10597'dhar',#8224'dagger',#8504'daleth',#8595'darr',#8208'dash',#8867'dashv',#10511'dbkarow',
   #733'dblac',#271'dcaron',#1076'dcy',#8518'dd',#8225'ddagger',#8650'ddarr',#10871'ddotseq',#176'deg',#948'delta',#10673'demptyv',#10623'dfisht',#8643'dharl',#8642'dharr',#8900'diam',#8900'diamond',#9830'diamondsuit',#9830'diams',#168'die',#989'digamma',#8946'disin',#247'div',#247'divide',#8903'divideontimes',#8903'divonx',#1106'djcy',#8990'dlcorn',#8973'dlcrop',#36'dollar',#729'dot',#8784'doteq',#8785'doteqdot',#8760'dotminus',#8724'dotplus',#8865'dotsquare',#8966'doublebarwedge',#8595'downarrow',#8650'downdownarrows',#8643'downharpoonleft',#8642'downharpoonright',#10512'drbkarow',#8991'drcorn',#8972'drcrop',#1109'dscy',#10742'dsol',#273'dstrok',#8945'dtdot',#9663'dtri',
   #9662'dtrif',#8693'duarr',#10607'duhar',#10662'dwangle',#1119'dzcy',#10239'dzigrarr',#10871'eddot',#8785'edot',#233'eacute',#10862'easter',#283'ecaron',#8790'ecir',#234'ecirc',#8789'ecolon',#1101'ecy',#279'edot',#8519'ee',#8786'efdot',#10906'eg',#232'egrave',#10902'egs',#10904'egsdot',#10905'el',#9191'elinters',#8467'ell',#10901'els',#10903'elsdot',#275'emacr',#8709'empty',#8709'emptyset',#8709'emptyv',#8196'emsp13',#8197'emsp14',#8195'emsp',#331'eng',#8194'ensp',#281'eogon',#8917'epar',#10723'eparsl',#10865'eplus',#949'epsi',#949'epsilon',#1013'epsiv',#8790'eqcirc',#8789'eqcolon',#8770'eqsim',#10902'eqslantgtr',#10901'eqslantless',
   #61'equals',#8799'equest',#8801'equiv',#10872'equivdd',#10725'eqvparsl',#8787'erdot',#10609'erarr',#8495'escr',#8784'esdot',#8770'esim',#951'eta',#240'eth',#235'euml',#8364'euro',#33'excl',#8707'exist',#8496'expectation',#8519'exponentiale',#8786'fallingdotseq',#1092'fcy',#9792'female',#64259'ffilig',#64256'fflig',#64260'ffllig',#64257'filig',#9837'flat',#64258'fllig',#9649'fltns',#402'fnof',#8704'forall',#8916'fork',#10969'forkv',#10765'fpartint',#189'frac12',#8531'frac13',#188'frac14',#8533'frac15',#8537'frac16',#8539'frac18',#8532'frac23',#8534'frac25',#190'frac34',#8535'frac35',#8540'frac38',#8536'frac45',#8538'frac56',#8541'frac58',#8542'frac78',
   #8260'frasl',#8994'frown',#8807'ge',#10892'gel',#501'gacute',#947'gamma',#989'gammad',#10886'gap',#287'gbreve',#285'gcirc',#1075'gcy',#289'gdot',#8805'ge',#8923'gel',#8805'geq',#8807'geqq',#10878'geqslant',#10878'ges',#10921'gescc',#10880'gesdot',#10882'gesdoto',#10884'gesdotol',#10900'gesles',#8811'gg',#8921'ggg',#8503'gimel',#1107'gjcy',#8823'gl',#10898'gle',#10917'gla',#10916'glj',#8809'gne',#10890'gnap',#10890'gnapprox',#10888'gne',#10888'gneq',#8809'gneqq',#8935'gnsim',#96'grave',#8458'gscr',#8819'gsim',#10894'gsime',#10896'gsiml',#62'gt',#10919'gtcc',#10874'gtcir',#8919'gtdot',
   #10645'gtlpar',#10876'gtquest',#10886'gtrapprox',#10616'gtrarr',#8919'gtrdot',#8923'gtreqless',#10892'gtreqqless',#8823'gtrless',#8819'gtrsim',#8660'harr',#8202'hairsp',#189'half',#8459'hamilt',#1098'hardcy',#8596'harr',#10568'harrcir',#8621'harrw',#8463'hbar',#293'hcirc',#9829'hearts',#9829'heartsuit',#8230'hellip',#8889'hercon',#10533'hksearow',#10534'hkswarow',#8703'hoarr',#8763'homtht',#8617'hookleftarrow',#8618'hookrightarrow',#8213'horbar',#8463'hslash',#295'hstrok',#8259'hybull',#8208'hyphen',#237'iacute',#8291'ic',#238'icirc',#1080'icy',#1077'iecy',#161'iexcl',#8660'iff',#236'igrave',#8520'ii',#10764'iiiint',#8749'iiint',#10716'iinfin',
   #8489'iiota',#307'ijlig',#299'imacr',#8465'image',#8464'imagline',#8465'imagpart',#305'imath',#8887'imof',#437'imped',#8712'in',#8453'incare',#8734'infin',#10717'infintie',#305'inodot',#8747'int',#8890'intcal',#8484'integers',#8890'intercal',#10775'intlarhk',#10812'intprod',#1105'iocy',#303'iogon',#953'iota',#10812'iprod',#191'iquest',#8712'isin',#8953'isine',#8949'isindot',#8948'isins',#8947'isinsv',#8712'isinv',#8290'it',#297'itilde',#1110'iukcy',#239'iuml',#309'jcirc',#1081'jcy',#567'jmath',#1112'jsercy',#1108'jukcy',#954'kappa',#1008'kappav',#311'kcedil',#1082'kcy',
   #312'kgreen',#1093'khcy',#1116'kjcy',#8666'laarr',#8656'larr',#10523'latail',#10510'lbarr',#8806'le',#10891'leg',#10594'lhar',#314'lacute',#10676'laemptyv',#8466'lagran',#955'lambda',#10216'lang',#10641'langd',#10216'langle',#10885'lap',#171'laquo',#8592'larr',#8676'larrb',#10527'larrbfs',#10525'larrfs',#8617'larrhk',#8619'larrlp',#10553'larrpl',#10611'larrsim',#8610'larrtl',#10923'lat',#10521'latail',#10925'late',#10508'lbarr',#10098'lbbrk',#123'lbrace',#91'lbrack',#10635'lbrke',#10639'lbrksld',#10637'lbrkslu',#318'lcaron',#316'lcedil',#8968'lceil',#123'lcub',#1083'lcy',#10550'ldca',#8220'ldquo',#8222'ldquor',#10599'ldrdhar',#10571'ldrushar',
   #8626'ldsh',#8804'le',#8592'leftarrow',#8610'leftarrowtail',#8637'leftharpoondown',#8636'leftharpoonup',#8647'leftleftarrows',#8596'leftrightarrow',#8646'leftrightarrows',#8651'leftrightharpoons',#8621'leftrightsquigarrow',#8907'leftthreetimes',#8922'leg',#8804'leq',#8806'leqq',#10877'leqslant',#10877'les',#10920'lescc',#10879'lesdot',#10881'lesdoto',#10883'lesdotor',#10899'lesges',#10885'lessapprox',#8918'lessdot',#8922'lesseqgtr',#10891'lesseqqgtr',#8822'lessgtr',#8818'lesssim',#10620'lfisht',#8970'lfloor',#8822'lg',#10897'lge',#8637'lhard',#8636'lharu',#10602'lharul',#9604'lhblk',#1113'ljcy',#8810'll',#8647'llarr',#8990'llcorner',#10603'llhard',#9722'lltri',#320'lmidot',#9136'lmoust',#9136'lmoustache',#8808'lne',#10889'lnap',#10889'lnapprox',#10887'lne',
   #10887'lneq',#8808'lneqq',#8934'lnsim',#10220'loang',#8701'loarr',#10214'lobrk',#10229'longleftarrow',#10231'longleftrightarrow',#10236'longmapsto',#10230'longrightarrow',#8619'looparrowleft',#8620'looparrowright',#10629'lopar',#10797'loplus',#10804'lotimes',#8727'lowast',#95'lowbar',#9674'loz',#9674'lozenge',#10731'lozf',#40'lpar',#10643'lparlt',#8646'lrarr',#8991'lrcorner',#8651'lrhar',#10605'lrhard',#8206'lrm',#8895'lrtri',#8249'lsaquo',#8624'lsh',#8818'lsim',#10893'lsime',#10895'lsimg',#91'lsqb',#8216'lsquo',#8218'lsquor',#322'lstrok',#60'lt',#10918'ltcc',#10873'ltcir',#8918'ltdot',#8907'lthree',#8905'ltimes',#10614'ltlarr',#10875'ltquest',#10646'ltrpar',#9667'ltri',#8884'ltrie',
   #9666'ltrif',#10570'lurdshar',#10598'luruhar',#8762'mddot',#175'macr',#9794'male',#10016'malt',#10016'maltese',#8614'map',#8614'mapsto',#8615'mapstodown',#8612'mapstoleft',#8613'mapstoup',#9646'marker',#10793'mcomma',#1084'mcy',#8212'mdash',#8737'measuredangle',#8487'mho',#181'micro',#8739'mid',#42'midast',#10992'midcir',#183'middot',#8722'minus',#8863'minusb',#8760'minusd',#10794'minusdu',#10971'mlcp',#8230'mldr',#8723'mnplus',#8871'models',#8723'mp',#8766'mstpos',#956'mu',#8888'multimap',#8888'mumap',#8653'nleftarrow',#8654'nleftrightarrow',#8655'nrightarrow',#8879'nvdash',#8878'nvdash',#8711'nabla',#324'nacute',#8777'nap',#329'napos',#8777'napprox',
   #9838'natur',#9838'natural',#8469'naturals',#160'nbsp',#10819'ncap',#328'ncaron',#326'ncedil',#8775'ncong',#10818'ncup',#1085'ncy',#8211'ndash',#8800'ne',#8663'nearr',#10532'nearhk',#8599'nearr',#8599'nearrow',#8802'nequiv',#10536'nesear',#8708'nexist',#8708'nexists',#8817'nge',#8817'ngeq',#8821'ngsim',#8815'ngt',#8815'ngtr',#8654'nharr',#8622'nharr',#10994'nhpar',#8715'ni',#8956'nis',#8954'nisd',#8715'niv',#1114'njcy',#8653'nlarr',#8602'nlarr',#8229'nldr',#8816'nle',#8602'nleftarrow',#8622'nleftrightarrow',#8816'nleq',#8814'nless',#8820'nlsim',#8814'nlt',#8938'nltri',#8940'nltrie',#8740'nmid',#172'not',#8713'notin',
   #8713'notinva',#8951'notinvb',#8950'notinvc',#8716'notni',#8716'notniva',#8958'notnivb',#8957'notnivc',#8742'npar',#8742'nparallel',#10772'npolint',#8832'npr',#8928'nprcue',#8832'nprec',#8655'nrarr',#8603'nrarr',#8603'nrightarrow',#8939'nrtri',#8941'nrtrie',#8833'nsc',#8929'nsccue',#8740'nshortmid',#8742'nshortparallel',#8769'nsim',#8772'nsime',#8772'nsimeq',#8740'nsmid',#8742'nspar',#8930'nsqsube',#8931'nsqsupe',#8836'nsub',#8840'nsube',#8840'nsubseteq',#8833'nsucc',#8837'nsup',#8841'nsupe',#8841'nsupseteq',#8825'ntgl',#241'ntilde',#8824'ntlg',#8938'ntriangleleft',#8940'ntrianglelefteq',#8939'ntriangleright',#8941'ntrianglerighteq',#957'nu',#35'num',#8470'numero',#8199'numsp',#8877'nvdash',#10500'nvharr',
   #8876'nvdash',#10718'nvinfin',#10498'nvlarr',#10499'nvrarr',#8662'nwarr',#10531'nwarhk',#8598'nwarr',#8598'nwarrow',#10535'nwnear',#9416'os',#243'oacute',#8859'oast',#8858'ocir',#244'ocirc',#1086'ocy',#8861'odash',#337'odblac',#10808'odiv',#8857'odot',#10684'odsold',#339'oelig',#10687'ofcir',#731'ogon',#242'ograve',#10689'ogt',#10677'ohbar',#937'ohm',#8750'oint',#8634'olarr',#10686'olcir',#10683'olcross',#8254'oline',#10688'olt',#333'omacr',#969'omega',#959'omicron',#10678'omid',#8854'ominus',#10679'opar',#10681'operp',#8853'oplus',#8744'or',#8635'orarr',#10845'ord',#8500'order',#8500'orderof',#170'ordf',#186'ordm',
   #8886'origof',#10838'oror',#10839'orslope',#10843'orv',#8500'oscr',#248'oslash',#8856'osol',#245'otilde',#8855'otimes',#10806'otimesas',#246'ouml',#9021'ovbar',#8741'par',#182'para',#8741'parallel',#10995'parsim',#11005'parsl',#8706'part',#1087'pcy',#37'percnt',#46'period',#8240'permil',#8869'perp',#8241'pertenk',#966'phi',#981'phiv',#8499'phmmat',#9742'phone',#960'pi',#8916'pitchfork',#982'piv',#8463'planck',#8462'planckh',#8463'plankv',#43'plus',#10787'plusacir',#8862'plusb',#10786'pluscir',#8724'plusdo',#10789'plusdu',#10866'pluse',#177'plusmn',#10790'plussim',#10791'plustwo',#177'pm',#10773'pointint',#163'pound',#8826'pr',
   #10931'pre',#10935'prap',#8828'prcue',#10927'pre',#8826'prec',#10935'precapprox',#8828'preccurlyeq',#10927'preceq',#10937'precnapprox',#10933'precneqq',#8936'precnsim',#8830'precsim',#8242'prime',#8473'primes',#10933'prne',#10937'prnap',#8936'prnsim',#8719'prod',#9006'profalar',#8978'profline',#8979'profsurf',#8733'prop',#8733'propto',#8830'prsim',#8880'prurel',#968'psi',#8200'puncsp',#10764'qint',#8279'qprime',#8461'quaternions',#10774'quatint',#63'quest',#8799'questeq',#34'quot',#8667'raarr',#8658'rarr',#10524'ratail',#10511'rbarr',#10596'rhar',#341'racute',#8730'radic',#10675'raemptyv',#10217'rang',#10642'rangd',#10661'range',#10217'rangle',
   #187'raquo',#8594'rarr',#10613'rarrap',#8677'rarrb',#10528'rarrbfs',#10547'rarrc',#10526'rarrfs',#8618'rarrhk',#8620'rarrlp',#10565'rarrpl',#10612'rarrsim',#8611'rarrtl',#8605'rarrw',#10522'ratail',#8758'ratio',#8474'rationals',#10509'rbarr',#10099'rbbrk',#125'rbrace',#93'rbrack',#10636'rbrke',#10638'rbrksld',#10640'rbrkslu',#345'rcaron',#343'rcedil',#8969'rceil',#125'rcub',#1088'rcy',#10551'rdca',#10601'rdldhar',#8221'rdquo',#8221'rdquor',#8627'rdsh',#8476'real',#8475'realine',#8476'realpart',#8477'reals',#9645'rect',#174'reg',#10621'rfisht',#8971'rfloor',#8641'rhard',#8640'rharu',#10604'rharul',#961'rho',#1009'rhov',#8594'rightarrow',#8611'rightarrowtail',#8641'rightharpoondown',
   #8640'rightharpoonup',#8644'rightleftarrows',#8652'rightleftharpoons',#8649'rightrightarrows',#8605'rightsquigarrow',#8908'rightthreetimes',#730'ring',#8787'risingdotseq',#8644'rlarr',#8652'rlhar',#8207'rlm',#9137'rmoust',#9137'rmoustache',#10990'rnmid',#10221'roang',#8702'roarr',#10215'robrk',#10630'ropar',#10798'roplus',#10805'rotimes',#41'rpar',#10644'rpargt',#10770'rppolint',#8649'rrarr',#8250'rsaquo',#8625'rsh',#93'rsqb',#8217'rsquo',#8217'rsquor',#8908'rthree',#8906'rtimes',#9657'rtri',#8885'rtrie',#9656'rtrif',#10702'rtriltri',#10600'ruluhar',#8478'rx',#347'sacute',#8218'sbquo',#8827'sc',#10932'sce',#10936'scap',#353'scaron',#8829'sccue',#10928'sce',#351'scedil',#349'scirc',#10934'scne',
   #10938'scnap',#8937'scnsim',#10771'scpolint',#8831'scsim',#1089'scy',#8901'sdot',#8865'sdotb',#10854'sdote',#8664'searr',#10533'searhk',#8600'searr',#8600'searrow',#167'sect',#59'semi',#10537'seswar',#8726'setminus',#8726'setmn',#10038'sext',#8994'sfrown',#9839'sharp',#1097'shchcy',#1096'shcy',#8739'shortmid',#8741'shortparallel',#173'shy',#963'sigma',#962'sigmaf',#962'sigmav',#8764'sim',#10858'simdot',#8771'sime',#8771'simeq',#10910'simg',#10912'simge',#10909'siml',#10911'simle',#8774'simne',#10788'simplus',#10610'simrarr',#8592'slarr',#8726'smallsetminus',#10803'smashp',#10724'smeparsl',#8739'smid',#8995'smile',#10922'smt',#10924'smte',#1100'softcy',#47'sol',
   #10692'solb',#9023'solbar',#9824'spades',#9824'spadesuit',#8741'spar',#8851'sqcap',#8852'sqcup',#8847'sqsub',#8849'sqsube',#8847'sqsubset',#8849'sqsubseteq',#8848'sqsup',#8850'sqsupe',#8848'sqsupset',#8850'sqsupseteq',#9633'squ',#9633'square',#9642'squarf',#9642'squf',#8594'srarr',#8726'ssetmn',#8995'ssmile',#8902'sstarf',#9734'star',#9733'starf',#1013'straightepsilon',#981'straightphi',#175'strns',#8834'sub',#10949'sube',#10941'subdot',#8838'sube',#10947'subedot',#10945'submult',#10955'subne',#8842'subne',#10943'subplus',#10617'subrarr',#8834'subset',#8838'subseteq',#10949'subseteqq',#8842'subsetneq',#10955'subsetneqq',#10951'subsim',#10965'subsub',#10963'subsup',#8827'succ',#10936'succapprox',
   #8829'succcurlyeq',#10928'succeq',#10938'succnapprox',#10934'succneqq',#8937'succnsim',#8831'succsim',#8721'sum',#9834'sung',#185'sup1',#178'sup2',#179'sup3',#8835'sup',#10950'supe',#10942'supdot',#10968'supdsub',#8839'supe',#10948'supedot',#10185'suphsol',#10967'suphsub',#10619'suplarr',#10946'supmult',#10956'supne',#8843'supne',#10944'supplus',#8835'supset',#8839'supseteq',#10950'supseteqq',#8843'supsetneq',#10956'supsetneqq',#10952'supsim',#10964'supsub',#10966'supsup',#8665'swarr',#10534'swarhk',#8601'swarr',#8601'swarrow',#10538'swnwar',#223'szlig',#8982'target',#964'tau',#9140'tbrk',#357'tcaron',#355'tcedil',#1090'tcy',#8411'tdot',#8981'telrec',#8756'there4',#8756'therefore',#952'theta',
   #977'thetasym',#977'thetav',#8776'thickapprox',#8764'thicksim',#8201'thinsp',#8776'thkap',#8764'thksim',#254'thorn',#732'tilde',#215'times',#8864'timesb',#10801'timesbar',#10800'timesd',#8749'tint',#10536'toea',#8868'top',#9014'topbot',#10993'topcir',#10970'topfork',#10537'tosa',#8244'tprime',#8482'trade',#9653'triangle',#9663'triangledown',#9667'triangleleft',#8884'trianglelefteq',#8796'triangleq',#9657'triangleright',#8885'trianglerighteq',#9708'tridot',#8796'trie',#10810'triminus',#10809'triplus',#10701'trisb',#10811'tritime',#9186'trpezium',#1094'tscy',#1115'tshcy',#359'tstrok',#8812'twixt',#8606'twoheadleftarrow',#8608'twoheadrightarrow',#8657'uarr',#10595'uhar',#250'uacute',#8593'uarr',#1118'ubrcy',#365'ubreve',
   #251'ucirc',#1091'ucy',#8645'udarr',#369'udblac',#10606'udhar',#10622'ufisht',#249'ugrave',#8639'uharl',#8638'uharr',#9600'uhblk',#8988'ulcorn',#8988'ulcorner',#8975'ulcrop',#9720'ultri',#363'umacr',#168'uml',#371'uogon',#8593'uparrow',#8597'updownarrow',#8639'upharpoonleft',#8638'upharpoonright',#8846'uplus',#965'upsi',#978'upsih',#965'upsilon',#8648'upuparrows',#8989'urcorn',#8989'urcorner',#8974'urcrop',#367'uring',#9721'urtri',#8944'utdot',#361'utilde',#9653'utri',#9652'utrif',#8648'uuarr',#252'uuml',#10663'uwangle',#8661'varr',#10984'vbar',#10985'vbarv',#8872'vdash',#10652'vangrt',#1013'varepsilon',#1008'varkappa',#8709'varnothing',#981'varphi',
   #982'varpi',#8733'varpropto',#8597'varr',#1009'varrho',#962'varsigma',#977'vartheta',#8882'vartriangleleft',#8883'vartriangleright',#1074'vcy',#8866'vdash',#8744'vee',#8891'veebar',#8794'veeeq',#8942'vellip',#124'verbar',#124'vert',#8882'vltri',#8733'vprop',#8883'vrtri',#10650'vzigzag',#373'wcirc',#10847'wedbar',#8743'wedge',#8793'wedgeq',#8472'weierp',#8472'wp',#8768'wr',#8768'wreath',#8898'xcap',#9711'xcirc',#8899'xcup',#9661'xdtri',#10234'xharr',#10231'xharr',#958'xi',#10232'xlarr',#10229'xlarr',#10236'xmap',#8955'xnis',#10752'xodot',#10753'xoplus',#10754'xotime',
   #10233'xrarr',#10230'xrarr',#10758'xsqcup',#10756'xuplus',#9651'xutri',#8897'xvee',#8896'xwedge',#253'yacute',#1103'yacy',#375'ycirc',#1099'ycy',#165'yen',#1111'yicy',#1102'yucy',#255'yuml',#378'zacute',#382'zcaron',#1079'zcy',#380'zdot',#8488'zeetrf',#950'zeta',#1078'zhcy',#8669'zigrarr',#8205'zwj',#8204'zwnj'
 );

var
 whiteList:TVarHash; // list of allowed elements
 blackList:TVarHash; // list of forbidden elements
 parentList:TVarHash; // whitelist of allowed parent elements
 entities:TVarHash; // entity name -> code point


function DecodeHTMLString(src:string):string; // replace HTML entities with corresponging characters
var
 i,p,n,code:integer;
 ent:string;
begin
 SetLength(result,length(src));
 i:=1; n:=0;
 while i<=length(src) do begin
   if src[i]='&' then begin
     ent:='';
     p:=i; inc(i);
     while i<=length(src) do begin
       if src[i] in ['#','A'..'Z','a'..'z','0'..'9'] then ent:=ent+src[i]
         else break; // unallowed character
       inc(i);
     end;
     if (i<=length(src)) and (src[i]=';') then inc(i);
     code:=-1;
     // Check if ent contains a valid entity name or number
     if ent.StartsWith('#') then begin
       delete(ent,1,1);
       if ent.StartsWith('x') then code:=integer(HexToInt(ent)) // avoid range error
         else code:=integer(ParseInt(ent));
     end else begin
       if entities.HasKey(ent) then
         code:=entities.Get(ent);
     end;
     if code>=0 then begin // success
       {$IFDEF UNICODE}
       inc(n);
       result[n]:=Char(code);
       {$ELSE}
       ent:=UTF8Encode(WideChar(code));
       move(ent[1],result[n],length(ent));
       inc(n,length(ent));
       {$ENDIF}
     end else begin // failed -> copy original
       move(src[p],result[n+1],(i-p)*sizeof(char));
       inc(n,i-p);
     end;
   end else begin
     inc(n);
     result[n]:=src[i];
     inc(i);
   end;
 end;
 Setlength(result,n);
end;

// Find the next unquoted '>' character
function FindTagEnd(const st:string;startPos:integer):integer;
var
 i:integer;
 quote:char;
begin
 quote:=#0;
 i:=startPos;
 while i<=length(st) do begin
   if quote=#0 then begin
    if st[i]='>' then exit(i);
    if st[i] in ['"',''''] then quote:=st[i];
   end else begin
    if (st[i]=quote) and (st[i-1]<>'\') then quote:=#0;
   end;
   inc(i);
 end;
end;

function ParseHTML(st:string):THtmlElement;
type
 TState=(stateText,stateComment,stateTag);
var
 root:THtmlElement;
 stack:TArray<THtmlElement>;
 i,p:integer;
 node:THtmlNode;
 element:THtmlElement;
 tag:string;
begin
 root:=THtmlElement.Create(nil);
 stack.Add(root);
 i:=1; // current position
 repeat
   // loop always starts in the "text" state
   p:=pos('<',st,i); // EOF or '<' symbol
   if p=0 then p:=length(st)+1;
   if p>i then begin
     // create text node
     node:=THtmlText.Create(stack.Last,DecodeHtmlString(copy(st,i,p-i)));
     i:=p;
   end;
   if i>length(st) then break;
   if (i+3<length(st)) and (st[i+1]='!') and (st[i+2]='-') and (st[i+3]='-') then begin
     // comment node
     p:=pos('-->',st,i+4);
     if i=0 then p:=length(st)+1;
     node:=THtmlComment.Create(stack.Last,copy(st,i,p-i));
     i:=p+3;
     continue;
   end;
   // html close tag?
   if (i<length(st)) and (st[i+1]='/') then begin
     // closing tag
     p:=pos('>',st,i+1);
     tag:=copy(st,i+2,p-i-2);
     tag:=Lowercase(Chop(tag));
     i:=p+1;
     // Close tags
     for p:=stack.count-1 downto 1 do
      if tag=THtmlElement(stack.items[p]).tag then begin
        SetLength(stack.items,p); // trim the stack to this element
        break;
      end;
     continue;
   end;
   // Regular HTML tag
   p:=FindTagEnd(st,i+1);
   if p=0 then p:=length(st)+1;
   element:=THtmlElement.Create(nil,copy(st,i,p-i+1));
   i:=p+1;
   // Autoclose some elements?
   while stack.Count>1 do
     if THtmlElement(stack.Last).CanContain(element.tag) then break
       else stack.Pop;
   // Append element to the tree
   stack.Last.AddChild(element);
   // Process element
   if element.IsForeign or element.IsRawtext then begin
     // find end tag and create a text node for the whole content
     p:=PosFrom('</'+element.tag+'>',st,i,true); // To be accurate, space chars are allowed before '>'
     if p=0 then p:=length(st)+1;
     if element.IsForeign then
       THtmlForeignContent.Create(element,copy(st,i,p-i))
     else
       THtmlText.Create(element,copy(st,i,p-i));
     i:=pos('>',st,p)+1;
     continue;
   end else
   if not element.IsVoid then
     stack.Add(element); // push element to the stack
 until false;

 result:=root;
end;

{ THtmlNode }

constructor THtmlNode.Create(parent:THtmlElement;text:string);
begin
 self.parent:=parent;
 self.text:=text;
 if parent<>nil then parent.AddChild(self);
end;

function THtmlNode.Depth:integer;
var
 node:THtmlNode;
begin
 result:=0;
 node:=self;
 while node.parent<>nil do begin
  inc(result);
  node:=node.parent;
 end;
end;

destructor THtmlNode.Destroy;
begin
 if parent<>nil then parent.RemoveChild(self);
 inherited;
end;

{ THtmlElement }

constructor THtmlElement.Create(parent:THtmlElement; text:string);
var
 i,p:integer;
 name,value:string;
begin
 inherited;
 if text='' then exit;
 ASSERT(text.StartsWith('<') and text.EndsWith('>'),'Malformed tag: '+text);
 i:=2;
 // Extract tagname
 while (i<=length(text)) and not (text[i] in [' ',#9,#10,#13,'>']) do inc(i);
 tag:=Lowercase(copy(text,2,i-2));
 // Extract attributes
 while i<length(text) do begin
  // skip whitespace
  while (i<=length(text)) and (text[i] in [' ',#9,#10,#13]) do inc(i);
  // get attribute name
  p:=i;
  while (p<=length(text)) and not (text[p] in [' ','=',#9,#10,#13,'>']) do inc(p);
  name:=copy(text,i,p-i); // can be empty
  i:=p;
  // Skip whitespace before '='
  while (i<=length(text)) and (text[i] in [' ',#9,#10,#13]) do inc(i);
  if text[i]<>'=' then begin
    // no value
    if name<>'' then attributes.Item[name]:=''; // add attribute without value
    continue;
  end;
  inc(i); // next char after '=' - skip whitespace
  while (i<=length(text)) and (text[i] in [' ',#9,#10,#13]) do inc(i);
  // Extract value
  if (text[i]='''') or (text[i]='"') then begin
    // quoted value
    p:=i;
    repeat
     p:=PosFrom(text[i],text,p+1);
     if p=0 then begin
      // no end quote
      p:=length(text)-1;
      break;
     end;
     if text[p-1]<>'\' then break; // found first unescaped end quote
    until false;
    value:=copy(text,i+1,p-i-1);
    i:=p+1;
  end else begin
    // unquoted value - grab all up to the nearest space/terminator char
    p:=i;
    while (p<=length(text)) and not (text[p] in [' ',#9,#10,#13,'>']) do inc(p);
    value:=copy(text,i,p-i);
    i:=p;
  end;
  if name<>'' then attributes.Item[name]:=value;
 end;
end;

destructor THtmlElement.Destroy;
begin
 while children.Count>0 do children.Pop.Free; // delete children
 inherited;
end;

function THtmlElement.GetElement(tag,attribute,contains:string):THtmlElement;
var
 i:integer;
 aIdx:integer;
begin
 result:=nil;
 // Check if this element meets the search criteria
 if (tag='') or SameText(tag,self.tag) then begin
  result:=self;
  if attribute<>'' then begin // element must have specified attribute
   aIdx:=attributes.Find(attribute);
   if aIdx<0 then result:=nil
   else begin
    if (contains<>'') and (PosFrom(contains,attributes.items[aIdx].value,1,true)=0) then result:=nil;
   end;
  end;
 end;
 if result<>nil then exit;
 for i:=0 to children.Count-1 do
  if children.items[i] is THtmlElement then
   with children.items[i] as THtmlElement do begin
    result:=GetElement(tag,attribute,contains);
    if result<>nil then exit;
   end;
end;

function THtmlElement.HasAttribute(aName:string):boolean;
begin
 result:=attributes.HasName(aName);
end;

function THtmlElement.GetAttribute(aName:string):string;
begin
 result:=attributes.Item[aName];
end;

function THtmlElement.ChildElementCount:integer;
var
 child:THtmlNode;
begin
  result:=0;
  for child in children.items do
   if child is THtmlElement then inc(result);
end;

function THtmlElement.GetChildElement(index:integer):THtmlElement;
var
 child:THtmlNode;
begin
  result:=nil;
  for child in children.items do
   if child is THtmlElement then begin
     if index=0 then exit(THtmlElement(child));
     dec(index);
   end;
end;

function THtmlElement.AttributeContains(aName,substr:string):boolean;
var
 idx:integer;
begin
 result:=false;
 idx:=attributes.Find(aName);
 if idx<0 then exit;
 result:=PosFrom(substr,attributes.items[idx].value,1,true)>0;
end;

function THtmlElement.InnerText:string;
var
 i:integer;
begin
 result:='';
 for i:=0 to children.count-1 do begin
  if children.items[i] is THtmlText then
   result:=result+THtmlText(children.items[i]).text;
  if children.items[i] is THtmlElement then
   result:=result+THtmlElement(children.items[i]).InnerText;
 end;
end;

procedure THtmlElement.AddChild(node:THtmlNode);
begin
 children.Add(node);
 node.parent:=self;
end;

procedure THtmlElement.RemoveChild(node:THtmlNode);
begin
 children.Remove(node,true);
 node.parent:=nil;
end;

function THtmlElement.CanContain(childTag:string):boolean;
var
 st:string;
begin
 result:=true;
 st:=parentList.Get(childTag); // child's parent whitelist
 if (st<>'') and (pos('|'+tag+'|',st)=0) then exit(false);
 childTag:='|'+childTag+'|';
 if not IsBlock then  // non-block emlement can't contain a block element
  if pos(childtag,BLOCK_ELEMENTS)>0 then exit(false);
 st:=whiteList.Get(tag); // if has whitelist: child must be whitelisted
 if (st<>'') and (pos(childTag,st)=0) then exit(false);
 st:=blackList.Get(tag); // child must not be blacklisted
 if pos(childTag,st)>0 then exit(false);
end;

procedure THtmlElement.Visit(visitor:THtmlNodeVisitor;context:pointer);
var
 i:integer;
begin
 for i:=0 to children.count-1 do begin
  visitor(children.items[i],context);
  if children.items[i] is THtmlElement then
   THtmlElement(children.items[i]).Visit(visitor,context);
 end;
end;

procedure THtmlElement.VisitElements(visitor:THtmlElementVisitor;context:pointer;tag:string);
var
 i:integer;
begin
 if (tag='') or (SameText(tag,self.tag)) then
  visitor(self,context);
 for i:=0 to children.count-1 do
  if children.items[i] is THtmlElement then
   THtmlElement(children.items[i]).VisitElements(visitor,context,tag);
end;

procedure PrintVisitor(node:THtmlNode;context:pointer);
var
 st:PString;
 txt:string;
 depth:integer;
begin
 depth:=node.Depth;
 if depth=0 then exit;
 txt:=StringOfChar(#9,depth-1);
 txt:=txt+StringReplace(node.text,#13#10,'',[rfReplaceAll]);
 st:=context;
 st^:=st^+txt+#13#10;
end;

function THtmlElement.PrintTree:string;
var
 str:string;
begin
 str:='';
 Visit(PrintVisitor,@str);
 result:=str;
end;

function THtmlElement.IsBlock: boolean;
begin
 result:=pos('|'+tag+'|',BLOCK_ELEMENTS)>0;
end;

function THtmlElement.IsForeign:boolean;
begin
 result:=pos('|'+tag+'|',FOREIGN_ELEMENTS)>0;
end;

function THtmlElement.IsRawtext:boolean;
begin
 result:=pos('|'+tag+'|',RAWTEXT_ELEMENTS)>0;
end;

function THtmlElement.IsVoid:boolean;
begin
 result:=pos('|'+tag+'|',VOID_ELEMENTS)>0;
end;

var
 node:THtmlElement;
 st:string;
 t:int64;
 i:integer;

initialization
 with whiteList do begin
  Put('table','|caption|col|colgroup|thead|tfoot|tbody|tr|');
  Put('colgroup','|col|');
  Put('thead','|tr|');
  Put('tfoot','|tr|');
  Put('tbody','|tr|');
  Put('tr','|td|th|');
  Put('dl','|dt|dd|');
  Put('ol','|li|');
  Put('ul','|li|');
  Put('select','|optgroup|option|');
  Put('optgroup','|option|');
 end;
 with blackList do begin // https://html.spec.whatwg.org/multipage/syntax.html#syntax-tag-omission
  Put('head','|body|');
  Put('p','|p|address|article|aside|blockquote|details|div|dl|fieldset|figcaption|'+
    'figure|footer|form|h1|h2|h3|h4|h5|h6|header|hgroup|hr|main|menu|nav|ol|pre|section|table|or|ul|');
 end;
 with parentList do begin
  Put('li','|ul|ol|');
  Put('tr','|table|thead|tbody|tfoot|');
  Put('td','|tr|');
  Put('th','|tr|');
 end;

 // Init hash of entities
 entities.Init(length(ENTITIES_LIST)*2);
 for i:=0 to high(ENTITIES_LIST) do
  entities.Put(String8(copy(ENTITIES_LIST[i],2,100)),Word(ENTITIES_LIST[i][1]));

 //node:=ParseHTML('<div>123</div>');
 //node:=ParseHTML('<div><p>1<p>2</p>3');
 //DecodeHtmlString('&#12345678912345678123443653656546456546');
 //DecodeHtmlString('&#x0');
 //DecodeHtmlString('&xxx');
 //DecodeHtmlString('A&quot;_&#66;&ksdhkh&#x44');
{ // Debug test
 st:=LoadFileAsString('test.htm');
 st:=LoadFileAsString('content.htm');
 t:=MyTickCount;
 node:=ParseHTML(st);
 t:=MyTickCount-t;
 st:=node.PrintTree;
 SaveFile('tree.txt',Utf8String(st));
 writeln(t,node.tag);  }
end.
