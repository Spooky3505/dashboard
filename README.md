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

## Commute

Drive time with live traffic, beside the rain verdict: **"Atlanta 31 min +8"**.
The `+8` is minutes over free-flow and is the only part that colours — amber
past 5 minutes, accent past 12. At free flow there is no badge at all, because
a badge that is present every morning stops being read.

Click it to set up. **Your API key and both addresses are stored in this
browser's `localStorage` and nowhere else.** They are deliberately not in the
repo: this dashboard is published, and a home address committed to a public
page cannot be taken back. It also means the key never enters git — nothing to
leak, no referrer restriction to maintain, and no key rotation if the repo is
ever cloned. Addresses are geocoded once on save and only the coordinates are
kept.

### The Traffic button

The **Traffic** pill opens Google Maps with its traffic layer on
(`data=!5m1!1e1`), centred on whichever ZIP is set. It is a link, not an
embed, and that is not a stylistic choice.

Google **forbids framing its map**. The URL you would copy out of your browser
with traffic switched on answers `X-Frame-Options: SAMEORIGIN`, and the browser
refuses outright: *"Refused to display 'https://www.google.com/' in a frame
because it set 'X-Frame-Options' to 'sameorigin'."* Refreshing the link does
not help — it never renders once.

There is one legacy endpoint that does frame, `maps.google.com/maps?...&output=embed`,
and it renders a real map. But it carries **no traffic**, and the old `layer=t`
flag is inert: tested against a control on an interstate at 14:41 on a Tuesday,
both frames drew identical uncoloured roads.

Worth recording: `curl` reported **404** on that endpoint while a real browser
got a working map. That is the third time in this project that header
inspection disagreed with a browser, after GDELT and the favicon service.

### Why TomTom rather than Google

Google's Maps Embed API — the drop-in iframe — has **no traffic layer**. Its
five modes take `center`, `zoom`, `maptype`, `language` and `region`, and that
is all. Live traffic needs the Maps JavaScript API and its `TrafficLayer`.

That is where the economics stop working. Google withdrew the universal $200
monthly credit in March 2025; Dynamic Maps now gets 10,000 free loads a month,
then $7 per 1,000. This page reloads every five minutes — **288 loads a day,
about 8,640 a month from a single always-on screen**, or 86% of the free
allowance before it is opened anywhere else.

TomTom's free tier is 50,000 tile and 2,500 non-tile requests **per day**, with
no credit card and commercial use permitted. One route call per reload is ~288
a day against 2,500. No billing account is attached, so a leaked key costs
nothing but rate limits.

Verified in a real browser rather than by reading headers, after the GDELT
lesson: both the routing and geocoding endpoints return a normal HTTP 401 for a
bad key rather than being blocked by CORS, which is what proves they are usable
from the page.

The setup panel is an overlay, not an inline block. Opening it inline added its
height to the hero and pushed the calendar off the bottom of the screen — the
third time this layout has been broken that way.

## Calendar

Current month, with today ringed in the accent colour, paydays green and
company holidays yellow, plus a countdown to the next of each.

**Months can be browsed** with the arrows in the heading, but the default view
is always the current month — it resets on every open and reload. A "Today"
button appears only once you have navigated away, so the way back is offered
exactly when it is needed.

Browsing pauses the snap-back. The page reloads itself every five minutes, and
that reload would otherwise yank the view back to this month while someone was
still reading another one. While the calendar is off its default the reload
defers and asks again; two minutes after the last click the view restores
itself and the reload proceeds. It defers, it never blocks.

**Clicking a payday or a holiday** names it — "Independence Day, Fri 3 Jul, 25
days ago". Clicking it again closes it. The detail line's space is reserved
whether or not anything is selected: on a layout this height-constrained, a
line appearing from nowhere would push the legend off the bottom of the card.

Relative dates are phrased in both directions, since months can now be browsed
backwards and "in -5 days" is what the naive version produced.

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

## Appearance

The pill in the top right cycles four states: **Auto** (follows sunrise and
sunset at the chosen ZIP), **Light**, **Dark**, and **NASA** — the Astronomy
Picture of the Day as a full-bleed background.

The choice is kept in `localStorage`, not `sessionStorage`, and unlike the ZIP
it is meant to stick: the page reloads itself every five minutes, and a display
preference that reset on every reload would be useless.

A manual choice is never overridden. The weather call runs every 15 minutes and
used to toggle the dark class directly, which would have flipped a manually
chosen Light back to Dark within the quarter hour. Sunrise/sunset now only
*records* its verdict; applying it is skipped unless the mode is Auto.

Photo mode needs its own treatment rather than just a background image. Opaque
cards would hide the picture entirely, and body text over a bright nebula is
unreadable — so the panels go translucent with a blur, and a gradient scrim sits
between image and content, weighted to the top and bottom where the text is.
The image title and photographer are credited in the corner.

APOD is fetched **once a day** and cached by date. This is not an optimisation:
the measured DEMO_KEY rate limit is 10 requests/hour, and the page reloads 12
times an hour, so an uncached fetch would exhaust the quota inside the first
hour and leave the background broken for the rest of the day. Roughly one APOD
in fifteen is a video rather than an image; those have no usable background URL,
so the poster frame is used, falling back to the previous day's picture.

## News thumbnails

Each headline carries a small tile. It is the **publisher's favicon**, not the
article's own image — Google News strips images from its feed entirely: no
thumbnail, no enclosure, and the link is an opaque redirect, so there is no
article picture to be had at any price.

The publisher name is recovered from the " - Publisher" suffix Google appends to
every headline, and its domain is guessed from that name. The guess is right
more often than not — Patch → patch.com, FOX 5 Atlanta → fox5atlanta.com, WSB-TV
→ wsbtv.com — and wrong sometimes: the Atlanta Journal-Constitution is ajc.com,
which no rule would produce.

A miss costs nothing, because behind every tile is a coloured monogram of the
publisher's initials, and the favicon only replaces it once it has actually
decoded. Google's favicon service answers 404 for a domain it does not know —
verified against real requests, not assumed — so a wrong guess simply leaves the
monogram in place. Some domains do return a generic globe icon instead of a
404; those show the globe rather than the monogram.

The tile colour is derived from the publisher's name, so a given source keeps
the same colour between reloads instead of flickering to a new one every five
minutes.

**Headlines open the article** in a new tab, and the whole row is the target,
not just the words — on a display you walk up to, that matters more than it
would in a desktop app. Links carry `rel="noopener noreferrer"` so the opened
page gets no handle back to this one, and only `http(s)` URLs are accepted: the
feed is third-party text, and a `javascript:` URL in a headline's link would
otherwise become a click target on the page. Headlines with no link stay plain
text rather than becoming a dead link that looks clickable.

## Fitting on the screen

Two things were being cut off, and they had different causes.

**Headlines** were sliced through the middle of a line. The list is height-capped
by its card and CSS `overflow` cuts wherever it happens to land. Now the list is
measured and a headline is either shown whole or not at all.

Measuring once was not enough. The forecast strip starts hidden and appears when
the weather call returns, taking ~180px straight out of the cards *after* the
first measurement had already run — so the list had been trimmed to a height it
no longer had. A `ResizeObserver` on the list catches that and every other cause
(font swap, ZIP change, window resize) without having to enumerate them.

**The calendar's countdown and legend** were not clipped, they were pushed off
the bottom of the screen entirely — the card was simply shorter than its
content. Hiding overflow would not have brought them back; that content is the
answer the card exists to give. The height came back out of the hero, which had
grown when the hourly icons landed: tighter padding, a smaller clock, and the
current-conditions icon moved beside the temperature instead of above it.

Below roughly a 13" laptop's viewport height there is no type size at which it
all fits, so short viewports scroll instead of silently cutting content off.

## Revision number

The footer shows `rev N · date`. `REVISIONS.md` maps each revision to its commit
and what it changed, so a version you dislike can be rolled back to a specific
one. The number is bumped by hand rather than derived from the git SHA —
`data.js` is committed every 15 minutes by the refresh workflow, and a SHA-based
revision would churn several times an hour with nothing visibly different.

## Hourly icons

Each hour carries an animated SVG icon: the sun's rays turn, clouds drift, rain
and snow fall on staggered delays, fog bands slide, the storm bolt flashes.
Inline SVG rather than an icon font or sprite sheet — the page has no build step
and makes no external requests, and the parts have to animate independently.

Animation is disabled under `prefers-reduced-motion`. This thing runs all day
in the corner of a screen; a viewer who has asked for calm should get it.

The droplet shows **precipitation probability, not humidity**. The reference
layout this follows used humidity, but the whole point of the strip is deciding
whether to play outside, and the chance of rain answers that where humidity does
not. Feels-like is included because it diverges sharply from the actual
temperature in Georgia — 88° reading as 97° is the number that matters.

## Legibility over the picture

Photo mode's panels are **completely transparent** — no fill and no backdrop
filter, so a panel is optically identical to the picture around it. Only a
hairline encloses it. Any filter on the card, even a pure brightness one, is
what made the panels read as darker rectangles laid over the image.

Legibility therefore cannot come from the panels. It comes from two things
that do not single them out: a page-wide scrim, which treats every pixel
alike, and a text halo, which darkens only the few pixels around each glyph.

The same filter sits over the whole background, and it is there because the
APOD swings from a near-black starfield to a full-frame bright nebula. A fixed
dark wash tuned for the worst case buries the good ones; a multiplicative
filter scales with whatever is actually there.

It has to work this way because **the pixels cannot be read**. `apod.nasa.gov`
sends no `access-control-allow-origin`, so drawing the image to a canvas taints
it and `getImageData` throws — measuring average luminance in script is not
available. A compositing filter needs no such access.

Measured against a synthetic worst-case bright frame:

| Text | Original | Now |
|---|---|---|
| White body text | 3.12:1 | 4.19:1 |
| Muted text | 1.95:1 | 3.42:1 |
| Accent (`#2997ff`) | 1.04:1 | replaced in photo mode |

Plus the halo, which lifts contrast at the glyph edge beyond what a flat
background ratio captures. WCAG AA wants 4.5:1 for body text, so body text is
close and muted text clears the 3.0 large-text bar rather than the body one.
That is the cost of fully transparent panels, accepted deliberately: an
earlier build reached 6.1:1 and 4.8:1 with a `brightness(0.7)` filter on each
card, and that filter is precisely what made them look like rectangles. The accent was effectively invisible against
a bright frame, so photo mode drops it for the after-work label and uses a pale
blue for the selected-day line. Muted text is raised from `#cccccc` to
`#e8e8e8` in photo mode for the same reason.

One known soft spot: the hero band has no card behind it, so on an unusually
bright picture its smallest text (the wind line, ~11px) sits nearer 3.5:1 than
4.5:1. Most APODs are space and therefore dark. If a bright one lands and it
bothers you, the fix is one number — the top stop of the scrim gradient.

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
