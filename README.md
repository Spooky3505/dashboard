# Dashboard

A glanceable ambient dashboard — clock, date, weather and news headlines.
Live at <https://spooky3505.github.io/dashboard>.

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
