#!/usr/bin/env python3

import argparse
import gzip
import json
import os
import sqlite3
import tempfile
import xml.etree.ElementTree as ET


PRIORITY_PREFIX_RANKS = {
    "spec1": 0,
    "spec2": 1,
    "ichi1": 2,
    "ichi2": 3,
    "news1": 4,
    "news2": 5,
    "gai1": 6,
    "gai2": 7,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a bundled JMdict SQLite subset for Jouzu."
    )
    parser.add_argument("--input", required=True, help="Path to JMdict_e.gz or JMdict_e.xml")
    parser.add_argument("--output", required=True, help="Output SQLite path")
    parser.add_argument(
        "--all-entries",
        action="store_true",
        help="Bundle all JMdict entries instead of only priority-tagged entries.",
    )
    parser.add_argument(
        "--max-glosses",
        type=int,
        default=6,
        help="Maximum number of English glosses stored per entry.",
    )
    parser.add_argument(
        "--jlpt-map",
        default=None,
        help="Path to jlpt_levels.json mapping word forms to JLPT levels (1-5).",
    )
    return parser.parse_args()


def iter_entries(path: str):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rb") as handle:
        for _, elem in ET.iterparse(handle, events=("end",)):
            if elem.tag == "entry":
                yield elem
                elem.clear()


def english_glosses(entry: ET.Element, max_glosses: int) -> list[str]:
    glosses: list[str] = []

    for sense in entry.findall("sense"):
        for gloss in sense.findall("gloss"):
            lang = gloss.attrib.get("{http://www.w3.org/XML/1998/namespace}lang") or gloss.attrib.get("xml:lang")
            if lang not in (None, "eng"):
                continue

            text = (gloss.text or "").strip()
            if text and text not in glosses:
                glosses.append(text)
                if len(glosses) >= max_glosses:
                    return glosses

    return glosses


def part_of_speech(entry: ET.Element) -> str:
    all_pos: list[str] = []
    inherited_pos: list[str] = []

    for sense in entry.findall("sense"):
        sense_pos = [pos.text.strip().lower() for pos in sense.findall("pos") if pos.text]
        if sense_pos:
            inherited_pos = sense_pos
        all_pos.extend(inherited_pos)

    joined = " ".join(all_pos)
    if "particle" in joined:
        return "particle"
    if "auxiliary verb" in joined or "copula" in joined:
        return "auxiliary-verb"
    if "conjunction" in joined:
        return "conjunction"
    if "interjection" in joined:
        return "interjection"
    if "prefix" in joined:
        return "prefix"
    if "adverb" in joined:
        return "adverb"
    if "adjectival nouns" in joined or "adjectival noun" in joined or "na-adjective" in joined:
        return "na-adjective"
    if "adjective (keiyoushi)" in joined or "i-adjective" in joined or "adjective (keiyoushiku)" in joined:
        return "i-adjective"
    if "verb" in joined:
        return "verb"
    if "noun" in joined or "pronoun" in joined:
        return "noun"
    return "unknown"


def priority_rank(entry: ET.Element) -> int | None:
    tags = [
        child.text.strip()
        for child in entry.iter()
        if child.tag in ("ke_pri", "re_pri") and child.text
    ]
    if not tags:
        return None

    ranks: list[int] = []
    for tag in tags:
        if tag in PRIORITY_PREFIX_RANKS:
            ranks.append(PRIORITY_PREFIX_RANKS[tag])
            continue
        if tag.startswith("nf") and tag[2:].isdigit():
            ranks.append(100 + int(tag[2:]))

    return min(ranks) if ranks else 9999


def entry_rows(
    entry: ET.Element,
    max_glosses: int,
    include_all: bool,
    jlpt_map: dict[str, int] | None = None,
) -> tuple[list[tuple[str, str, str, str, int, int | None]], bool]:
    rank = priority_rank(entry)
    if rank is None and not include_all:
        return [], False

    definitions = english_glosses(entry, max_glosses)
    if not definitions:
        return [], rank is not None

    kanji_terms = [node.text.strip() for node in entry.findall("./k_ele/keb") if node.text]
    reading_terms = [node.text.strip() for node in entry.findall("./r_ele/reb") if node.text]
    if not reading_terms:
        return [], rank is not None

    pos = part_of_speech(entry)
    definition_text = "; ".join(definitions)
    stored_rank = rank if rank is not None else 9999
    rows: set[tuple[str, str, str, str, int, int | None]] = set()

    # Look up JLPT level from kanji or reading forms
    jlpt_level: int | None = None
    if jlpt_map:
        for term in kanji_terms + reading_terms:
            if term in jlpt_map:
                jlpt_level = jlpt_map[term]
                break

    if kanji_terms:
        for word in kanji_terms:
            for reading in reading_terms:
                rows.add((word, reading, definition_text, pos, stored_rank, jlpt_level))
    else:
        for reading in reading_terms:
            rows.add((reading, reading, definition_text, pos, stored_rank, jlpt_level))

    return sorted(rows), rank is not None


def init_database(path: str) -> sqlite3.Connection:
    connection = sqlite3.connect(path)
    connection.execute("PRAGMA journal_mode = OFF")
    connection.execute("PRAGMA synchronous = OFF")
    connection.execute("PRAGMA temp_store = MEMORY")
    connection.executescript(
        """
        CREATE TABLE entries (
            id INTEGER PRIMARY KEY,
            kanji TEXT NOT NULL,
            reading TEXT NOT NULL,
            definition TEXT NOT NULL,
            pos TEXT NOT NULL,
            priority INTEGER NOT NULL DEFAULT 9999,
            jlpt_level INTEGER
        );
        CREATE INDEX idx_kanji ON entries(kanji);
        CREATE INDEX idx_reading ON entries(reading);
        CREATE INDEX idx_priority ON entries(priority);
        CREATE INDEX idx_jlpt ON entries(jlpt_level);
        """
    )
    return connection


def main() -> None:
    args = parse_args()
    os.makedirs(os.path.dirname(args.output), exist_ok=True)

    with tempfile.NamedTemporaryFile(delete=False, suffix=".sqlite") as temp_file:
        temp_path = temp_file.name

    if os.path.exists(args.output):
        os.remove(args.output)

    jlpt_map: dict[str, int] | None = None
    if args.jlpt_map:
        with open(args.jlpt_map, "r", encoding="utf-8") as f:
            jlpt_map = json.load(f)
        print(f"Loaded JLPT map with {len(jlpt_map)} entries")

    connection = init_database(temp_path)
    cursor = connection.cursor()
    insert_sql = "INSERT INTO entries (kanji, reading, definition, pos, priority, jlpt_level) VALUES (?, ?, ?, ?, ?, ?)"

    total_entries = 0
    included_entries = 0
    priority_entries = 0
    total_rows = 0
    jlpt_tagged = 0

    try:
        for entry in iter_entries(args.input):
            total_entries += 1
            rows, had_priority = entry_rows(entry, args.max_glosses, args.all_entries, jlpt_map)
            if had_priority:
                priority_entries += 1
            if not rows:
                continue

            cursor.executemany(insert_sql, rows)
            included_entries += 1
            total_rows += len(rows)
            if any(row[5] is not None for row in rows):
                jlpt_tagged += 1

        connection.commit()
    finally:
        connection.close()

    os.replace(temp_path, args.output)
    print(
        f"Generated {args.output} with {included_entries} entries / {total_rows} rows "
        f"(JMdict total entries: {total_entries}, priority-tagged entries: {priority_entries}, "
        f"JLPT-tagged entries: {jlpt_tagged})"
    )


if __name__ == "__main__":
    main()
