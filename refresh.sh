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
  FEEDDIR="$FEEDDIR" python3 <<'PY' > data.js.tmp
import os, json, glob, datetime, email.utils
import xml.etree.ElementTree as ET

errors = []
news = []

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
                    news.append({"title": t.strip(), "age": age_of(it.findtext("pubDate"))})
        else:
            ns = {"a": "http://www.w3.org/2005/Atom"}
            for it in root.findall(".//a:entry", ns):
                t = it.findtext("a:title", namespaces=ns)
                if t:
                    news.append({"title": t.strip(), "age": age_of(it.findtext("a:updated", namespaces=ns))})
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
