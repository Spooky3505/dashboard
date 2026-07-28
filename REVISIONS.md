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
git log --oneline            # confirm the SHA is still there
git checkout <sha> -- index.html
git commit -m "Roll dashboard back to rev N"
git push
```

That restores the page only. `data.js` keeps refreshing on its own, so news and
the timestamp stay current after a rollback.

To look at an old revision before committing to it, `git show <sha>:index.html > /tmp/old.html`
and open that file.

| Rev | Date | Commit | What changed |
|-----|------|--------|--------------|
| 8 | 2026-07-28 | `fb59fc8` | AM/PM clock, appearance toggle (auto/light/dark/NASA), animated icon for current conditions, news thumbnails, revision label; fixed news and calendar being cut off |
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
4. Commit, then fill the SHA into the row (it is not known until after the
   commit) and amend or follow up.
