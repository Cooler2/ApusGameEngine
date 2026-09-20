# Chapter 21. Resource System: Images and Textures

This chapter describes how images are loaded, found, shared and released. It is both a
user manual and the reference for the intended behaviour: where the current code differs
from what is written here, the text wins and the code is the thing to fix. See
"Implementation status" at the end for the exact list.

Other resource kinds (shaders, buffers, models) follow the same ownership rules but are
covered in their own chapters.

## 1) Concepts

**Texture object (`TTexture`).** A CPU-side object that describes an image the engine can
draw. It is a *handle*: it points at storage (a GPU texture, a system-memory buffer, or a
part of an atlas) and carries a *view* on that storage: `left`, `top`, `width`, `height`,
the UV rectangle `u1..v2`, and `stepU`/`stepV`.

**Storage vs. handle.** Several handles may share one storage. A handle created with
`Clone`/`ClonePart` shares the storage of its parent and differs only in the view. The
sampler state of the storage (filtering, mip-maps, wrap mode) belongs to the storage and is
therefore shared by every handle that points at it.

**Name and source are different things.**

- `name` is an arbitrary label chosen by the programmer. Names are looked up through the
  per-class registry of `TNamedObject` (`TTexture.FindByName`). Textures have their own
  registry; they never collide with widgets or other named objects. A name starting with
  `_` is *non-unique*: it is kept for logs and GL labels but not registered.
- `src` is the *source key*: where the pixels came from. It is derived from the file name
  by fixed rules (section 3) and indexed in the source registry (`TTexture.FindByFile`).

**Mutability.** Two flags exist and they mean different things:

- `tfNoWrite` — the CPU may not write pixels through `Lock`. Render targets carry it, yet
  their content changes on the GPU every frame.
- `tfImmutable` (set by `MakeImmutable`) — the *content is frozen*: no `Lock` for write, no
  `Upload`, `Clear` or `Resize`, and no GPU rendering into it. In multi-window mode an
  immutable texture is read without synchronization.

A texture loaded from a file is immutable unless `liffAllowChange` is passed. Only an
immutable texture can be shared between holders (section 4).

## 2) Getting an image

| Need | Call | Result |
|---|---|---|
| Empty texture to fill or render into | `AllocImage(w,h,fmt,aiFlags,name)` | exclusively owned, mutable |
| Image from a file, shared if already loaded | `LoadImage(tex,'name')` | shared, immutable (default) |
| Image from a file, own copy to modify | `LoadImage(tex,'name',liffAllowChange)` | exclusively owned, mutable |
| Part of a loaded image | `tex.ClonePart(rect)` | view on shared storage |
| Generated from a string / drawn via FastGFX | `CreateImageFromString`, `EditImage` | exclusively owned |

`LoadImage` is the normal entry point. It prepends `defaultImagesDir` (default `Images\`)
to relative names, so `LoadImage(tex,'cstyle/menu')` reads `Images\cstyle\menu.*`.
`LoadImageFromFile` is the lower-level routine that takes a path as is.

The file extension may be omitted. The loader probes `.dds`, `.tga`, `.png`, `.jpg` and
`.txt` and takes the newest file. This is deliberate: an artist can drop a `.dds` next to a
`.png` and the newer one wins without touching code. A reference without extension says
"this image, any of its files"; a reference with extension says "exactly this file" and
is always honoured (section 3).

**Atlases.** `LoadAtlas` registers every entry of an atlas under its file key. A later
`LoadImage` of such a file returns a view (`ClonePart`) on the atlas storage instead of
reading the disk. Atlas parts are always immutable.

**Preload queue.** `QueueFileLoad`/`StartLoadingThreads` (`Apus.Engine.ImgLoadQueue`)
decode files on worker threads. The loader consults the queue before reading the disk; the
API and semantics of `LoadImage` do not change.

**Flags.** `liffSysMem`, `liffTexture`, `liffPow2`, `liffMipMaps` select storage
properties; `liffAllowChange` asks for a mutable copy; `liffNoFail` returns `nil` instead
of raising when the file is missing. `defaultLoadImageFlags` supplies the flags when
`liffDefault` is passed.

## 3) The source key

A source key is computed by a pure string function, without touching the disk, so any
caller can compute it from a reference and get the same answer as the loader:

1. Separators are normalized by `Files.FixName` (`/` and `\` are the same).
2. The images root (`defaultImagesDir`) or the executable directory is stripped when the
   path starts with it. The key is "path relative to the images root".
3. The extension is *kept* when the reference has one. A key with extension names a
   *file*; a key without extension names an *image* (any of its files).
4. Letter case is *kept* as written by the first loader. Lookup is case-insensitive
   (`THashMap` compares keys ignoring case). Two files that differ only in case are not
   allowed; on case-sensitive file systems they would be different files with one key.

A loaded texture stores the key of the file it was actually read from in `src`, always
with extension (for a reference without extension, the file the loader chose). The
source registry indexes the texture under two keys:

| entry | example | found by |
|---|---|---|
| file | `cstyle\Buttons\MenuBTN2.png` | references with extension |
| image | `cstyle\Buttons\MenuBTN2` | references without extension |

An entry that already exists is never replaced: the file entry belongs to the first
texture loaded from that file, the image entry to the first texture loaded from any of
the image's files. When a texture is released it removes only the entries that point to
it; nobody takes them over.

References that meet in one texture (the loader picked `menubtn2.png`):

```
cstyle/buttons/menubtn2
Images\cstyle\buttons\menubtn2.png
cstyle\Buttons\MenuBTN2
```

`foo.tga` and `foo.dds` are different files and give different textures, even in one
program. `foo` then returns whichever of them was loaded first.

`TTexture.FindByFile(ref)` computes the key of `ref` and returns the registered texture or
`nil`: with extension, the texture of that file; without, the texture of the image. The
source registry is an *index*: it lists every texture that has a source, mutable or not,
and it owns nothing.

## 4) Sharing

`LoadImage` first looks the reference up in the source registry. A reference without
extension that misses is resolved to a file, and that file is looked up once more: it may
already be loaded by its own name.

- **Hit, texture is immutable, flags compatible, not thread-local** — the *same object* is
  returned and its reference counter is incremented. No clone is made: identity comparison
  (`tex1=tex2`) works, memoization by object works, and there is one handle per storage.
- **Hit, but the registered texture is mutable, or was loaded with incompatible flags, or
  belongs to another thread** — the request cannot be served by sharing. A private copy is
  loaded, a warning is logged, and the index keeps the first texture. The copy gets a
  non-unique name so the name registry stays consistent.
- **Miss** — the file is loaded, registered, and returned with reference count zero
  (one holder).

"Compatible flags" means the storage flags match: mip-maps, POT padding, system-memory
placement, filtering. The first loader decides them; asking for different flags for the
same file is almost always an error in the caller and is reported, not silently honoured.

Filtering is sampler state of the storage. `SetFilter` on a shared texture changes it for
every holder. Set filtering through load flags; per-holder sampling would require GL
sampler objects and is not provided.

Thread-local textures (`aiThreadLocal`, `tfThreadLocal`) are never shared across threads.

## 5) Mutability and publishing

- A loaded texture is immutable by default. To modify pixels after loading pass
  `liffAllowChange`; the texture is then yours alone and is not shared.
- A texture you created and filled (`AllocImage` + `Lock`/`Unlock`, or `EditImage`) is
  mutable. Once its content is final call `MakeImmutable`. After that it may be shared
  the same way file textures are.
- `MakeImmutable` fails while the texture is locked or while an upload from another
  thread is pending. Data written through `Lock`/`Unlock` on the main thread is uploaded
  lazily at first use and does not block `MakeImmutable`.
- A `tfNoWrite` texture is not necessarily immutable. Render targets are the example: the
  CPU may not write them, the GPU does. They are never shared through `LoadImage`.

## 6) Views: clones and parts

`Clone` and `ClonePart` create a new handle on the same storage. Use them when you need a
different rectangle of a shared image (atlas cells, sprite sheets, nine-patch pieces).

Rules for holders:

- The view fields of a handle you obtained from `LoadImage` are read-only for you. Other
  holders see the same object. If you need a different view, take `ClonePart`.
- `CropImage` returns a new view; it does not modify the handle it was given.
- A clone owns nothing but the view. Freeing it decrements the parent's counter.
- Clones get non-unique names (`_` prefix). Two clones of one parent must not collide in
  the name registry.

## 7) Names and the name registry

`name` is for the programmer: give a texture a name when other code needs to find it
without holding a reference (`TTexture.FindByName`, or `tex:<name>` in styles). Names are
unique per class; assigning a name that is already taken raises `Duplicate object name`.

Textures loaded from files are labelled with their key for logs and GL debugging, but the
label is non-unique (`_` prefix). File identity lives in the source registry, not in the
name registry. The two are never merged: a style reference `tex:foo` must not accidentally
find a file `foo.png`.

`FindByName` returns a *weak* reference: a pointer to the live object, nothing to free.
The creator of a named texture keeps it alive for everyone who looks it up by name, and
frees it after them. This is the ordinary raw-pointer contract, the same as for fonts and
styles.

Code that must outlive the creator takes a *strong* reference explicitly:

```pascal
skin:=TTexture(TTexture.FindByName('demo-skin')).AddRef; // nil-safe
...
FreeImage(skin); // releases that one reference
```

`AddRef` increments the reference counter and returns the same object. Every strong
reference is released with `FreeImage`; the object is destroyed when the last one goes.

One rule comes with strong references to *named* textures: a name is unique, so while any
holder keeps the old object alive, `AllocImage` with the same name raises
`Duplicate object name`. Do not recreate a named texture while strong references to the
previous one exist. File textures have no such problem: their labels are non-unique and a
new load simply joins the live object.

## 8) Images in UI and styles

Style values (`background-image`, image content keys) and `TUIImage.src` accept two
reference forms:

- `tex:<name>` — a named texture. A weak reference: the code that created the texture
  keeps it alive for as long as the UI may draw it. Looked up by name on every use (a hash
  lookup), never memoized and never freed by the UI.
- `file:<path>` — a file. Resolved through `LoadImage`, so the first element loads the
  file and every later element shares it. Extension optional, case and separators free.
  The element's style context holds one reference per file and releases it when the
  element is destroyed.

A reference that cannot be resolved yet returns `nil` and is retried on the next frame.

## 9) Lifetime and release

- Every reference obtained through `LoadImage`, `AddRef`, `Clone`/`ClonePart` or
  `CropImage` is released with exactly one `FreeImage(tex)`. It sets the variable to
  `nil`. A pointer from `FindByName` is not a reference and is not freed.
- `FreeImage` decrements the reference counter and returns while other holders remain.
  The storage is released when the last holder frees it. A clone's `FreeImage` also
  releases one reference of its parent.
- A freed texture removes itself from the source registry in its destructor. The name
  registry entry is removed with the name.
- GPU deletion must happen on the render thread. `FreeImage` from another thread posts a
  `GLIMAGES\DeleteTexture` signal and returns immediately.
- Freeing a texture twice is a bug: with sharing it steals a reference from another
  holder and leads to a use-after-free in code you did not write. Keep the
  `LoadImage`/`FreeImage` pairs local and obvious.

## 10) Design decisions

Recorded so that they are not re-litigated.

**The source registry is an index, not a cache owner.** Lookup by file is a general
function; a mutable texture must be findable too. Ownership is expressed only through the
reference counter on the object. Keeping the two apart avoids a hash that owns some
entries and not others.

**Sharing returns the same object, not a clone.** Clones exist for views. For a whole
image the view is the identity, so a clone would add a second handle, a second name, and
a parent chain for nothing. The reference counter already supports co-ownership of one
object (`FreeImage` deletes only when the counter goes below zero).

**Only immutable textures are shared.** Sharing a texture that any holder may modify is a
data race by definition. `tfImmutable` is the gate, not `tfNoWrite`, because `tfNoWrite`
still allows GPU writes (render targets).

**Loaded textures are immutable by default; mutability is requested by flag.** The flag
(`liffAllowChange`) states intent, not mechanism. Copy-on-write at `Lock` was rejected: it
hides a full copy behind an innocent call and changes the object identity mid-life.

**A key keeps the extension when the reference has one; a texture is indexed as a file
and as an image.** An explicit extension means the caller wants exactly that file; a
missing one means any file of the image will do. One extensionless key for both would
silently hand `foo.dds` to a caller that asked for `foo.tga`. Keeping only full file keys
would force extensionless references to probe the disk before every lookup. Two entries
per texture keep the key a pure string function and answer both questions exactly. Case
is kept because the hash is already case-insensitive and the original spelling is what a
case-sensitive file system needs.

**Flag conflicts: first wins, warn.** Different storage flags for the same file are a
caller error. Encoding the flags into the key would silently create duplicates instead of
reporting the mistake.

**Filtering is per storage.** It is GL texture state. Per-holder filtering needs sampler
objects, a separate feature that is not justified by current use.

**The frozen-content flag is called `tfImmutable`.** It used to be `tfReadOnly`, which
read as a synonym of `tfNoWrite` while meaning something stronger. The flag is named after
the method that sets it (`MakeImmutable`); the buffer flags `abImmutable`/`bfImmutable`
follow. "Immutable" here means frozen content, not the GL notion of immutable storage
(`glTexStorage`); a flag for that, if ever needed, will be named after the storage.

**Names stay per class and separate from sources.** Names are chosen; keys are derived.
Merging them would let a name reference hit a file by accident.

**Thread-local textures are not shared.** They exist precisely so a window thread can own
a texture without synchronization.

**Lookup by name is weak; strength is opt-in through `AddRef`.** Making every `FindByName`
a counted reference would force a `FreeImage` on every lookup site and, worse, would let a
lingering holder block the recreation of a named texture (unique names). File references
are counted because nobody else owns a file texture; named ones have a creator.

**Taking a reference is a method, not a clone.** `Clone` costs a full texture object and
breaks identity (`tex1=tex2`, memo by object). `AddRef` on the same object is what
`FreeImage` already undoes.

**Deferred: resident handles with evictable storage.** A model where the registry owns
every handle forever and only the storage behind it comes and goes (dropped at zero
holders, reloaded from the source on first use) would remove dangling pointers by
construction and give hot reload and streaming a base. Not needed by current users; it
can be layered later without changing `LoadImage`/`FreeImage`, whose meaning ("take /
release a reference") stays. Revisit when hot reload (skin switching) or streaming is on
the table.

## 11) Common pitfalls

- Loading the same file twice through `LoadImage` and expecting two independent objects.
  You get one shared immutable object; pass `liffAllowChange` for a private copy.
- Modifying `left`/`top`/`width`/`height` of a shared handle. Take `ClonePart`.
- Freeing a texture obtained through `FindByName`. It is not yours.
- Calling `SetFilter` on a shared texture to get a different look in one place.
- Keeping `foo.png` and `foo.dds` in one folder by accident. References without
  extension get the newer file (or whichever of them is already loaded); references with
  extension get exactly the file they name, so one program can end up with both.
- Giving a texture a unique name that another texture already has. Use a `_` prefix
  when the name is only a label.

## 12) Implementation status

Target behaviour is described above. Implemented on 2026-09-16 (branch `engine5`):

- `tfReadOnly`/`abReadOnly`/`bfReadOnly` renamed to `tfImmutable`/`abImmutable`/`bfImmutable`.
- `TTexture.SourceKey`: one pure key function (section 3) used by the loader and by
  `FindByFile`; `defaultImagesDir` moved to `Apus.Engine.Resources` so the key can be
  computed at that level. Keys keep an explicit extension; a texture is indexed under its
  file key and its image key (`src` = file key).
- `LoadImageFromFile`/`LoadImage` consult the source registry first: same object plus
  reference count on a compatible hit, private copy with a warning otherwise
  (`ShareableImage` in `Apus.Engine.ImageTools`).
- Loaded textures are immutable by default (`MakeImmutable` unless `liffAllowChange`);
  `tfNoWrite` is no longer set by the loader.
- File textures are labelled `_<file key>` (non-unique); the source registry never
  replaces an existing entry, and a texture removes only the entries that point to it.
- Clones and atlas parts get `_`-prefixed labels; `CropImage` returns a `ClonePart` view.
- `TTexture.AddRef` takes a strong reference (same object); the loader uses it on a
  registry hit.
- Styles resolve `file:` through plain `LoadImage`; `TContext` memoizes only `file:`
  textures and releases all of them in its destructor. `tex:` is looked up on every use
  and never owned.

Verified with a scratch runtime check (`tmp/sharecheck`, not a repo test): 38 checks
covering keys, three-form sharing, reference counts, private copies, write refusal,
views, reload after the last release, and file vs image keys (explicit extensions).
Not yet covered by a repo test.

Known limits:

- `FreeImage` from a thread other than the render thread is asynchronous: the reference
  count and the index update when the render thread processes the request.
- Flag compatibility compares clamp mode and mip-maps only; `liffSysMem` and `liffPow2`
  are not part of the check.
