# Revisions

The footer of the dashboard shows `rev N · date`. This file says what each one
changed and which commit it is, so you can go back to a specific one.

`REV` is a constant near the top of the script in `index.html`. It is bumped by
hand, deliberately — the refresh workflow commits `data.js` every 15 minutes,
and a revision derived from the git SHA would change several times an hour
without anything visible having changed.

## How to go back

Look at the footer of the page, find that rev below, and check out its commit:

```bash
cd site
git fetch --tags
git checkout rev7 -- index.html     # tag name is "rev" + the number
git commit -m "Roll dashboard back to rev 7"
git push
```

Every revision from 8 onward is tagged `revN`, which is stabler than the SHA —
a tag survives the follow-up commits a revision sometimes needs.

That restores the page only. `data.js` keeps refreshing on its own, so news and
the timestamp stay current after a rollback.

To look at an old revision before committing to it, `git show <sha>:index.html > /tmp/old.html`
and open that file.

| Rev | Date | Commit | What changed |
|-----|------|--------|--------------|
| 16 | 2026-07-29 | tag `rev16` | Video days fall back to the most recent actual photograph instead of a YouTube title card |
| 15 | 2026-07-28 | tag `rev15` | Traffic button — opens Google Maps' real traffic layer, centred on the current ZIP |
| 14 | 2026-07-28 | tag `rev14` | Commute drive time with live traffic (TomTom); key and addresses stay in the browser |
| 13 | 2026-07-28 | tag `rev13` | Band as underline, age beside headline, scaling icons, NASA dim step, footer consolidated, max content width |
| 12 | 2026-07-28 | tag `rev12` | Photo-mode panels fully transparent — outline only; legibility moved to a page-wide scrim and a text halo |
| 11 | 2026-07-28 | tag `rev11` | Play-window band, feels-like promoted, capped line length, adaptive scrim, transparent photo panels, wind spelled out, simplified day detail |
| 10 | 2026-07-28 | tag `rev10` | Partly-cloudy sun given a full 8-ray corona — it had only three rays in one quadrant |
| 9 | 2026-07-28 | tag `rev9` | Partly-cloudy icon fix, browsable calendar months with holiday names on click, clickable headlines, more transparent photo-mode panels |
| 8 | 2026-07-28 | tag `rev8` | AM/PM clock, appearance toggle (auto/light/dark/NASA), animated icon for current conditions, news thumbnails, revision label; fixed news and calendar being cut off |
| 7 | 2026-07-27 | `411894d` | Animated colour weather icons on the hourly strip |
| 6 | 2026-07-27 | `9635b00` | Fixed five bugs found in review (timezone-correct night mode, responsive breakpoint, locale assumption, midnight rollover) |
| 5 | 2026-07-27 | `cfe4524` | Payday and holiday calendar card |
| 4 | 2026-07-27 | `955b5ba` | Time, forecast and news all follow the ZIP |
| 3 | 2026-07-27 | `846d40a` | Viewer-settable ZIP for the forecast |
| 2 | 2026-07-27 | `c473623` | Afternoon rain strip with a plain-English verdict |
| 1 | 2026-07-27 | earlier | First published dashboard — clock, weather, news |

Revisions 1–7 are numbered here in retrospect; only rev 8 onward actually
prints its number on the page, so anything older than 8 shows no rev label at
all. That absence is itself the signal that a page predates rev 8.

## Bumping it

When changing `index.html` in a way a viewer would notice:

1. Bump `REV` and set `REV_DATE` in `index.html`.
2. `cp index.html site/index.html` — the two copies must stay identical.
3. Add a row to the table above.
4. Commit, then `git tag revN && git push --tags`. Tag rather than SHA: the
   SHA is not knowable until after the commit that would have to contain it.
