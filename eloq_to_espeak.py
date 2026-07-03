#!/usr/bin/env python3
"""
Convert IBM/Eloquence SPR-style dictionary entries to eSpeak-ng-style phoneme entries.

Input example:
    postfix    `[.1post.2fIks]

Default output example:
    postfix    [[p'O:stf,Iks]]

This is intentionally conservative: unmapped symbols are preserved as <X> markers
and also written to a review report instead of being silently guessed.
"""
from __future__ import annotations

import argparse
import collections
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

# Eloquence SPR-ish symbol -> eSpeak-ng phoneme mnemonic.
# These mappings are tuned for the IBM/Eloquence English dictionaries that use
# entries like `[.1post.2fIks]`.
PHONE_MAP: dict[str, str] = {
    # vowels / diphthongs
    "A": "a",      # TRAP / cat
    "a": "A:",     # LOT/PALM-ish; adjust to Q if you prefer a shorter US lot vowel
    "E": "E",      # DRESS
    "e": "eI",     # FACE
    "I": "I",      # KIT
    "i": "i:",     # FLEECE / happy vowel
    "Y": "aI",     # PRICE
    "O": "OI",     # CHOICE
    "W": "aU",     # MOUTH
    "c": "O:",     # THOUGHT / soft/horse vowel
    "o": "oU",     # GOAT
    "U": "U",      # FOOT
    "u": "u:",     # GOOSE
    "H": "V",      # STRUT
    "X": "@",      # schwa / reduced vowel
    "x": "@",      # reduced schwa-like vowel, often before liquids
    "R": "3:",     # stressed/colored er; may be changed to @r if preferred

    # consonants
    "p": "p", "b": "b", "t": "t", "d": "d", "k": "k", "g": "g",
    "f": "f", "v": "v", "s": "s", "z": "z", "h": "h",
    "m": "m", "n": "n", "l": "l", "r": "r", "w": "w", "y": "j",
    "T": "T",      # voiceless th
    "D": "D",      # voiced th
    "S": "S",      # sh
    "Z": "Z",      # zh
    "C": "tS",     # ch
    "J": "dZ",     # j
    "G": "N",      # ng
    "F": "t",      # Eloquence flap/weak t-ish phone; best eSpeak approximation
    "N": "n",      # appears in a few syllabic/reduced n contexts
    "M": "m",      # syllabic/standalone m in a few entries
    "?": "t",      # glottal/stop marker in entries such as greaten/proteinuria
}

# Multi-symbol sequences. Kept separate so users can override special cases.
MULTI_PHONE_MAP: dict[str, str] = {
    "?N": "t@n",    # greaten-like reduced /tən/; review if it appears in technical terms
}

STRESS_MAP = {
    ".1": "'",      # primary stress
    ".2": ",",      # secondary stress
    ".0": "",       # unstressed syllable marker; omitted by default
}

ENTRY_RE = re.compile(r"^(?P<word>\S+)\s+`?\[(?P<phones>[^\]]+)\]\s*(?P<rest>.*)$")

@dataclass
class ConvertedEntry:
    word: str
    source: str
    converted: str
    unknown: list[str]
    line_no: int
    original_line: str


def convert_phone_string(src: str) -> tuple[str, list[str]]:
    out: list[str] = []
    unknown: list[str] = []
    i = 0
    while i < len(src):
        # Syllable/stress marker: .0, .1, .2
        if src[i] == "." and i + 1 < len(src) and src[i:i+2] in STRESS_MAP:
            out.append(STRESS_MAP[src[i:i+2]])
            i += 2
            continue
        # skip separators/brackets just in case
        if src[i] in "[]` \t\r\n":
            i += 1
            continue
        # Some dictionary lines contain bare stress digits or a bare dot, usually from typos
        # such as o2hY instead of o.2hY. Convert the digit and ignore a bare dot.
        if src[i] in "012":
            out.append({"1": "\'", "2": ",", "0": ""}[src[i]])
            i += 1
            continue
        if src[i] == ".":
            i += 1
            continue
        # multi-character phones first
        matched = False
        for n in (3, 2):
            chunk = src[i:i+n]
            if chunk in MULTI_PHONE_MAP:
                out.append(MULTI_PHONE_MAP[chunk])
                i += n
                matched = True
                break
        if matched:
            continue
        ch = src[i]
        if ch in PHONE_MAP:
            out.append(PHONE_MAP[ch])
        else:
            out.append(f"<{ch}>")
            unknown.append(ch)
        i += 1
    # Avoid ugly repeated stress if source has odd markers; otherwise keep compact.
    return "".join(out), unknown


def parse_entries(lines: Iterable[str]) -> Iterable[ConvertedEntry]:
    for line_no, raw in enumerate(lines, 1):
        line = raw.rstrip("\n\r")
        if not line.strip() or line.lstrip().startswith(("#", ";")):
            continue
        m = ENTRY_RE.match(line)
        if not m:
            yield ConvertedEntry("", "", "", ["PARSE_ERROR"], line_no, line)
            continue
        word = m.group("word")
        src = m.group("phones")
        converted, unknown = convert_phone_string(src)
        yield ConvertedEntry(word, src, converted, unknown, line_no, line)


def main() -> int:
    ap = argparse.ArgumentParser(description="Convert Eloquence/IBM SPR dictionary pronunciations to eSpeak-ng phonemes.")
    ap.add_argument("input", type=Path, help="Input Eloquence .dic file")
    ap.add_argument("-o", "--output", type=Path, required=True, help="Converted output file")
    ap.add_argument("--review", type=Path, help="Write entries with unknown/parse issues here")
    ap.add_argument("--format", choices=["bracket", "plain"], default="bracket",
                    help="bracket writes word<TAB>[[phones]], plain writes word<TAB>phones")
    ap.add_argument("--include-comments", action="store_true", help="Include original Eloquence phones as comments")
    args = ap.parse_args()

    entries = list(parse_entries(args.input.read_text(encoding="latin-1").splitlines()))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.review:
        args.review.parent.mkdir(parents=True, exist_ok=True)

    unknown_counter: collections.Counter[str] = collections.Counter()
    parse_errors = 0
    review_lines: list[str] = []

    with args.output.open("w", encoding="utf-8", newline="\n") as out:
        out.write("// Converted from IBM/Eloquence SPR-style dictionary. Review before installing.\n")
        out.write("// Format: word<TAB>[[eSpeak phonemes]]\n")
        for e in entries:
            if "PARSE_ERROR" in e.unknown:
                parse_errors += 1
                review_lines.append(f"{e.line_no}\tPARSE_ERROR\t{e.original_line}")
                continue
            if e.unknown:
                unknown_counter.update(e.unknown)
                review_lines.append(f"{e.line_no}\t{e.word}\t{e.source}\t{e.converted}\tunknown={','.join(e.unknown)}")
            pron = f"[[{e.converted}]]" if args.format == "bracket" else e.converted
            if args.include_comments:
                out.write(f"{e.word}\t{pron}\t// Eloquence: {e.source}\n")
            else:
                out.write(f"{e.word}\t{pron}\n")

    if args.review:
        with args.review.open("w", encoding="utf-8", newline="\n") as r:
            r.write("# line\tword\teloquence\tespeak\tissue\n")
            r.write("\n".join(review_lines))
            if review_lines:
                r.write("\n")
            r.write("\n# Summary\n")
            r.write(f"# entries={len(entries)} parse_errors={parse_errors} entries_needing_review={len(review_lines)}\n")
            for sym, count in unknown_counter.most_common():
                r.write(f"# unknown_symbol {sym!r}: {count}\n")
    print(f"Converted {len(entries)} entries -> {args.output}")
    if args.review:
        print(f"Review report -> {args.review}; review entries: {len(review_lines)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
