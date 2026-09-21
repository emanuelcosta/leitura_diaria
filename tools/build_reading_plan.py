"""Offline preprocessing: converts the personal Bible reading-plan spreadsheet
into assets/reading_plan.json bundled with the Flutter app.

Not shipped/run at app runtime. Run manually whenever the source spreadsheet
changes:

    python tools/build_reading_plan.py "C:\\path\\to\\plano_de_leitura_2_SBB.xlsx"

Normalizes every day's reading (which may be a partial chapter or span two
chapters) to whole-chapter units, deduplicated so each of the Bible's 1189
chapters is assigned to exactly one plan-day: the first day it is referenced.
"""

import json
import re
import sys
import unicodedata
from pathlib import Path

import openpyxl

# (name, chapter_count, testament, canonical_order 1-66, source track 1/2/3)
BOOKS = [
    ("Gênesis", 50, "AT", 1, 2), ("Êxodo", 40, "AT", 2, 2), ("Levítico", 27, "AT", 3, 2),
    ("Números", 36, "AT", 4, 2), ("Deuteronômio", 34, "AT", 5, 2), ("Josué", 24, "AT", 6, 2),
    ("Juízes", 21, "AT", 7, 2), ("Rute", 4, "AT", 8, 2), ("I Samuel", 31, "AT", 9, 2),
    ("II Samuel", 24, "AT", 10, 2), ("I Reis", 22, "AT", 11, 2), ("II Reis", 25, "AT", 12, 2),
    ("I Crônicas", 29, "AT", 13, 2), ("II Crônicas", 36, "AT", 14, 2), ("Esdras", 10, "AT", 15, 2),
    ("Neemias", 13, "AT", 16, 2), ("Ester", 10, "AT", 17, 2), ("Jó", 42, "AT", 18, 3),
    ("Salmos", 150, "AT", 19, 3), ("Provérbios", 31, "AT", 20, 3), ("Eclesiastes", 12, "AT", 21, 3),
    ("Cantares", 8, "AT", 22, 3), ("Isaías", 66, "AT", 23, 2), ("Jeremias", 52, "AT", 24, 2),
    ("Lamentações", 5, "AT", 25, 2), ("Ezequiel", 48, "AT", 26, 2), ("Daniel", 12, "AT", 27, 3),
    ("Oséias", 14, "AT", 28, 3), ("Joel", 3, "AT", 29, 3), ("Amós", 9, "AT", 30, 3),
    ("Obadias", 1, "AT", 31, 3), ("Jonas", 4, "AT", 32, 3), ("Miquéias", 7, "AT", 33, 3),
    ("Naum", 3, "AT", 34, 3), ("Habacuque", 3, "AT", 35, 3), ("Sofonias", 3, "AT", 36, 3),
    ("Ageu", 2, "AT", 37, 3), ("Zacarias", 14, "AT", 38, 3), ("Malaquias", 4, "AT", 39, 3),
    ("Mateus", 28, "NT", 40, 1), ("Marcos", 16, "NT", 41, 1), ("Lucas", 24, "NT", 42, 1),
    ("João", 21, "NT", 43, 1), ("Atos", 28, "NT", 44, 1), ("Romanos", 16, "NT", 45, 1),
    ("I Coríntios", 16, "NT", 46, 1), ("II Coríntios", 13, "NT", 47, 1), ("Gálatas", 6, "NT", 48, 1),
    ("Efésios", 6, "NT", 49, 1), ("Filipenses", 4, "NT", 50, 1), ("Colossenses", 4, "NT", 51, 1),
    ("I Tessalonicenses", 5, "NT", 52, 1), ("II Tessalonicenses", 3, "NT", 53, 1),
    ("I Timóteo", 6, "NT", 54, 1), ("II Timóteo", 4, "NT", 55, 1), ("Tito", 3, "NT", 56, 1),
    ("Filemom", 1, "NT", 57, 1), ("Hebreus", 13, "NT", 58, 1), ("Tiago", 5, "NT", 59, 1),
    ("I Pedro", 5, "NT", 60, 1), ("II Pedro", 3, "NT", 61, 1), ("I João", 5, "NT", 62, 1),
    ("II João", 1, "NT", 63, 1), ("III João", 1, "NT", 64, 1), ("Judas", 1, "NT", 65, 1),
    ("Apocalipse", 22, "NT", 66, 1),
]

TOTAL_CHAPTERS = sum(b[1] for b in BOOKS)
assert TOTAL_CHAPTERS == 1189, f"expected 1189 chapters, got {TOTAL_CHAPTERS}"


def strip_accents(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def slugify(name: str) -> str:
    s = strip_accents(name).lower()
    # roman numeral prefixes -> digits (e.g. "i coríntios" -> "1corintios")
    s = re.sub(r"^iii\s+", "3", s)
    s = re.sub(r"^ii\s+", "2", s)
    s = re.sub(r"^i\s+", "1", s)
    s = re.sub(r"[^a-z0-9]", "", s)
    return s


BOOK_KEY = {strip_accents(name).upper(): name for name, *_ in BOOKS}
BOOK_INFO = {name: {"chapters": n, "testament": t, "order": o, "track": tr} for name, n, t, o, tr in BOOKS}


def parse_ref(raw: str):
    """Returns (book_name, sorted list of chapter numbers) or (None, []) if unparseable."""
    raw = raw.strip()
    m = re.match(r"^(.*?)\s+([\d].*)$", raw)
    if not m:
        # no digits at all -> bare book name, must be a 1-chapter book
        key = strip_accents(raw).upper()
        book = BOOK_KEY.get(key)
        if book and BOOK_INFO[book]["chapters"] == 1:
            return book, [1]
        return None, []

    bookpart, rest = m.groups()
    key = strip_accents(bookpart).upper()
    book = BOOK_KEY.get(key)
    if not book:
        return None, []

    chapters = set()
    if ":" in rest:
        if "-" in rest:
            left, right = rest.split("-", 1)
        else:
            left, right = rest, None
        lch = int(left.split(":")[0])
        chapters.add(lch)
        if right and ":" in right:
            rch = int(right.split(":")[0])
            for c in range(lch, rch + 1):
                chapters.add(c)
        # else: right is a bare verse number in the same chapter -> lch already added
    elif "-" in rest:
        a, b = rest.split("-", 1)
        for c in range(int(a), int(b) + 1):
            chapters.add(c)
    else:
        chapters.add(int(rest))
    return book, sorted(chapters)


def build_plan(xlsx_path: str):
    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    ws = wb["LEITURA"]

    seen = {}  # (book, chapter) -> plan_day (1-indexed)
    days = []  # list of {"day": n, "chapters": [chapter_id, ...]}
    unparsed = []

    for plan_day, row in enumerate(range(10, 375), start=1):
        day_chapter_ids = []
        for col in (7, 9, 11):  # G, I, K
            raw = ws.cell(row=row, column=col).value
            if not raw:
                continue
            book, chapters = parse_ref(str(raw))
            if book is None or not chapters:
                unparsed.append((plan_day, raw))
                continue
            for ch in chapters:
                key = (book, ch)
                if key in seen:
                    continue  # already introduced on an earlier day
                seen[key] = plan_day
                day_chapter_ids.append(f"{slugify(book)}-{ch}")
        days.append({"day": plan_day, "chapters": day_chapter_ids})

    if unparsed:
        raise ValueError(f"Failed to parse {len(unparsed)} reading references: {unparsed[:10]}")
    if len(days) != 365:
        raise ValueError(f"Expected 365 plan days, got {len(days)}")

    expected = {(name, c) for name, n, *_ in BOOKS for c in range(1, n + 1)}
    found = set(seen.keys())
    missing = expected - found
    extra = found - expected
    if missing:
        raise ValueError(f"Missing {len(missing)} chapters: {sorted(missing)[:10]}")
    if extra:
        raise ValueError(f"Found {len(extra)} unexpected chapters: {sorted(extra)[:10]}")

    books_out = []
    for name, n, testament, order, track in BOOKS:
        books_out.append({
            "id": slugify(name),
            "name": name,
            "testament": testament,
            "track": track,
            "order": order,
            "chapters": n,
        })

    return {"books": books_out, "plan": days}


def main():
    if len(sys.argv) != 2:
        print("Usage: python build_reading_plan.py <path-to-xlsx>")
        sys.exit(1)

    xlsx_path = sys.argv[1]
    result = build_plan(xlsx_path)

    total_chapters_in_plan = sum(len(d["chapters"]) for d in result["plan"])
    print(f"Books: {len(result['books'])}")
    print(f"Plan days: {len(result['plan'])}")
    print(f"Unique chapters scheduled: {total_chapters_in_plan}")
    assert len(result["books"]) == 66
    assert total_chapters_in_plan == 1189

    out_path = Path(__file__).resolve().parent.parent / "assets" / "reading_plan.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
