# Dashboard

A glanceable ambient dashboard — clock, date, weather, an afternoon rain
forecast and news headlines. Live at <https://spooky3505.github.io/dashboard>.

## Setting your location

The ZIP box in the top right changes the forecast. Your choice is stored in your
own browser (`localStorage`) and never leaves it — the repo's `config.sh` only
supplies the default (30066, Marietta GA) for a first-time visitor.

ZIPs resolve through `api.zippopotam.us`, which returns the actual ZIP centroid.
Open-Meteo's own geocoder is the fallback, but only as a fallback: it resolves a
ZIP to the whole city, which for 30066 lands about six miles from the ZIP itself.
Both send `access-control-allow-origin: *`, so the lookup runs in the browser
with no server involved.

Known wrinkle: a few PO-Box-only ZIPs carry bad centroids in that dataset —
`96801` (Honolulu) resolves to open ocean. The fallback can't catch it because
the lookup technically succeeds.

**Everything follows the ZIP** — clock, forecast and news. The clock starts on
the default location's zone and re-homes once the weather call returns, since
Open-Meteo reports the resolved timezone alongside the forecast at no extra
request.

The ZIP is held in `sessionStorage`, not `localStorage`, and the distinction is
deliberate: opening the page always starts at the default (30066), while a ZIP
typed in survives the 5-minute auto-reload for as long as the tab stays open.
`localStorage` would make a one-off lookup stick forever.

## Local news

News is fetched **in the browser**, because only the browser knows the chosen
ZIP — a build-time fetch cannot know each viewer's location. Google News carries
genuinely local stories but sends no CORS header, so it is bridged through
`api.rss2json.com`, which does.

Two things learned the hard way, both verified in a real browser rather than by
inspecting headers:

- **GDELT is not usable.** It advertises `Access-Control-Allow-Origin: *` on a
  HEAD request and is still blocked on the actual GET. Its local relevance was
  poor anyway — a query for Marietta returned national politics.
- **Commas break the bridge.** `"Marietta, GA"` makes rss2json return a 500
  ("Cannot download this RSS feed") on the nested URL; `"Marietta GA"` is fine.
  The query strips commas for this reason.

rss2json is a free third party and does intermittently 500. When it fails, the
build-time feed from `data.js` stays on screen and the card heading drops its
place name — so the card is never blank, but the news is not local at that
moment.

## Calendar

Current month, with today ringed in the accent colour, paydays green and
company holidays yellow, plus a countdown to the next of each.

Neither set is a hardcoded list of dates. **Paydays** are derived from a 14-day
chain anchored on a known payday (9 Jan 2026); **holidays** are derived from
their rules — third Monday of January, last Monday of May, fourth Thursday of
November and so on, with 4 July sliding to the nearest weekday. Both were
checked against the source calendar for 2026 and reproduce it exactly: 26
paydays and 10 holidays, none missing, none extra. Rules rather than lists means
the card keeps working next year instead of going blank on 1 January.

Today is resolved in the dashboard's current timezone, so the highlight follows
the ZIP rather than the machine rendering the page — it matters either side of
midnight.

A payday landing on a holiday happens twice a year (27 Nov and 25 Dec in 2026).
Those days take the green fill plus a yellow dot, so neither fact is lost.

## The rain strip

Hourly rain probability from noon to 9pm, in Fahrenheit, with a one-line
verdict above it. The verdict deliberately judges **only the hours from 4pm
onward**, not the whole displayed window — it exists to answer "is outdoor play
on tonight", and judging the full window produced readings that were true but
useless (a wet morning with a clear evening reported as "rain possible all
afternoon"; a 70%-rain evening reported as "dry until 1p").

Probabilities escalate by contrast, then by the single accent colour: muted
below 25%, full-contrast bold to 50%, accent above. No second hue is
introduced — nothing on the page is clickable, so the accent is free to carry
emphasis instead of interactivity.

Once 9pm passes the strip rolls forward to tomorrow rather than showing a row
of dead hours.

Published build of the local dashboard in the parent folder. The difference is
deliberate: **this one ships no `todos.txt`**, so the page drops the todos card
and lets news take the full width. Nothing personal is published.

## How it stays current

`refresh.sh` fetches the news feeds and writes `data.js`. It runs here in GitHub
Actions (`.github/workflows/refresh.yml`) at :07/:22/:37/:52 — offset from the
top of the hour because GitHub's docs warn that scheduled runs are delayed under
load, and load peaks on the hour.

Weather is not in `data.js`. The page fetches Open-Meteo directly in each
visitor's browser, because Open-Meteo sends `access-control-allow-origin: *`.
News can't work that way — RSS feeds send no CORS header at all, so a browser
refuses to fetch them. That is the whole reason `refresh.sh` exists.

The page reloads itself every 5 minutes.

## Two caveats

- **GitHub disables scheduled workflows after 60 days of repository inactivity**
  in a public repo. It is unconfirmed whether the workflow's own bot commits
  count as activity — reportedly they do not. GitHub emails before disabling and
  re-enabling is one click.
- Pages may serve a cached `data.js` briefly after a refresh. The reload should
  revalidate via ETag, but this has not been measured against the live site.

## Keeping in sync with the local version

`index.html` and `refresh.sh` are copies of the parent folder's. If you change
either one there, copy it across:

```bash
cp ../index.html ../refresh.sh .
```

The page needs no change to work in both places — it hides the todos card
whenever `data.js` carries no todos, which is exactly what the published
`refresh.sh` produces when there's no `todos.txt` beside it.
