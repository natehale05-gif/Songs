# Song rights

Every song in `assets/data/songs.json` has been screened, and 13 that were
still under copyright have been removed. **702 songs remain.**

Re-run the screen after any change to the song data:

```bash
python3 tool/audit_song_rights.py           # report; exits non-zero if any fail
python3 tool/audit_song_rights.py --remove  # drop the ones that fail
```

---

## What the screen proves, and what it does not

It applies the one rule that can be applied by machine: **a work published in
1930 or earlier is in the US public domain as of 2026.** That settles most of
this collection.

It does not, and cannot, establish the following. These are the reasons this is
a screen and not a clearance.

**The dates in the data are not publication dates.** They appear to be
composition or authorship dates, and copyright runs from publication. This is
not hypothetical — it is how the screen was caught out:

> `I'll Fly Away` is recorded here as **1929**, which would put it safely in the
> public domain. Albert E. Brumley wrote it in 1929 but it was **published in
> 1932** by Hartford Music, and renewed. It is one of the most actively
> licensed gospel songs in existence. The date in the data would have shipped
> it.

So a date at or under 1930 is *evidence*, not proof. Anything commercially
prominent deserves a second look regardless of what the data says.

**A translation or an arrangement carries its own copyright.** An entry can
credit a twelfth-century author and still be encumbered by a twentieth-century
translator. `How Great Thou Art` is the clearest case: Carl Boberg's 1885
Swedish original is long out of copyright, but the English text everyone
actually sings is Stuart K. Hine's 1949 translation, which is not.

**Jurisdiction.** The 1930 rule is US law. Most of the rest of the world uses
life of the author plus 70 years, which for a 2026 assessment means an author
who died in 1955 or earlier. The two rules mostly agree for this material, but
not always.

---

## Removed (13)

| # | Title | Credited | Why |
| --- | --- | --- | --- |
| 251 | Cuán Grande Es Él | tr. en español, trad. | Spanish *How Great Thou Art*; descends from the Hine translation lineage, not Boberg's original |
| 369 | Holy Spirit Breathe on Me | Edwin Hatch 1886 / B.B. McKinney 1937 | Hatch's text is clear; McKinney's 1937 adaptation is not |
| 533 | This World Is Not My Home | Traditional, c.1940 | Dated 1940; an Albert E. Brumley arrangement is widely claimed |
| 632 | He Lives | Alfred H. Ackley, 1933 | Published 1933 |
| 660 | Room at the Cross | Ira F. Stanphill, 1946 | Published 1946 |
| 664 | The Savior Is Waiting | Ralph Carmichael, 1958 | Published 1958 |
| 668 | What a Day That Will Be | Jim Hill, 1955 | Published 1955 |
| 676 | I'll Fly Away | Albert E. Brumley, 1929 | **Published 1932** and renewed, despite the 1929 date shown |
| 682 | Beyond the Sunset | Virgil P. Brock, 1936 | Published 1936 |
| 702 | Precious Lord Take My Hand | Thomas A. Dorsey, 1932 | Published 1932 |
| 764 | O Lord My God (How Great Thou Art) | Boberg 1885; tr. Hine 1949 | The 1949 English translation is under copyright |
| 781 | All That Thrills My Soul | Thoro Harris, 1931 | Published 1931 — one year short; enters the public domain 1 January 2027 |
| 806 | Jesus Is Coming Again | John W. Peterson, 1957 | Published 1957 |

`All That Thrills My Soul` is worth a note in the calendar: it becomes free to
carry on **1 January 2027**.

## Author entries

Removing those songs exposed some pre-existing breakage in the author data,
which is now fixed:

- **Charles Wesley** listed *"Love Divine All Loves Excelling"*, while the song
  is titled *"Love Divine, All Loves Excelling"*. A missing comma had silently
  broken the cross-link — this predated the rights work.
- **Thomas O. Chisholm** is reachable from three songs in the collection, but
  his biography listed only *Great Is Thy Faithfulness*, which is under
  copyright and not carried. His page therefore rendered **empty**. It now
  lists the three hymns of his that are actually here.
- **Stuart K. Hine** and **E.M. Bartlett** have been removed. No song reaches
  either page, and the single hymn each advertised (*How Great Thou Art*,
  *Victory in Jesus*) is under copyright and deliberately absent.

24 author biographies remain.

---

## Still worth a human look

The screen flags these rather than removing them. None is known to be
encumbered; each is simply something a machine cannot settle.

| # | Title | Credited | The question |
| --- | --- | --- | --- |
| 25 | Sing and Be Happy | Haldor Lillenas | Lillenas lived 1885–1959. Some of his output is public domain and some is not; this needs its publication date. |
| 59 | I Have Decided to Follow Jesus | Indian Folk Song, arr. Aulia | The tune is traditional, but most hymnals carry a 1959 Reynolds arrangement that is not. "arr. Aulia" is unattributed. |
| 141 | Standing Somewhere in the Shadows | E.J. Rollings | No date recorded. |
| 817 | To the Old Rugged Cross I Will Cling | Traditional (based on George Bennard) | Bennard's 1913 original is public domain; the derivation is unattributed. |

Beyond those, 13 entries name a **translator or arranger with no date**, and
about 145 are credited to traditional, folk, spiritual or liturgical sources.
The underlying works there are public domain. The residual risk is that a
specific *translation* — particularly among the Spanish, Chinese and Albanian
texts — is modern and separately owned. Establishing that needs the provenance
of each translation, which is not in the data.

One that looks alarming and is not: **We Shall Overcome** (#397). Its
registered copyright was invalidated by a US federal court in 2018 and it is
now treated as public domain.

---

## This is a screen, not legal advice

It was done by reading dates and applying a rule. It has not been reviewed by
anyone qualified to give an opinion, and the residual items above are real. If
you are going to charge for access — which raises the stakes from a takedown
request to a commercial infringement claim — this is the part to put in front
of a lawyer, along with `web/terms.html`.
