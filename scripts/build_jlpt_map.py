#!/usr/bin/env python3
"""Build a JLPT word→level mapping JSON from per-level CSV files.

Usage:
    python3 scripts/build_jlpt_map.py --input-dir /path/to/csv/dir --output scripts/jlpt_levels.json

Input CSVs should be named n1.csv through n5.csv with columns:
    expression, reading, meaning, tags

Output is a JSON object mapping word forms (kanji or kana) to their JLPT level
(integer 1–5, where 5 = N5/easiest). When a word appears at multiple levels,
the easiest (highest number) is kept — learners encounter it first at that level.
"""

import argparse
import csv
import json
import os


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build JLPT level mapping JSON.")
    parser.add_argument(
        "--input-dir",
        required=True,
        help="Directory containing n1.csv through n5.csv",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output JSON path",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    mapping: dict[str, int] = {}

    # Process from hardest (N1) to easiest (N5) so that the easiest level wins
    # when a word appears at multiple levels.
    for level in range(1, 6):
        csv_path = os.path.join(args.input_dir, f"n{level}.csv")
        if not os.path.exists(csv_path):
            print(f"Warning: {csv_path} not found, skipping N{level}")
            continue

        count = 0
        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                expression = row.get("expression", "").strip()
                if expression:
                    mapping[expression] = level
                    count += 1

                # Also index by reading for kana-only lookups
                reading = row.get("reading", "").strip()
                if reading and reading != expression:
                    mapping[reading] = level

        print(f"N{level}: {count} entries")

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(mapping, f, ensure_ascii=False, indent=None, separators=(",", ":"))

    print(f"Wrote {len(mapping)} mappings to {args.output}")


if __name__ == "__main__":
    main()
