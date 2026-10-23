# Configuration Files (CTL3)

**Status: draft for review.** Nothing described here is implemented yet; the current code is
`Base/Apus.ControlFiles.pas` (format CTL2). Once accepted, this chapter is the reference for
the intended behaviour of `Apus.Config`: where the code differs from the text, the text wins
and the code is the thing to fix. Open points are collected in section 12.

## 1) Purpose and scope

`Apus.Config` reads and writes hierarchical configuration documents: engine and game
settings, resource descriptions (sounds, music), server settings, and data files produced
by tools (levels). One syntax, **CTL3**, covers all of them. The same parser also reads:

- **CTL2**, the format of `Apus.ControlFiles` (`$Section`/`$EndOfSection`/`$Include`), so
  existing data files keep working without conversion;
- **a JSON subset** (section 3.8), for data produced by web services and external tools.

Not covered: encryption and signing algorithms (section 8 defines only the interface to
them), the binary CTL2 format (not supported), and compatibility with the `ctlGet*`
procedural API (there is no facade).

## 2) Concepts

**Document (`TConfig`).** An object holding a stack of *layers*. Code reads and writes the
document through *node handles*; it never sees the layers directly.

**Layer.** One source file together with the files it includes, parsed into a tree. Layers
are ordered bottom to top: shipped defaults first, user settings above them, command-line
overrides on top. A read looks through the layers from the top; a write goes into the one
*writable* layer (section 6).

**Node.** An element of the tree. Its kind is one of:

| Kind | Meaning |
|---|---|
| `ckSection` | named children in source order; the root of every layer is a section |
| `ckArray` | unnamed items in order; items may be of any kind |
| `ckScalar` | a single value, stored as its **source text** (the lexeme) |
| `ckNull` | JSON `null`: present, but reads return the default |
| `ckNone` | the node does not exist (handles to missing nodes are valid, see 5.1) |

**The reader decides the type.** A scalar has no type of its own. `Int`, `Float`, `Bool` and
`Str` interpret the same lexeme on request (section 4). `loopTime 1` and `loopTime 0.5` are
both floats for `Float`; `version 1.10` stays `"1.10"` for `Str`; `lang no` stays `"no"` for
`Str` and is `false` only for `Bool`.

**Keys** are case-insensitive (ASCII letters only are folded); the original spelling is kept
for output and iteration.

## 3) Syntax

### 3.1 Example

```
# Engine and game settings
instanceID = 35672194

options {
  fullScreen   = off
  windowWidth  = 1024
  windowHeight = 768
  title        = "My game"         # inline comment
}

music {
  intro { file = "intro.ogg", volume = 50, loop = on }
  battle {
    file     = "battle.ogg"
    loopTime = 12.5
  }
}

spawnPoints = [
  { x = 10, y = 20 }
  { x = 30, y = 5 }
]
preload = ["click.ogg", "hit.ogg"]

@include "controls.ctl"
```

### 3.2 Lexical rules

- **Encoding:** UTF-8. A BOM is accepted and kept on save. Line ends are LF or CRLF; the
  style of the file is kept on save, a new file uses `sLineBreak`.
- **Comments:**
  - `#` starts a comment at the start of a line or after whitespace, except where a value
    begins: `color #FF8000` is the value `#FF8000`, `url = http://a/#top` keeps its `#`.
  - `//` and `;` start a comment only as the first non-blank characters of a line (`;` is
    kept for CTL2 habits).
- **Unquoted key:** a run of letters, digits, `_`, `-` and bytes `$80..$FF` (UTF-8 text).
  A key with any other character (a dot, a space) is written in double quotes:
  `"window.size" = 3`.
- **Separator** between a key and its value: whitespace, `=` or `:`, each optional.
  `width 800`, `width=800`, `width = 800` and `"width": 800` are the same item.
- **Items** are separated by line ends or commas. A trailing comma is allowed.

### 3.3 Scalars

- **Double-quoted string** `"..."`: escapes `\"` `\\` `\n` `\r` `\t` `\uXXXX` (a surrogate
  pair forms one character). Any other `\x` keeps both characters as they are.
- **Single-quoted string** `'...'`: raw, no escapes (Windows paths: `'C:\Games\new'`). A
  single quote inside is written as two quotes `''`.
- **Bare value:** everything else, up to the end of the line or a comment, with surrounding
  spaces trimmed. Inside an inline container (3.4) a bare value also ends at `,`, `}` or
  `]`. On a line of its own a trailing `,` is a separator, not part of the value. So
  `title = Hello, world` is `"Hello, world"`, and `"a": 1,` in a multi-line JSON object is
  `1`.
- **`null`** (bare) is a `ckNull` node.

A value that must keep leading or trailing spaces, starts with `"`, `'`, `{`, `[` or `(`, or
contains a line break needs quotes.

### 3.4 Sections and arrays

- **Block section:** `name {` at the end of a line, the items on the following lines, and
  `}` as the first non-blank character of a line.
- **Inline section:** `name { a = 1, b = 2 }` or `name = { ... }` on one line. Inside it,
  items are separated by commas.
- **Array:** `[ value, value, ... ]`, one line or several. Items are separated by commas or
  line ends; an item may be a scalar, an inline or block section `{ ... }`, or an array.
  `( ... )` is accepted as a synonym of `[ ... ]` (CTL2 lists).
- **Root:** the items of the file are the children of the layer root. A file whose first
  significant character is `{` is a JSON-style root object: it must be the only top-level
  item.

### 3.5 Duplicates

Within one layer, including its included files:

- a section that is defined again is the same section: the children of both definitions
  are merged in source order (one section may be split across files);
- a scalar or array key that is defined again, or a key that is a section in one place and
  a value in another, is an error that names both locations (`file:line`).

Replacing a value on purpose is what layers are for (section 6), not duplicates.

### 3.6 Include

`@include "file"` merges the items of the file into the current section, at the point of
the directive.

- The path is relative to the including file; a path with a directory part or a VFS root
  is used as given. Files are read through `Files`.
- The merge follows the duplicate rules of 3.5.
- Including a file that is already being included (a cycle) is an error.
- Each node remembers the file it came from; a save writes a changed node back to that file
  (section 7).

### 3.7 CTL2 dialect

A file is read as CTL2 if any line, after leading blanks, starts with `$Section`,
`$EndOfSection` or `$Include` (in any letter case). The whole file is then read by the CTL2
rules, exactly as `Apus.ControlFiles` reads it today:

- `$Section name` ... `$EndOfSection` is a block section; `$Include file` is an include,
  merged by 3.6 (in CTL2 an included file was a separate namespace; that is not kept);
- `key value`: the value is the rest of the line, trimmed; there are no inline comments;
- full-line comments start with `#` or `;`;
- a quoted value loses its quotes, with no escape processing;
- `( ... )` is a list of strings and may span lines.

A file without any of these directives (flat `key value` lines) is read as CTL3. For such
old files the difference is limited to values containing ` #` (a comment now) or a
backslash escape inside double quotes.

A CTL2 file that is saved is written in CTL3 syntax (section 7).

### 3.8 JSON subset

Objects, arrays, strings with JSON escapes, numbers, `true`, `false` and `null` are read as
described above: an object is a section, keys are quoted, `:` is the separator. This makes
any JSON text that uses only these elements a valid CTL3 document. A layer read from a file
with the `.json` extension is written back as JSON (section 7).

### 3.9 Grammar summary

```
document  = items
items     = { item ( EOL | "," ) }
item      = key [ sep ] value  |  key [ sep ] block  |  "@include" string
key       = barekey | string
sep       = "=" | ":"
value     = scalar | inline | array
block     = "{" EOL items "}"            (the closing brace starts a line)
inline    = "{" items "}"                (on one line)
array     = ( "[" | "(" ) { ( value | block ) ( EOL | "," ) } ( "]" | ")" )
scalar    = string | rawstring | bare | "null"
```

## 4) Reading values

Each typed read takes a path (section 5.2) and a default. A *lenient* read returns the
default when the node is missing, is `ckNull`, or does not convert; a conversion failure
also logs a warning once per node with its `file:line`. A *strict* read (`Req...`) raises
`EConfigError` with the location instead.

| Read | Accepts | Gives the default (warning) for |
|---|---|---|
| `Int` | `42`, `-7`, `+5`, `$2A`, `0x2A`, and floats with no fractional part (`2.0`) | `2.5`, `abc`, values outside `int64` |
| `Float` | anything `Int` accepts, `0.5`, `1e-7`, `-2.5E-2` | `abc`, `1.`, `.5` |
| `Bool` | `on`/`off`, `true`/`false`, `yes`/`no`, `1`/`0`, any letter case | anything else |
| `Str` | any scalar: the text after unquoting and escapes | sections and arrays |
| `Enum` | one of the given names, any letter case; returns its index | anything else |
| `Strs` | an array of scalars, or one scalar as an array of one | sections |

Quotes do not change the type: `"42"` is `42` for `Int`. Floats are parsed exactly (the
nearest `double`).

## 5) Navigation

### 5.1 Node handles

`TCfgNode` is a small record that denotes a **position** in a document, not an object:

- it never dangles: after the node is deleted it reports `ckNone`, after it is created
  again it sees the new node;
- it sees the merged view of all layers (section 6) as it is at the moment of each call;
- a handle to a missing node is valid; its reads return defaults and its writes create the
  missing sections.

So chains need no checks: `cfg.Node('music').Node('intro').Int('volume',75)`.

### 5.2 Paths

- Segments are separated by `.`; `\` and `/` are accepted as well.
- `name[n]` selects item `n` (from 0) of an array.
- Matching is case-insensitive. The empty path is the node itself.
- A key that is not an unquoted key (3.2) is reached with `Child(name)`, which takes the
  exact name and does no path parsing.

### 5.3 Iteration

`Count`, `Item(i)` and `for child in node do` go over the children of a section (in the
order of section 6.2) or the items of an array. `Name` of a section child is its key; array
items have an empty name.

## 6) Layers

### 6.1 Building a document

```pascal
cfg:=TConfig.Create;
cfg.AddLayer('game.ctl');                               // shipped defaults
cfg.AddLayer(AppDataDir+'game.ctl',[lfWritable,lfOptional]); // user settings
cfg.Override('options.fullScreen=on');                  // from the command line
```

- `AddLayer` puts a layer on top of the existing ones. A file that fails to load raises
  `EConfigError` and leaves the document unchanged.
- `lfOptional`: a missing file is an empty layer (user settings before the first save).
- `lfWritable`: the layer receives writes. At most one layer is writable.
- `Override` adds an assignment to the topmost in-memory layer, which is never saved.
- `TConfig.Load(fname)` is a shortcut for a document with one writable layer.

### 6.2 Merged view

- A scalar, array or null comes from the topmost layer that has the key; arrays are not
  merged item by item.
- Sections are merged: the children of all layers, in the order of the lowest layer that
  has each key, with keys found only in upper layers following in the order of those
  layers.
- If layers disagree on the kind of a key (a section in one, a value in another), the
  topmost wins and a warning names both locations.

### 6.3 Writes

- `Set...` stores the value in the writable layer, creating the missing sections there;
  with no writable layer it raises `EConfigError`.
- `Delete(path)` removes the key from the writable layer and hides it from the lower ones
  (the user layer records the deletion).
- `Reset(path)` removes the key from the writable layer only, so the value of the lower
  layers shows through again.
- `Save` writes the writable layer if it was modified (section 7). Nothing else is saved.

## 7) Writing files

- A file with no changes is not written. When only some nodes changed, every unchanged line
  of a CTL3 file is written back **byte for byte**: comments, blank lines, alignment and
  the lexemes of unchanged values stay as they were.
- A changed scalar keeps its line and loses only its old value. New values are written
  canonically:
  - integers in decimal;
  - floats in the shortest form that reads back to the same `double` (15 to 17 digits),
    with `.0` added to an integral value;
  - booleans in the style of the old lexeme (`on`/`off`, `true`/`false` or `yes`/`no`,
    keeping its letter case), `on`/`off` for new keys;
  - strings in double quotes with escapes, so any string, line breaks included, can be
    saved.
- New keys go to the end of their section, as `key = value`, indented by two spaces per
  level. A new key under a section that came from an included file goes to that file; a
  new key in the root goes to the main file of the layer.
- A changed included file is written back as well.
- A layer read as CTL2 is written in CTL3 syntax as a whole; comments are kept, with `;`
  turned into `#`.
- A layer from a `.json` file is written as JSON, indented, without comments.
- The text is built completely before the file is written: a failed save leaves the file
  as it was.

## 8) Protected data

Protection is not part of the syntax. `Apus.Config` gives two hooks; the algorithms live in
separate units.

**Protected layer (envelope).** `AddLayer(fname,flags,protector)` passes the file bytes
through `protector.Unprotect` before parsing, and the text through `protector.Protect`
before saving:

```pascal
type
  IConfigProtector=interface
    // Must give different output for the same input on every call (a random nonce), so the
    // file changes as a whole on every save and shows no structure
    function Protect(const data:ByteArray):ByteArray;
    // Raises on damaged or foreign data
    function Unprotect(const data:ByteArray):ByteArray;
  end;
```

Inside the envelope the layer is ordinary CTL3 text. It is meant for data a game writes for
itself: purchase records with a server signature inside, authorization tokens. The envelope
hides where things are, the signature makes the record unforgeable.

**Shipped data** (levels and other game content) is protected by the VFS, not by
`Apus.Config`: an encrypted pack provider of `Files`, with its own key per pack, holds plain
CTL3 files. A trial and a full version are then two packs with different keys, so the trial
key opens only the trial content. `Apus.Config` reads such files like any others, since all
its file access goes through `Files`. (Such a provider does not exist yet; it is a separate
task.)

**Protected strings.** A plain config may hold a value that is already protected, e.g.
`token = "b64:..."`; the code that uses the value unprotects it. `Apus.Config` treats it as
an ordinary string.

A protected document may keep its values obfuscated in memory as well (against memory
scanners); this is an implementation option of the protected layer and does not change the
API.

## 9) Exchange

One routine describes a group of settings for both directions:

```pascal
procedure TWindowOptions.Exchange(const x:TCfgExchange);
begin
  x.Item('fullScreen',fullScreen,false);
  x.Item('windowWidth',width,1024);
  x.Item('windowHeight',height,768);
end;

options.Exchange(cfg.Reader('options')); // load
options.Exchange(cfg.Writer('options')); // save
```

- `Reader` assigns each variable from the document, or the default when the key is
  missing or does not convert (the same rules as section 4).
- `Writer` stores a variable in the writable layer only if it differs from the value the
  lower layers give (the default when they have none); otherwise it resets the key. The
  user file therefore holds only what the user changed.
- `Section(name)` gives the exchange of a subsection.

## 10) Errors, threads, lifetime

- Parse errors raise `EConfigError` with `file:line:column` and a description; the layer is
  not added.
- `EConfigError` is also raised by strict reads, by writes without a writable layer or
  through a scalar (`a.b` where `a` is a value), and by a failed save.
- A `TConfig` is thread-safe: every call takes the document's own lock. Different documents
  share nothing.
- Handles do not keep the document alive. Using a handle after its document is freed is a
  programming error.

## 11) Interface

```pascal
unit Apus.Config;
interface
uses Apus.Core;

type
  EConfigError=class(EError);

  TCfgKind=(ckNone,ckNull,ckScalar,ckSection,ckArray);
  TLayerFlag=(lfWritable,lfOptional);
  TLayerFlags=set of TLayerFlag;

  IConfigProtector=interface
    function Protect(const data:ByteArray):ByteArray;
    function Unprotect(const data:ByteArray):ByteArray;
  end;

  TConfig=class;
  TCfgEnumerator=record;

  // Position in a document; see section 5.1
  TCfgNode=record
  public
    function Exists:boolean;
    function Kind:TCfgKind;
    function Name:String8;
    function Path:String8;
    function Location:String8; // 'file:line' of the topmost definition, '' if missing
    // Navigation
    function Node(const path:String8):TCfgNode;
    function Child(const name:String8):TCfgNode;
    function Count:integer;
    function Item(index:integer):TCfgNode;
    function GetEnumerator:TCfgEnumerator;
    // Lenient reads (section 4)
    function Int(const path:String8;default:int64=0):int64;
    function Float(const path:String8;default:double=0.0):double;
    function Bool(const path:String8;default:boolean=false):boolean;
    function Str(const path:String8;const default:String8=''):String8;
    function Enum(const path:String8;const names:array of String8;default:integer=0):integer;
    function Strs(const path:String8):Strings8;
    // Reads of the node itself
    function AsInt(default:int64=0):int64;
    function AsFloat(default:double=0.0):double;
    function AsBool(default:boolean=false):boolean;
    function AsStr(const default:String8=''):String8;
    // Strict reads
    function ReqInt(const path:String8):int64;
    function ReqFloat(const path:String8):double;
    function ReqBool(const path:String8):boolean;
    function ReqStr(const path:String8):String8;
    // Writes (section 6.3)
    procedure SetInt(const path:String8;value:int64);
    procedure SetFloat(const path:String8;value:double);
    procedure SetBool(const path:String8;value:boolean);
    procedure SetStr(const path:String8;const value:String8);
    procedure SetStrs(const path:String8;const values:Strings8);
    function AddSection(const path:String8):TCfgNode;
    procedure Delete(const path:String8);
    procedure Reset(const path:String8);
  end;

  // Direction-agnostic accessor; see section 9
  TCfgExchange=record
  public
    function Reading:boolean;
    procedure Item(const name:String8;var v:integer;default:integer); overload;
    procedure Item(const name:String8;var v:int64;default:int64); overload;
    procedure Item(const name:String8;var v:single;default:single); overload;
    procedure Item(const name:String8;var v:double;default:double); overload;
    procedure Item(const name:String8;var v:boolean;default:boolean); overload;
    procedure Item(const name:String8;var v:String8;const default:String8); overload;
    function Section(const name:String8):TCfgExchange;
  end;

  TConfig=class
  public
    constructor Create;
    destructor Destroy; override;
    // A document with one writable layer
    class function Load(const fname:String8):TConfig;
    procedure AddLayer(const fname:String8;flags:TLayerFlags=[];protector:IConfigProtector=nil);
    procedure Override(const assignment:String8);
    procedure Reload; // re-read all layers; unsaved changes are lost
    function Root:TCfgNode;
    function Node(const path:String8):TCfgNode; // Root.Node(path)
    function Reader(const path:String8=''):TCfgExchange;
    function Writer(const path:String8=''):TCfgExchange;
    function Modified:boolean;
    procedure Save;
  end;
```

Only the public part is shown; the records also carry private fields.

## 12) Open points

1. **Size of level files.** If levels are large (megabytes, many numeric arrays), a compact
   binary encoding of the same tree may be needed for loading speed. It would be a second
   *serialization* of the model, selected per layer, and needs no change to the API. What
   is the typical size of a level?
2. **Duplicate scalar keys** are an error (3.5). CTL2 silently kept the last one, so old
   files with duplicates will stop loading and show the place of the duplicate.
3. **Numeric types of `Exchange`:** `integer`, `int64`, `single`, `double`, `boolean`,
   `String8`. Are enumerations (by name) and `cardinal` needed?
4. **Change notifications** (a signal on `Set`, hot reload in development) are left for
   later; they do not change this interface.

## 13) Migration from Apus.ControlFiles

| `Apus.ControlFiles` | `Apus.Config` |
|---|---|
| `UseControlFile(f)` | `cfg:=TConfig.Load(f)` or a document with layers |
| `ctlGetInt('f.ctl:\A\B',d)` | `cfg.Int('A.B',d)` |
| `ctlGetKeyType(p)` | `cfg.Node(p).Kind`; int and float are not told apart |
| `ctlGetKeys(p)` + `Split(' ')` | `for n in cfg.Node(p) do ... n.Name` |
| `ctlGetStrCnt` / `ctlGetStrInd` | `Node(p).Count` / `Item(i).AsStr`, or `Strs(p)` |
| `ctlSet*` | `Set*` |
| `ctlCreateSection` | `AddSection` |
| `SaveAllControlFiles` | `Save` of each document |
| `FreeControlFile` | `cfg.Free` |
| `$Include` (separate namespace) | merged into the including section |
| binary (encrypted) files | not supported; use a protected layer (section 8) |
| `TControlFile` | `TCfgNode` of a section |
