#!/usr/bin/env bash
#
# calsyn - Outlook synchronization via outlook-cli (https://github.com/yusufaltunbicak/outlook-cli)
#
# Run by cron every 5 minutes. For every calendar with type=outlook in settings.json:
# 1. overwrites <profile>-events.json with the calendar events (clones excluded)
# 2. for every sync job where the calendar is a destination, reconciles the
#    clone events against the <source.profile>-events.json files
#
# See README.md for the full architecture.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="${REPO_DIR}/settings.json"
WINDOW_DAYS=14
LOCK_DIR="${REPO_DIR}/.calsync.lock"

log() { echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") INFO $*"; }
err() { echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") ERROR $*" >&2; }

# Converts a "YYYY-MM-DD HH:MM" UTC string to a local "YYYY-MM-DDTHH:MM"
# string, the format expected by `outlook event-create`.
# Supports both BSD (macOS) and GNU date.
utc_to_local() {
  local utc="$1"
  if date -j >/dev/null 2>&1; then
    local epoch
    epoch=$(TZ=UTC date -j -f "%Y-%m-%d %H:%M" "${utc}" +%s)
    date -r "${epoch}" +"%Y-%m-%dT%H:%M"
  else
    date -d "${utc} UTC" +"%Y-%m-%dT%H:%M"
  fi
}

window_end_utc() {
  if date -j >/dev/null 2>&1; then
    date -u -v+"${WINDOW_DAYS}"d +"%Y-%m-%d %H:%M"
  else
    date -u -d "+${WINDOW_DAYS} days" +"%Y-%m-%d %H:%M"
  fi
}

sha1() { printf '%s' "$1" | shasum -a 1 | cut -d' ' -f1; }

# Older macOS/BSD base64 only accepts -D for decoding; probe once at startup
if echo "" | base64 -d >/dev/null 2>&1; then
  BASE64_DECODE_FLAG="-d"
else
  BASE64_DECODE_FLAG="-D"
fi
b64d() { printf '%s' "$1" | base64 "${BASE64_DECODE_FLAG}"; }

# jq helpers shared by every extraction: string normalization (null-safe,
# unix line endings, trimmed) and the plain-text description of an event
# as returned by `outlook calendar --json` (clones are created with a text
# body, original events are usually HTML so the plain preview is used)
JQ_LIB='
  def normalize: (. // "") | gsub("\r\n"; "\n") | gsub("^\\s+|\\s+$"; "");
  def plain_description: (if .body_type == "Text" then .body else .body_preview end) | normalize;
  def short_date: .[0:16] | sub("T"; " ");
'

# Reads a TSV of events on stdin, prepends the sha1 identity of each event
# (computed on the cloned fields only, see README.md -> "Hash") and writes
# `hash<TAB>original line` on stdout.
# Expected input columns: title_b64, from, to, description_b64 [, extra...]
hash_events() {
  local title_b64 from to desc_b64 extra title desc hash
  while IFS=$'\t' read -r title_b64 from to desc_b64 extra; do
    title="$(b64d "${title_b64}")"
    desc="$(b64d "${desc_b64}")"
    hash="$(sha1 "${title}|${from}|${to}|${desc}")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${hash}" "${title_b64}" "${from}" "${to}" "${desc_b64}" "${extra}"
  done
}

# ---------------------------------------------------------------------------
# Locking + git pull
# ---------------------------------------------------------------------------

if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
  log "another synchronization is running, skipping"
  exit 0
fi
trap 'rmdir "${LOCK_DIR}"' EXIT

cd "${REPO_DIR}"
git pull --rebase --quiet

if [[ ! -f "${SETTINGS}" ]]; then
  err "settings.json not found in ${REPO_DIR}"
  exit 1
fi

# Fail fast on empty clone prefixes: an empty prefix would match every event
# during the reconciliation and delete most of the calendar
INVALID=$(jq -r '.calendars[] | select((.event_clone_prefix // "") | test("^\\s*$")) | .name' "${SETTINGS}")
if [[ -n "${INVALID}" ]]; then
  err "empty event_clone_prefix for calendars: ${INVALID}"
  exit 1
fi

ALL_PREFIXES=$(jq -c '[.calendars[].event_clone_prefix]' "${SETTINGS}")
W_START="$(date -u +"%Y-%m-%d") 00:00"
W_END="$(window_end_utc)"
TMP_DIR="$(mktemp -d -t calsync)"
trap 'rmdir "${LOCK_DIR}"; rm -rf "${TMP_DIR}"' EXIT

# ---------------------------------------------------------------------------
# Sync of a single (destination, job, source) triple.
# The wanted state is the source events file reduced to the fields listed in
# job.details; existing clones matching a wanted hash are kept (multiset
# semantics), the others are deleted, unmatched wanted events are created.
# ---------------------------------------------------------------------------
sync_source() {
  local profile="$1" job_name="$2" details="$3" source_name="$4" calendar_json_file="$5"

  local source_profile source_prefix events_file
  source_profile=$(jq -r --arg n "${source_name}" '.calendars[] | select(.name == $n) | .profile' "${SETTINGS}")
  source_prefix=$(jq -r --arg n "${source_name}" '.calendars[] | select(.name == $n) | .event_clone_prefix' "${SETTINGS}")
  if [[ -z "${source_profile}" ]]; then
    err "source calendar not found in settings: job=\"${job_name}\" source=${source_name}"
    return 0
  fi

  events_file="${REPO_DIR}/${source_profile}-events.json"
  if [[ ! -f "${events_file}" ]]; then
    log "source events file not found, skipping: job=\"${job_name}\" source=${source_name}"
    return 0
  fi

  # Wanted clones: source events inside the sync window, reduced to the
  # cloned fields (title/description blanked when not listed in job.details)
  jq -r --arg wstart "${W_START}" --arg wend "${W_END}" --argjson details "${details}" "${JQ_LIB}"'
    map(select(.from >= $wstart and .from <= $wend))
    | .[]
    | [ (if ($details | index("title")) then (.title | normalize) else "" end | @base64),
        .from,
        .to,
        (if ($details | index("description")) then (.description | normalize) else "" end | @base64)
      ] | @tsv
  ' "${events_file}" | hash_events > "${TMP_DIR}/wanted.tsv"

  # Existing clones: events whose subject starts with the source prefix,
  # hashed on the same fields (prefix stripped from the title)
  jq -r --arg prefix "${source_prefix}" "${JQ_LIB}"'
    .data[]
    | select(.subject | startswith($prefix))
    | [ (.subject[($prefix | length):] | normalize | @base64),
        (.start | short_date),
        (.end | short_date),
        (plain_description | @base64),
        .id
      ] | @tsv
  ' "${calendar_json_file}" | hash_events > "${TMP_DIR}/clones.tsv"

  # Multiset diff on the hash column: clones consuming a wanted hash are kept
  awk -F'\t' 'NR==FNR {count[$1]++; next} {if (count[$1] > 0) count[$1]--; else print $6}' \
    "${TMP_DIR}/wanted.tsv" "${TMP_DIR}/clones.tsv" > "${TMP_DIR}/to_delete.txt"
  awk -F'\t' 'NR==FNR {count[$1]++; next} {if (count[$1] > 0) count[$1]--; else print $0}' \
    "${TMP_DIR}/clones.tsv" "${TMP_DIR}/wanted.tsv" > "${TMP_DIR}/to_create.tsv"

  local deleted=0 created=0

  if [[ -s "${TMP_DIR}/to_delete.txt" ]]; then
    deleted=$(wc -l < "${TMP_DIR}/to_delete.txt" | tr -d ' ')
    xargs outlook event-delete --account "${profile}" -y < "${TMP_DIR}/to_delete.txt" > /dev/null
  fi

  # Create the missing clones; event-create expects local times
  local hash title_b64 from to desc_b64 extra title full_title
  while IFS=$'\t' read -r hash title_b64 from to desc_b64 extra; do
    title="$(b64d "${title_b64}")"
    full_title="${source_prefix}"
    [[ -n "${title}" ]] && full_title="${source_prefix} ${title}"
    outlook event-create "${full_title}" "$(utc_to_local "${from}")" "$(utc_to_local "${to}")" \
      -b "$(b64d "${desc_b64}")" -y --json --account "${profile}" > /dev/null < /dev/null
    created=$((created + 1))
  done < "${TMP_DIR}/to_create.tsv"

  log "source synced: job=\"${job_name}\" source=${source_name} created=${created} deleted=${deleted}"
}

# ---------------------------------------------------------------------------
# Main loop: for every outlook calendar, export the events file and
# reconcile the jobs where the calendar is a destination
# ---------------------------------------------------------------------------
jq -r '.calendars[] | select(.type == "outlook") | .name' "${SETTINGS}" | while read -r NAME; do
  PROFILE=$(jq -r --arg n "${NAME}" '.calendars[] | select(.name == $n) | .profile' "${SETTINGS}")
  CALENDAR_JSON="${TMP_DIR}/${PROFILE}-calendar.json"

  outlook calendar --days "${WINDOW_DAYS}" --timezone UTC --json --account "${PROFILE}" < /dev/null > "${CALENDAR_JSON}"

  # Export: every event whose subject does not start with any configured prefix
  jq --argjson prefixes "${ALL_PREFIXES}" "${JQ_LIB}"'
    .data
    | map(select(.subject as $s | ($prefixes | any(. as $p | $s | startswith($p))) | not))
    | map({
        title: (.subject | normalize),
        from: (.start | short_date),
        to: (.end | short_date),
        description: plain_description
      })
  ' "${CALENDAR_JSON}" > "${REPO_DIR}/${PROFILE}-events.json"
  log "events exported: profile=${PROFILE} count=$(jq 'length' "${REPO_DIR}/${PROFILE}-events.json")"

  # Reconcile every (job, source) where this calendar is a destination
  jq -c --arg name "${NAME}" '.sync[] | select(.destinations | index($name))' "${SETTINGS}" | while read -r JOB; do
    JOB_NAME=$(jq -r '.job' <<< "${JOB}")
    DETAILS=$(jq -c '.details // []' <<< "${JOB}")
    jq -r '.sources[]' <<< "${JOB}" | while read -r SOURCE_NAME; do
      sync_source "${PROFILE}" "${JOB_NAME}" "${DETAILS}" "${SOURCE_NAME}" "${CALENDAR_JSON}"
    done
  done
done

# ---------------------------------------------------------------------------
# Commit and push the exported files, if anything changed
# ---------------------------------------------------------------------------
git add -- *-events.json
if git diff --cached --quiet; then
  log "no changes to push"
  exit 0
fi

git commit --quiet -m "calsyn: update events"
if ! git push --quiet 2>/dev/null; then
  git pull --rebase --quiet
  git push --quiet
fi
log "events pushed"
