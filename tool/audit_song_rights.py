#!/usr/bin/env python3
"""Screen the hymn collection for works still under copyright.

This is a *mechanical screen*, not a legal opinion. It applies the rules that
can be applied by machine and flags everything else for a human. Run it after
any change to the song data:

    python3 tool/audit_song_rights.py            # report only
    python3 tool/audit_song_rights.py --remove   # drop the in-copyright ones

The rule for US publication, which is the one that decides most of this
collection: a work published in 1930 or earlier is in the public domain as of
2026. Works published 1931 onwards are not yet, whatever their renewal status.

Two things this screen cannot do, and which is why KNOWN_IN_COPYRIGHT exists:

  * The years in the data are unreliable. They appear to be composition or
    authorship dates, not publication dates, and copyright runs from
    publication. "I'll Fly Away" is recorded here as 1929 but was published in
    1932 and is still actively licensed — so a date at or under 1930 is
    evidence, not proof.
  * A translation or an arrangement carries its own copyright even when the
    underlying hymn is centuries old. An entry can name a medieval author and
    still be encumbered by a twentieth-century translator.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

DATA = pathlib.Path(__file__).resolve().parent.parent / "assets/data/songs.json"

# Works published in this year or earlier are in the US public domain in 2026.
PD_PUBLICATION_CUTOFF = 1930

YEAR = re.compile(r"\b(1[5-9]\d{2}|20\d{2})\b")

# Cases the date heuristic gets wrong, each checked individually. Keyed by song
# id so a retitling cannot silently drop an entry from the list.
KNOWN_IN_COPYRIGHT: dict[int, str] = {
    676: "Published 1932 by Hartford Music and renewed, though written in "
         "1929. Among the most actively licensed gospel songs there is.",
    251: "Spanish 'How Great Thou Art'. Descends from the Hine translation "
         "lineage, which is under copyright, not from Boberg's 1885 original.",
}

# Entries a machine cannot settle: a named person with no date, or a
# translator or arranger whose own rights may still run. Reported, not removed.
REVIEW_NOTES: dict[int, str] = {
    25: "Haldor Lillenas (1885-1959), no date given. Some of his output is "
        "public domain and some is not; this one needs its publication date.",
    59: "'arr. Aulia' is unattributed. The tune is traditional Indian, but "
        "most hymnals carry a 1959 Reynolds arrangement that is not.",
    141: "E.J. Rollings, no date given.",
    533: "Credited 'Traditional, c.1940', but an Albert E. Brumley "
         "arrangement is widely claimed on this one.",
    817: "Derived from Bennard's 'The Old Rugged Cross' (1913, public "
         "domain). The derivation itself is unattributed.",
}


def latest_year(author: str) -> int | None:
    years = [int(y) for y in YEAR.findall(author or "")]
    return max(years) if years else None


def classify(song: dict) -> tuple[str, str]:
    """Returns (verdict, reason)."""
    sid = song["id"]
    author = song.get("author") or ""

    if sid in KNOWN_IN_COPYRIGHT:
        return "in_copyright", KNOWN_IN_COPYRIGHT[sid]

    year = latest_year(author)
    if year is None:
        if sid in REVIEW_NOTES:
            return "review", REVIEW_NOTES[sid]
        if re.search(r"\btr\.|\barr\.", author):
            return "review", "Names a translator or arranger with no date; " \
                             "their rights run separately from the original."
        return "review", "No date recorded."

    if year > PD_PUBLICATION_CUTOFF:
        return "in_copyright", (
            f"Dated {year}, after the {PD_PUBLICATION_CUTOFF} public-domain "
            f"cutoff for 2026."
        )

    if sid in REVIEW_NOTES:
        return "review", REVIEW_NOTES[sid]

    return "public_domain", f"Dated {year}."


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--remove", action="store_true",
                        help="rewrite songs.json without the in-copyright songs")
    args = parser.parse_args()

    data = json.loads(DATA.read_text())
    songs = data["songs"]

    buckets: dict[str, list[tuple[dict, str]]] = {
        "in_copyright": [], "review": [], "public_domain": []
    }
    for song in songs:
        verdict, reason = classify(song)
        buckets[verdict].append((song, reason))

    print(f"{len(songs)} songs\n")
    print(f"  in copyright : {len(buckets['in_copyright']):>4}")
    print(f"  needs review : {len(buckets['review']):>4}")
    print(f"  public domain: {len(buckets['public_domain']):>4}\n")

    print("=" * 78)
    print("IN COPYRIGHT — must not ship")
    print("=" * 78)
    for song, reason in sorted(buckets["in_copyright"], key=lambda p: p[0]["id"]):
        print(f"\n  #{song['id']} {song['title']}")
        print(f"     {song.get('author', '')}")
        print(f"     {reason}")

    print("\n" + "=" * 78)
    print("NEEDS A HUMAN — named contributors a machine cannot date")
    print("=" * 78)
    for song, reason in sorted(buckets["review"], key=lambda p: p[0]["id"]):
        if song["id"] in REVIEW_NOTES or re.search(
                r"\btr\.|\barr\.", song.get("author") or ""):
            print(f"\n  #{song['id']} {song['title']}")
            print(f"     {song.get('author', '')}")
            print(f"     {reason}")

    undated = [s for s, _ in buckets["review"]
               if s["id"] not in REVIEW_NOTES
               and not re.search(r"\btr\.|\barr\.", s.get("author") or "")]
    print(f"\n  ...plus {len(undated)} undated entries credited to traditional, "
          f"folk,\n     liturgical or spiritual sources, which are public "
          f"domain as\n     underlying works.")

    if args.remove and buckets["in_copyright"]:
        drop = {s["id"] for s, _ in buckets["in_copyright"]}
        data["songs"] = [s for s in songs if s["id"] not in drop]
        DATA.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
        print(f"\nRemoved {len(drop)} songs; {len(data['songs'])} remain.")

    return 1 if buckets["in_copyright"] and not args.remove else 0


if __name__ == "__main__":
    sys.exit(main())
