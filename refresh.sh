#!/bin/bash
# Fetches news feeds and reads todos.txt, then writes data.js for index.html.
# Run by the LaunchAgent every 15 minutes. Safe to run by hand.
set -uo pipefail

cd "$(dirname "$0")" || exit 1

if [ ! -f config.sh ]; then
  echo "config.sh missing — copy config.example.sh to config.sh first" >&2
  exit 1
fi
# shellcheck disable=SC1091
source ./config.sh

# Fetch each feed into a temp dir; a dead feed must not abort the run.
FEEDDIR=$(mktemp -d)
trap 'rm -rf "$FEEDDIR"' EXIT

i=0
for url in $FEEDS; do
  curl -sL --max-time 20 "$url" -o "$FEEDDIR/feed$i.xml" 2>/dev/null || true
  i=$((i + 1))
done

LAT="$LAT" LON="$LON" TZNAME="$TZNAME" ZIP="${ZIP:-}" PLACE="${PLACE:-}" \
  FEEDDIR="$FEEDDIR" NASA_API_KEY="${NASA_API_KEY:-}" python3 <<'PY' > data.js.tmp
import os, json, glob, datetime, email.utils, subprocess
import xml.etree.ElementTree as ET

errors = []
news = []

def safe_link(u):
    """Only http(s) survives. Feed content is untrusted: a javascript: URL
    here would become a click target on the published page."""
    if not u:
        return None
    u = u.strip()
    return u if u[:7].lower() == "http://" or u[:8].lower() == "https://" else None

def safe_image(u):
    """safe_link's rule plus one more: this URL is interpolated into a CSS
    url("...") in the browser, so a quote, space or paren in it would break out
    of the string. NASA's own image URLs never contain any of those."""
    u = safe_link(u)
    if not u:
        return None
    return None if any(c in u for c in '"\'()\\<> \t\r\n') else u

def age_of(raw):
    """RSS pubDate / Atom updated -> compact age like '2h'. None if unparseable."""
    if not raw:
        return None
    dt = None
    try:
        dt = email.utils.parsedate_to_datetime(raw)          # RSS 2.0
    except Exception:
        try:
            dt = datetime.datetime.fromisoformat(raw.replace("Z", "+00:00"))  # Atom
        except Exception:
            return None
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=datetime.timezone.utc)
    secs = (datetime.datetime.now(datetime.timezone.utc) - dt).total_seconds()
    if secs < 0:
        return "now"
    if secs < 3600:
        return "%dm" % (secs // 60)
    if secs < 86400:
        return "%dh" % (secs // 3600)
    return "%dd" % (secs // 86400)

for path in sorted(glob.glob(os.path.join(os.environ["FEEDDIR"], "feed*.xml"))):
    try:
        root = ET.parse(path).getroot()
        # RSS 2.0 first, then Atom.
        items = root.findall(".//item")
        if items:
            for it in items:
                t = it.findtext("title")
                if t:
                    news.append({"title": t.strip(),
                                 "age": age_of(it.findtext("pubDate")),
                                 "link": safe_link(it.findtext("link"))})
        else:
            ns = {"a": "http://www.w3.org/2005/Atom"}
            for it in root.findall(".//a:entry", ns):
                t = it.findtext("a:title", namespaces=ns)
                if t:
                    lk = it.find("a:link", ns)
                    news.append({"title": t.strip(),
                                 "age": age_of(it.findtext("a:updated", namespaces=ns)),
                                 "link": safe_link(lk.get("href") if lk is not None else None)})
    except Exception as e:
        errors.append("feed: %s" % type(e).__name__)

if not news and not errors:
    errors.append("no headlines fetched")

# No todos.txt is a legitimate state, not an error: the published build ships
# without one so the todos card is dropped instead of exposing a task list.
todos = None
try:
    with open("todos.txt", encoding="utf-8") as fh:
        todos = []
        for line in fh:
            line = line.strip()
            if line and not line.startswith("#"):
                todos.append(line)
except FileNotFoundError:
    pass

# ---- NASA Astronomy Picture of the Day ----
# Resolved here, once, so every device that opens the dashboard sees the same
# picture. When the browser did this itself, each device called NASA against a
# rate limit measured per IP, so devices on one network competed — and two
# devices could legitimately end up showing different pictures on the same day.
#
# The URL is referenced, never copied. APOD images are frequently the
# individual astrophotographer's own copyright rather than NASA's, so serving
# the bytes from the published site would be automated redistribution of
# third-party work with nothing checking the licence.

APOD_KEY = os.environ.get("NASA_API_KEY") or "DEMO_KEY"

def apod_url(date_str):
    u = "https://api.nasa.gov/planetary/apod?api_key=%s&thumbs=true" % APOD_KEY
    return u + ("&date=%s" % date_str if date_str else "")

def http_json(url):
    """curl rather than urllib: the feeds already go through curl, and the
    system python3 on macOS has no dependable certificate bundle.

    The status is checked before the body is parsed. A 429 rate-limit response
    is perfectly good JSON that simply has no media_type, and reading it as
    data is what turned one throttled request into four."""
    p = subprocess.run(
        ["curl", "-sL", "--max-time", "20", "-w", "\n%{http_code}", url],
        capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError("curl exit %d" % p.returncode)
    body, _, code = p.stdout.rpartition("\n")
    if code.strip() != "200":
        raise RuntimeError("http %s" % code.strip())
    return json.loads(body)

def resolve_apod():
    """Today's picture, or the most recent photograph before it.

    Roughly one day in fifteen the picture of the day is a video. NASA hands
    back a YouTube poster frame, but those are usually title cards — burnt-in
    lettering that collides with the dashboard's own type. Walking back gives a
    real astrophoto instead, credited to the day it was actually published.

    Reports `base` — the date the *undated* call came back with — separately
    from `when`, the date of the photograph finally chosen. They differ on a
    video day, and the caller needs `base` rather than `when` to know whether
    today's entry has been published at all."""
    info = http_json(apod_url(None))        # no date: NASA's own idea of today
    base = info.get("date")
    for back in range(4):
        if info.get("media_type") == "image":
            img = safe_image(info.get("url") or info.get("hdurl"))
            # `url` (NASA's web-sized copy) rather than `hdurl`: measured at
            # 0.16 MB against 7.10 MB, 45x the bytes for a 5815px image that
            # lands on a 1440px display behind a scrim.
            if img:
                return {"img":    img,
                        "title":  (info.get("title") or "").strip(),
                        "credit": (info.get("copyright") or "").strip(),
                        "when":   info.get("date") or base,
                        "base":   base}
        if back == 3 or not base:
            break
        prev = datetime.date.fromisoformat(base) - datetime.timedelta(days=back + 1)
        info = http_json(apod_url(prev.isoformat()))
    return None

def stamp_day(found):
    """Which day this answer settles — the date NASA's undated call actually
    returned, NOT today.

    Between midnight Eastern and the moment today's entry is published, the
    undated call comes back with *yesterday's*. That is a real photograph, so
    the walk-back is satisfied and returns at once. Stamping it as today would
    close the guard for the rest of the day and the picture would simply never
    change — the one thing this whole design exists to do. Leaving the older
    date in place keeps the picture on screen while letting the next hour try
    again. On a video day `base` is still today, so a walk-back result
    correctly counts as settled."""
    return found.pop("base", None) or found.get("when")

def day_is_stale(day, today):
    """`<` rather than `!=`: a stamp at or ahead of today is settled. The two
    clocks can disagree by an hour when this machine has no tzdata and
    today_eastern() falls back to standard time, and that must not turn into an
    hourly refetch."""
    return (day or "") < today

def today_eastern():
    """APOD rolls over at midnight US/Eastern, not UTC and not the viewer's
    zone."""
    try:
        from zoneinfo import ZoneInfo
        tz = ZoneInfo("US/Eastern")
    except Exception:
        # No tzdata on this machine: Eastern Standard year-round. In summer the
        # day then rolls over an hour late, which only delays the refetch.
        tz = datetime.timezone(datetime.timedelta(hours=-5))
    return datetime.datetime.now(tz).strftime("%Y-%m-%d")

def previous_apod():
    """The record from the data.js this run is about to replace. Read before
    anything is written, because the file is the only place it is kept."""
    try:
        with open("data.js", encoding="utf-8") as fh:
            raw = fh.read()
    except OSError:
        return None
    i, j = raw.find("{"), raw.rfind("}")
    if i < 0 or j <= i:
        return None
    try:
        return json.loads(raw[i:j + 1]).get("apod")
    except Exception:
        return None

apod = previous_apod()
now_ts = datetime.datetime.now(datetime.timezone.utc).timestamp()
today_et = today_eastern()

# Two conditions, not one. This script runs every 15 minutes — 96 times a day —
# so an unconditional fetch would be 96 calls against DEMO_KEY's measured limit
# of 10 an hour. But keying only on the date is not enough either: APOD rolls
# over at midnight Eastern while publication lags behind it, so every run
# through that gap would refetch, spending ~20 requests before the new picture
# even exists. The `checked` stamp caps attempts at one an hour, so a slow
# publish costs a handful of calls instead of the whole quota.
fresh_needed = (not apod) or day_is_stale(apod.get("day"), today_et)
hour_elapsed = (not apod) or (now_ts - float(apod.get("checked") or 0)) > 3600

if fresh_needed and hour_elapsed:
    try:
        found = resolve_apod()
        if found:
            found["day"] = stamp_day(found)
            found["checked"] = now_ts
            apod = found
        else:
            errors.append("apod: no photograph in the last 4 days")
            apod = dict(apod or {})
            apod["checked"] = now_ts
    except Exception as e:
        # Only messages this file constructs are surfaced; anything else is
        # reduced to its type, so a remote body can never reach the page.
        errors.append("apod: " + (str(e) if isinstance(e, RuntimeError)
                                  else type(e).__name__))
        # Stamped even on failure — otherwise every run retries a dead quota.
        apod = dict(apod or {})
        apod["checked"] = now_ts

payload = {
    "generated": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "tz":     os.environ["TZNAME"],
    "lat":    float(os.environ["LAT"]),
    "lon":    float(os.environ["LON"]),
    "zip":    os.environ.get("ZIP") or None,
    "place":  os.environ.get("PLACE") or None,
    "news":   news[:6],
    "errors": errors,
}
if todos is not None:
    payload["todos"] = todos[:8]
if apod:
    payload["apod"] = apod

# Escape '<' so a headline containing '</script>' cannot close the tag early.
body = json.dumps(payload, ensure_ascii=False).replace("<", "\\u003c")
print("window.DASH_DATA = %s;" % body)
PY

if [ ! -s data.js.tmp ]; then
  echo "refresh failed: no output written, keeping previous data.js" >&2
  rm -f data.js.tmp
  exit 1
fi

# Atomic swap — a page reload landing mid-write must never see a partial file.
mv data.js.tmp data.js
