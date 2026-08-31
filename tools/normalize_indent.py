#!/usr/bin/env python
"""
normalize_indent.py  —  normalize Pascal indentation to 2 spaces.

Detection logic (per file):
  >20% odd-indent lines  →  1-space style  →  multiply leading spaces by 2
  <10% odd-indent lines  →  2-space style  →  skip (already correct)
  10-20%                 →  mixed/ambiguous →  skip, report separately

Usage:
  python normalize_indent.py [options]

Options:
  --dry-run        Show what would change, don't write files
  --dir DIR        Process only this directory (default: current dir)
  --file FILE      Process only this file
  --include-extra  Include extra/ directory (3rd-party, off by default)
  --include-tmp    Include tmp/  directory (worktree, off by default)
  --threshold N    Odd-% threshold for 1-space detection (default: 20)
  --flag-above N   Flag lines with indent > N as potential alignment (default: 12)
"""

import os
import sys
import argparse
from collections import Counter


SKIP_DIRS = {'bin', 'bin64', '.git', '__pycache__'}


# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------

def get_indent(line):
    """Return number of leading spaces (tabs count as 1 each)."""
    return len(line) - len(line.lstrip(' '))


def detect_style(lines):
    """
    Returns:
      'one'   — 1-space per indent level (needs 2x)
      'two'   — already 2-space (skip)
      'mixed' — ambiguous (skip, report)
    """
    indents = [get_indent(l) for l in lines
               if l.strip() and not l.startswith('\t')]
    indents = [x for x in indents if x > 0]
    if not indents:
        return 'two'  # no indented lines, nothing to do

    total = len(indents)
    odd = sum(1 for x in indents if x % 2 != 0)
    pct = 100 * odd // total

    if pct > 20:
        return 'one'
    elif pct < 10:
        return 'two'
    else:
        return 'mixed'


# ---------------------------------------------------------------------------
# Transform
# ---------------------------------------------------------------------------

import re as _re

# Block-opening keywords (each matched begin/asm/try/case adds +1 to depth)
_BLOCK_OPEN_RE = _re.compile(r'\b(begin|try|case|asm)\b', _re.I)
_END_RE        = _re.compile(r'\bend\b', _re.I)
_PROC_RE       = _re.compile(r'^(procedure|function|constructor|destructor)\b', _re.I)


def _block_delta(line):
    """Net change in begin/end depth for this line (opens minus closes)."""
    s = line.strip()
    cp = s.find('//')
    code = (s[:cp] if cp >= 0 else s).lower()
    return len(_BLOCK_OPEN_RE.findall(code)) - len(_END_RE.findall(code))


def _compute_reductions(lines):
    """
    For each line index, compute how many indent levels to subtract before
    multiplying by 2.

    Problem: in 1-space Pascal code, procedure/function bodies often have
    var/begin/end at proc_indent+1 instead of proc_indent.  After plain 2x
    multiplication this produces wrong indentation.

    Fix: for each such body, all lines from the first body line through the
    matching `end;` get reduction +1, so they use (indent - 1) * 2.
    Nested procedures accumulate reductions (each nesting level adds 1).

    Returns dict {line_index: reduction_count}.
    """
    reductions = {}
    n = len(lines)

    # Section keywords that can't appear inside a procedure body
    _SECTION_KW = frozenset((
        'implementation', 'interface', 'initialization', 'finalization',
    ))

    for i, line in enumerate(lines):
        stripped = line.strip()
        proc_indent = get_indent(line)

        if not _PROC_RE.match(stripped):
            continue

        # Skip forward to first non-blank line after the declaration
        j = i + 1
        while j < n and not lines[j].strip():
            j += 1
        if j >= n:
            continue

        nxt_s   = lines[j].strip().lower()
        nxt_ind = get_indent(lines[j])

        # Body follows when var/begin/const/type appear exactly one level deeper
        body_starters = ('var', 'begin', 'const', 'type')
        if not (nxt_ind == proc_indent + 1 and
                (nxt_s in body_starters or nxt_s.startswith('begin '))):
            continue

        # Scan forward to find the body `begin` (at exactly proc_indent+1)
        # and then its matching `end`.
        # Abort if we cross another proc/section at the same or higher level.
        found_open = False
        depth      = 0
        end_line   = -1

        for k in range(j, n):
            ks   = lines[k].strip().lower()
            kind = get_indent(lines[k])

            if not found_open:
                # Abort conditions: crossed into a sibling or parent scope
                if kind <= proc_indent and k > j:
                    if _PROC_RE.match(ks) or ks in _SECTION_KW:
                        break
                # Detect the body `begin` (must be at the right indent level)
                if kind == proc_indent + 1 and (ks == 'begin' or ks.startswith('begin ')):
                    found_open = True
                    depth = 1  # the opening begin counts as +1
            else:
                depth += _block_delta(lines[k])
                if depth <= 0:
                    end_line = k
                    break

        if not found_open or end_line < 0:
            continue  # no valid body found — skip

        # All lines from j to end_line (inclusive) need one extra reduction
        for idx in range(j, end_line + 1):
            reductions[idx] = reductions.get(idx, 0) + 1

    # Second pass: same-level style — var/begin at proc_indent (not proc_indent+1).
    # Only for nested procs (pi>0); top-level procs need no reduction.
    # Items are at proc_indent+2; apply reduction=1 only to those lines.
    for i, line in enumerate(lines):
        stripped = line.strip().lower()
        pi = get_indent(line)
        if pi == 0:
            continue
        if not _PROC_RE.match(stripped):
            continue
        j2 = i + 1
        while j2 < n and not lines[j2].strip():
            j2 += 1
        if j2 >= n:
            continue
        nxt_s2 = lines[j2].strip().lower()
        nxt_i2 = get_indent(lines[j2])
        if not (nxt_i2 == pi and nxt_s2 in ('var', 'begin', 'const', 'type')):
            continue
        # find body begin at proc_indent
        found2 = False
        depth2 = 0
        end2 = -1
        for k2 in range(j2, n):
            ks2 = lines[k2].strip().lower()
            ki2 = get_indent(lines[k2])
            if not found2:
                if ki2 < pi and k2 > j2:
                    break
                if ki2 == pi and (ks2 == 'begin' or ks2.startswith('begin ')):
                    found2 = True
                    depth2 = 1
            else:
                depth2 += _block_delta(lines[k2])
                if depth2 <= 0:
                    end2 = k2
                    break
        if not found2 or end2 < 0:
            continue
        for idx in range(j2, end2 + 1):
            if get_indent(lines[idx]) >= pi + 2:
                reductions[idx] = reductions.get(idx, 0) + 1

    return reductions


def _apply_indent(line, old_n, new_n, flag_above):
    """Return (new_line, flagged)."""
    stripped = line.lstrip(' ')
    flagged  = (old_n > flag_above)
    return ' ' * new_n + stripped, flagged


def transform_file(lines, flag_above):
    """
    Returns (new_lines, changed_count, flagged_lines).
    flagged_lines: list of (line_no, old_indent, line_content)

    Two corrections on top of plain 2x:
      1. Nested proc bodies: subtract accumulated reduction before multiplying.
      2. `uses` continuations: pin to the indent of the `uses` keyword.
    """
    reductions    = _compute_reductions(lines)
    new_lines     = []
    changed       = 0
    flagged       = []
    in_uses       = False
    new_uses_indent = 0

    for i, l in enumerate(lines):
        stripped = l.strip()
        lower_s  = stripped.lower()
        old_n    = get_indent(l)

        # --- uses-clause continuation handling ---
        if not in_uses and (lower_s.startswith('uses ') or lower_s == 'uses'):
            r      = reductions.get(i, 0)
            new_n  = max(0, old_n - r) * 2
            new_l, fl = _apply_indent(l, old_n, new_n, flag_above)
            new_uses_indent = get_indent(new_l) + 2
            in_uses = True
            if ';' in stripped:
                in_uses = False

        elif in_uses:
            if not stripped:
                new_l, fl = l, False
            else:
                new_l = ' ' * new_uses_indent + stripped
                fl    = False
            if ';' in stripped and not stripped.startswith('//'):
                in_uses = False

        # --- nested-proc correction ---
        elif i in reductions:
            r     = reductions[i]
            new_n = max(0, old_n - r) * 2
            new_l, fl = _apply_indent(l, old_n, new_n, flag_above)

        # --- plain 2x ---
        else:
            if old_n == 0:
                new_l, fl = l, False
            else:
                new_n  = old_n * 2
                new_l, fl = _apply_indent(l, old_n, new_n, flag_above)

        new_lines.append(new_l)
        if new_l != l:
            changed += 1
        if fl:
            flagged.append((i + 1, old_n, l.rstrip()))

    return new_lines, changed, flagged


# ---------------------------------------------------------------------------
# File I/O
# ---------------------------------------------------------------------------

def read_file(path):
    """Returns (bom, crlf, lines) or raises."""
    with open(path, 'rb') as f:
        raw = f.read()
    bom = raw[:3] == b'\xef\xbb\xbf'
    data = raw[3:] if bom else raw
    text = data.decode('utf-8', errors='replace')
    crlf = '\r\n' in text
    lines = text.splitlines()
    return bom, crlf, lines


def write_file(path, bom, crlf, lines):
    sep = '\r\n' if crlf else '\n'
    text = sep.join(lines)
    raw = (b'\xef\xbb\xbf' if bom else b'') + text.encode('utf-8')
    with open(path, 'wb') as f:
        f.write(raw)


# ---------------------------------------------------------------------------
# Collect files
# ---------------------------------------------------------------------------

def collect_files(root, include_extra, include_tmp):
    result = []
    for dirpath, dirs, files in os.walk(root):
        # Prune unwanted dirs in-place
        skip = set(SKIP_DIRS)
        if not include_extra:
            skip.add('extra')
        if not include_tmp:
            skip.add('tmp')
        dirs[:] = [d for d in dirs if d not in skip]

        for fname in files:
            if fname.lower().endswith('.pas'):
                result.append(os.path.join(dirpath, fname))
    return result


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def process(paths, dry_run, flag_above, verbose=True):
    stats = {'converted': 0, 'skipped_two': 0, 'skipped_mixed': 0,
             'skipped_tabs': 0, 'errors': 0}
    all_flagged = []
    mixed_files = []

    for path in sorted(paths):
        try:
            bom, crlf, lines = read_file(path)
        except Exception as e:
            print(f'  ERROR reading {path}: {e}')
            stats['errors'] += 1
            continue

        # Skip files with tabs (can't reliably handle)
        if any(l.startswith('\t') for l in lines):
            if verbose:
                print(f'  SKIP (has tabs): {path}')
            stats['skipped_tabs'] += 1
            continue

        style = detect_style(lines)

        if style == 'two':
            stats['skipped_two'] += 1
            continue

        if style == 'mixed':
            mixed_files.append(path)
            stats['skipped_mixed'] += 1
            continue

        # 1-space → transform
        new_lines, changed, flagged = transform_file(lines, flag_above)

        rel = os.path.relpath(path)
        if changed == 0:
            stats['skipped_two'] += 1
            continue

        flag_mark = f'  [{len(flagged)} suspicious]' if flagged else ''
        print(f'  {"[DRY] " if dry_run else ""}convert {rel}  ({changed} lines){flag_mark}')
        stats['converted'] += 1
        stats.setdefault('total_suspicious', 0)
        stats['total_suspicious'] += len(flagged)

        for ln, indent, content in flagged:
            all_flagged.append((rel, ln, indent, content))

        if not dry_run:
            write_file(path, bom, crlf, new_lines)

    # Summary
    print()
    print('=== Summary ===')
    print(f'  Converted:      {stats["converted"]} files')
    print(f'  Already 2-sp:   {stats["skipped_two"]} files')
    print(f'  Mixed/ambig:    {stats["skipped_mixed"]} files (manual review needed)')
    print(f'  Has tabs:       {stats["skipped_tabs"]} files (skipped)')
    print(f'  Errors:         {stats["errors"]}')
    if stats.get('total_suspicious', 0):
        print(f'  Suspicious ln:  {stats["total_suspicious"]} (enum alignment etc., review in git diff)')

    if mixed_files:
        print()
        print('=== Mixed/ambiguous files (skipped) ===')
        for p in mixed_files:
            print(f'  {os.path.relpath(p)}')

    if all_flagged:
        print()
        print(f'=== Suspicious alignment lines (indent > {flag_above} in source) ===')
        print('  Review these in git diff — they may be continuation/alignment lines.')
        for rel, ln, indent, content in all_flagged:
            print(f'  {rel}:{ln}  [{indent}sp]  {content[:70]}')


def main():
    parser = argparse.ArgumentParser(description='Normalize Pascal indentation to 2 spaces.')
    parser.add_argument('--dry-run', action='store_true',
                        help='Show changes without writing files')
    parser.add_argument('--dir', default='.',
                        help='Root directory to process (default: .)')
    parser.add_argument('--file', dest='single_file',
                        help='Process a single file only')
    parser.add_argument('--include-extra', action='store_true',
                        help='Include extra/ directory (3rd-party code)')
    parser.add_argument('--include-tmp', action='store_true',
                        help='Include tmp/ directory (git worktrees)')
    parser.add_argument('--threshold', type=int, default=20,
                        help='Odd-%% threshold for 1-space detection (default 20)')
    parser.add_argument('--flag-above', type=int, default=12,
                        help='Flag lines with source indent > N (default 12)')
    args = parser.parse_args()

    if args.single_file:
        paths = [args.single_file]
    else:
        paths = collect_files(args.dir, args.include_extra, args.include_tmp)
        print(f'Found {len(paths)} .pas files to analyze in {os.path.abspath(args.dir)}')
        print()

    process(paths, dry_run=args.dry_run, flag_above=args.flag_above)


if __name__ == '__main__':
    main()
