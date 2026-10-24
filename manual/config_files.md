# Configuration Files (CTL3)

**Status: implemented in `Base/Apus.Config.pas` (tests: `Base/tests/TestConfig.dpr`) and used by
the engine (`appConfig` of `Apus.Engine.GameApp`, the sound config, `Apus.SCGI`).** This chapter is
the reference for the intended behaviour of `Apus.Config`: where the code differs from the
text, the text wins and the code is the thing to fix. Open points are collected in section 12.

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

**Document (`TConfig`).** One file together with the files it includes, parsed into a tree.
Code reads and writes the document through *node handles*. Defaults live in the code: every
read takes a default value, so a key that is missing from the file gets the current default
of the program.

**Node.** An element of the tree. Its kind is one of:

| Kind | Meaning |
|---|---|
| `ckSection` | named children in source order; the root of the document is a section |
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
  spaces trimmed. Inside an inline container (3.4) a bare value also ends at a blank, `,`,
  `}` or `]`, so a missing comma there is an error (`{ a = 1 b = 2 }`) instead of the value
  `1 b = 2`. On a line of its own a trailing `,` is a separator, not part of the value. So
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
- **Root:** the items of the file are the children of the document root. A file whose first
  significant character is `{` is a JSON-style root object: it must be the only top-level
  item.

### 3.5 Duplicates

Within one document, including its included files:

- a section that is defined again is the same section: the children of both definitions
  are merged in source order (one section may be split across files);
- a scalar or array key that is defined again, or a key that is a section in one place and
  a value in another, is an error that names both locations (`file:line`).

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
any JSON text that uses only these elements a valid CTL3 document. A document read from a
file with the `.json` extension is written back as JSON (section 7).

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
is also reported once per node with its `file:line` (section 10). A *strict* read
(`Req...`) raises `EConfigError` with the location instead: it is the one place where the
caller asks for an exception.

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
- it sees the document as it is at the moment of each call;
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

`Count`, `Item(i)` and `for child in node do` go over the children of a section (in source
order, new keys last) or the items of an array. `Name` of a section child is its key; array
items have an empty name.

## 6) Documents

```pascal
cfg:=TConfig.Create('config.ctl');                       // the file must exist
user:=TConfig.Create(AppDataDir+'game.ctl',true);        // may be missing: empty document
w:=user.Root.Int('options.windowWidth',1024);
user.Root.SetInt('options.windowWidth',1280);
user.Save;
```

- `Create(fname)` reads the file and its includes. It never raises because of the file:
  a file that fails to load (missing, a syntax error, a duplicate key, a broken include)
  gives an empty document, so every read returns its default; the problem is reported
  (section 10) and kept in `LoadError`.
- With `optional=true` a missing file is not a problem: the document is empty, and the
  first `Save` creates the file.
- `Set...` stores a value, creating the missing sections. A write that the content does not
  allow (through a value: `a.b` where `a` is a value; a value over a section; an array item
  that does not exist) is reported and skipped. `Delete(path)` removes a key with
  everything under it.
- `Save` writes the document if it was modified (section 7) and returns `false` if it could
  not. A document that is only read (shipped data, a file in a pack) is simply never saved.
- While `LoadError` is set, `Save` does not write: the broken file stays as it is for the
  user to fix, and the changes made over the defaults are not saved.

## 7) Writing files

- A file with no changes is not written. When only some nodes changed, every unchanged line
  of a CTL3 file is written back **byte for byte**: comments, blank lines, alignment and
  the lexemes of unchanged values stay as they were.
- A changed scalar keeps its line and loses only its old value. New values are written
  canonically:
  - integers in decimal;
  - floats with 5 significant digits by default, trailing zeros dropped (`0.33333`,
    `12.5`), so a value computed or kept in a `single` does not clutter the file; precision
    is rarely needed, and `SetFloat(path,value,0)` writes the shortest form that reads back
    to the same `double` (up to 17 digits). An integral value gets `.0`;
  - booleans in the style of the old lexeme (`on`/`off`, `true`/`false` or `yes`/`no`,
    keeping its letter case), `on`/`off` for new keys;
  - strings in double quotes with escapes, so any string, line breaks included, can be
    saved.
- New keys go to the end of their section, as `key = value`, indented by two spaces per
  level. A new key under a section that came from an included file goes to that file; a
  new key in the root goes to the main file of the document.
- A changed included file is written back as well.
- A file read as CTL2 is written in CTL3 syntax as a whole; comments are kept, with `;`
  turned into `#`.
- A `.json` file is written as JSON, indented, without comments.
- The text is built completely before the file is written: a failed save leaves the file
  as it was.

## 8) Protected data

Protection is not part of the syntax. `Apus.Config` gives two hooks; the algorithms live in
separate units.

**Protected document (envelope).** `TConfig.Create(fname,optional,protector)` passes the file
bytes through `protector.Unprotect` before parsing, and the text through `protector.Protect`
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

Inside the envelope the document is ordinary CTL3 text. It is meant for data a game writes for
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
scanners); this is an implementation option of the protected document and does not change
the API.

## 9) Reloading

Servers pick up changed settings without a restart. A document remembers the size and time
of every file it read, main files and included ones, as `Files.GetFileInfo` reports them
(so files in packs are covered too).

- `Changed` tells whether any of these files differ now, or an optional file appeared or
  disappeared.
- `Reload` reads the document again. `ReloadIfChanged` does it only if `Changed`. Both
  return `true` if the document was reloaded. There is no file watcher: a server
  calls `ReloadIfChanged` on its own schedule, e.g. once a second from its timer.
- A reload is atomic. The new content is parsed first; on an error the document keeps its
  previous content, the error is reported with its location and set as `LoadError`, and
  `ReloadIfChanged` does not try the same files again until they change once more (a file
  caught in the middle of saving does not flood the log).
- A document whose load failed watches the files it tried to read, included ones too: a
  fixed file is picked up by `ReloadIfChanged`, and the defaults give way to its content.
- A document with unsaved changes is not reloaded; a warning names it. A document whose
  last load failed is reloaded anyway: its changes can't be saved over the broken file.
- Other threads see either the old or the new content, never a mix. Handles stay valid and
  see the new content (section 5.1).
- After a successful reload the document sends the signal `Config\Reloaded` through
  `Apus.EventMan`, with the document as the tag. Values that were copied into variables
  are read again in its handler.

## 10) Errors, threads, lifetime

A problem in a config is never fatal: the program goes on with the defaults, and the
problem is made noticeable.

- Every problem is logged and passed to the global `onConfigProblem` handler, from the
  thread that found it. Problems are: a failed load, reload or save (an error in the log),
  a value that does not convert and a write that the content does not allow (a warning).
  The messages carry the place, `file:line:column` for parse errors.
- The engine (`Apus.Engine.GameApp`) sets the handler to show each problem as a toast.
  Code that interprets config values itself (e.g. the parameters of a sound event)
  reports its problems through `ReportConfigProblem` and gets the same treatment.
- `EConfigError` is raised only for errors in the calling code: strict reads (section 4),
  a malformed path (`a[x`), a value written to the root, deleting the root.
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
  TConfigProblemProc=procedure(const msg:String8);

  IConfigProtector=interface
    function Protect(const data:ByteArray):ByteArray;
    function Unprotect(const data:ByteArray):ByteArray;
  end;

  TConfig=class;
  TCfgEnumerator=class; // a record can't be declared ahead; for..in frees it

  // Position in a document; see section 5.1
  TCfgNode=record
  public
    function Exists:boolean;
    function Kind:TCfgKind;
    function Name:String8;
    function Path:String8;
    function Location:String8; // 'file:line' of the definition, '' if missing
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
    // Writes (section 6)
    procedure SetInt(const path:String8;value:int64);
    procedure SetFloat(const path:String8;value:double;digits:integer=5); // 0: exact
    procedure SetBool(const path:String8;value:boolean);
    procedure SetStr(const path:String8;const value:String8);
    procedure SetStrs(const path:String8;const values:Strings8);
    function AddSection(const path:String8):TCfgNode;
    procedure Delete(const path:String8);
  end;

  TConfig=class
  public
    // never raises on the file; optional: a missing file is not a problem (section 6)
    constructor Create(const fname:String8;optional:boolean=false;protector:IConfigProtector=nil);
    destructor Destroy; override;
    function Changed:boolean;
    function Reload:boolean;
    function ReloadIfChanged:boolean;
    function Root:TCfgNode;
    function Node(const path:String8):TCfgNode; // Root.Node(path)
    function Modified:boolean;
    function LoadError:String8; // '' if the last load or reload succeeded
    function Save:boolean;
  end;

var
  onConfigProblem:TConfigProblemProc=nil; // section 10

procedure ReportConfigProblem(const msg:String8);
```

Only the public part is shown; the records also carry private fields.

## 12) Open points

Settled in review: a document is one file, defaults live in the code (no layering of
files); levels are small, so no binary encoding of the tree is planned; reloading is
required (section 9); no two-way binding of variables (an earlier `Exchange` helper was
dropped: reading and saving stay explicit calls).

1. **Duplicate scalar keys** are an error (3.5). CTL2 silently kept the last one, so old
   files with duplicates will stop loading and show the place of the duplicate.
2. **A signal on every `Set`** is left for later; it does not change this interface.

## 13) Migration from Apus.ControlFiles

| `Apus.ControlFiles` | `Apus.Config` |
|---|---|
| `UseControlFile(f)` | `cfg:=TConfig.Create(f)` (does not raise; `LoadError` tells the problem) |
| `ctlGetInt('f.ctl:\A\B',d)` | `cfg.Root.Int('A.B',d)` |
| `ctlGetKeyType(p)` | `cfg.Node(p).Kind`; int and float are not told apart |
| `ctlGetKeys(p)` + `Split(' ')` | `for n in cfg.Node(p) do ... n.Name` |
| `ctlGetStrCnt` / `ctlGetStrInd` | `Node(p).Count` / `Item(i).AsStr`, or `Strs(p)` |
| `ctlSet*` | `Set*` |
| `ctlCreateSection` | `AddSection` |
| `SaveAllControlFiles` | `Save` of each document |
| `FreeControlFile` | `cfg.Free` |
| `$Include` (separate namespace) | merged into the including section |
| binary (encrypted) files | not supported; use a protected document (section 8) |
| `TControlFile` | `TCfgNode` of a section |
