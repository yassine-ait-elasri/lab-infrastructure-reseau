#!/usr/bin/env bash
# /opt/soar/script.sh
# Suricata -> Redis fully debuggable and durable (inode+offset tracking, atomic saves)
set -euo pipefail

# -----------------------
# Config - adjust if needed
# -----------------------
SURICATA_DIR="/nsm/suricata"
STATE_DIR="/var/lib/soar"
STATE_FILE="$STATE_DIR/last_ts.txt"
PROCESSED_FILE="$STATE_DIR/processed_files.txt"
LOG_FILE="/var/log/soar/script_debug_verbose.log"
REDIS_HOST="10.0.254.6"
REDIS_PORT="6379"
REDIS_PASS="123"   # left as-is for testing per request
REDIS_LIST="so:alerts"
LOCKFILE="/var/lock/soar_script_debug_verbose.lock"

# Optional test mode:
# ./script.sh --once [max_pushes]
ONCE_MODE=0
MAX_PUSHES=0
if [ "${1:-}" = "--once" ]; then
  ONCE_MODE=1
  MAX_PUSHES=${2:-100}
fi

# -----------------------
# Ensure dirs/files
# -----------------------
mkdir -p "$STATE_DIR"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

if [ ! -f "$STATE_FILE" ]; then
  echo "1970-01-01T00:00:00.000000+0000" > "$STATE_FILE"
fi

touch "$PROCESSED_FILE"

# -----------------------
# Helpers
# -----------------------
ts_now() { date -u +"%Y-%m-%dT%H:%M:%S%z"; }
log() { printf '%s %s\n' "$(ts_now)" "$*" | tee -a "$LOG_FILE"; }

timestamp_to_epoch() {
  local ts="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$ts" <<'PY' 2>/dev/null || echo 0
import sys, datetime
s = sys.argv[1]
try:
    if s.endswith('Z'):
        s = s[:-1] + '+00:00'
    if len(s) > 5 and (s[-5] == '+' or s[-5] == '-') and s[-3] != ':':
        s = s[:-5] + s[-5:-2] + ':' + s[-2:]
    dt = datetime.datetime.fromisoformat(s)
    print(int(dt.timestamp()))
except Exception:
    try:
        s2 = s.split('.', 1)[0]
        if s2.endswith('Z'):
            s2 = s2[:-1] + '+00:00'
        dt = datetime.datetime.fromisoformat(s2)
        print(int(dt.timestamp()))
    except Exception:
        print(0)
PY
    return
  fi
  date -d "$ts" +"%s" 2>/dev/null || echo 0
}

write_state_atomic() {
  local tsval="$1"
  if [ -z "$tsval" ]; then return; fi
  local tmpf
  tmpf=$(mktemp --tmpdir "$STATE_DIR/last_ts.XXXXXX") || tmpf="$STATE_DIR/last_ts.tmp"
  printf '%s\n' "$tsval" > "$tmpf"
  mv -f "$tmpf" "$STATE_FILE"
  log "Persisted state -> $STATE_FILE : $tsval"
}

file_inode() { stat -c %i "$1" 2>/dev/null || echo 0; }
file_size()  { stat -c %s "$1" 2>/dev/null || echo 0; }

# -----------------------
# Per-file last read tracking (inode + offset)
# Format: <path><TAB><inode><TAB><offset>
# offset == -1 : fully processed (used for .gz immutable files)
# -----------------------
declare -A file_offsets   # path -> offset (number or -1)
declare -A file_inodes   # path -> inode (number)

load_processed_files() {
    [ -f "$PROCESSED_FILE" ] || { : > "$PROCESSED_FILE"; return; }
    while IFS=$'\t' read -r f inode offset; do
        [ -z "$f" ] && continue
        # Support legacy two-column files (path offset) too:
        if [ -z "$offset" ]; then
            # line probably "path offset" separated by spaces
            # try splitting by whitespace
            read -r f inode offset <<<"$f"
        fi
        file_inodes["$f"]="${inode:-0}"
        file_offsets["$f"]="${offset:-0}"
    done < "$PROCESSED_FILE"
}

save_processed_files() {
    # write atomically
    local tmpf
    tmpf=$(mktemp --tmpdir "$STATE_DIR/processed.XXXXXX") || tmpf="$PROCESSED_FILE.tmp"
    # write sorted for reproducibility
    for f in $(printf '%s\n' "${!file_offsets[@]}" | sort); do
        inode=${file_inodes["$f"]:-0}
        offset=${file_offsets["$f"]:-0}
        printf '%s\t%s\t%s\n' "$f" "$inode" "$offset" >> "$tmpf"
    done
    mv -f "$tmpf" "$PROCESSED_FILE"
    log "Persisted processed files -> $PROCESSED_FILE"
}

# -----------------------
# Locking (prevent concurrent runs)
# -----------------------
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  log "Another instance is running — exiting."
  exit 0
fi
log "Acquired lock $LOCKFILE (fd 9)."

# Ensure we release lock and persist on exit/kill
CLEANED=0
on_exit() {
  if [ "$CLEANED" -eq 1 ]; then return; fi
  CLEANED=1
  if [ -n "${NEW_LAST_TS-}" ] && [ "${NEW_LAST_TS:-}" != "${LAST_TS:-}" ]; then
    write_state_atomic "$NEW_LAST_TS"
  fi
  save_processed_files
  log "Releasing lock and exiting."
  flock -u 9 || true
  exec 9>&- || true
}
trap 'log "Trap SIGINT/TERM/EXIT received."; on_exit' INT TERM EXIT

# -----------------------
# Main
# -----------------------
log "=== START (durable debug + per-file tracking) ==="
log "Script: $0"
log "SURICATA_DIR=$SURICATA_DIR"
log "STATE_FILE=$STATE_FILE"
log "PROCESSED_FILE=$PROCESSED_FILE"
log "LOG_FILE=$LOG_FILE"
log "LOCKFILE=$LOCKFILE"
log "REDIS_HOST=$REDIS_HOST REDIS_PORT=$REDIS_PORT REDIS_LIST=$REDIS_LIST"
if [ "$ONCE_MODE" -eq 1 ]; then
  log "RUNNING IN TEST MODE (--once) max_pushes=$MAX_PUSHES"
fi

LAST_TS=$(cat "$STATE_FILE")
log "Loaded last state timestamp: $LAST_TS"
NEW_LAST_TS="$LAST_TS"

pushed=0
lines_processed=0

mapfile -t eve_files < <(ls -1tr "$SURICATA_DIR"/eve-*.json* 2>/dev/null || true)
if [ "${#eve_files[@]}" -eq 0 ]; then
  log "No eve files found in $SURICATA_DIR - exiting."
  on_exit
  exit 0
fi

last_epoch=$(timestamp_to_epoch "$LAST_TS")
NEW_LAST_TS_EPOCH="$last_epoch"

log "Found ${#eve_files[@]} eve file(s) to process."

# Load per-file offsets (inode-aware)
load_processed_files

for file in "${eve_files[@]}"; do
  [ -s "$file" ] || { log "Skipping empty file: $file"; continue; }
  log "Processing file: $file"

  saved_offset=${file_offsets["$file"]:-0}
  saved_inode=${file_inodes["$file"]:-0}
  log "Saved metadata: inode=$saved_inode offset=$saved_offset"

  # TEST MODE skip flag
  if [ "$saved_offset" = "-1" ]; then
      log "Offset=-1 -> skipping file $file (marked done)"
      continue
  fi

  cur_inode=$(file_inode "$file")
  cur_size=$(file_size "$file")

  # Detect rotation/recreate (inode changed)
  if [ "$saved_inode" != "0" ] && [ "$cur_inode" != "$saved_inode" ]; then
    log "Inode changed for $file (saved=$saved_inode cur=$cur_inode) -> reset offset to 0"
    saved_offset=0
  fi

  # Detect truncation
  if [ "$cur_size" -lt "$saved_offset" ]; then
    log "File truncated for $file (size $cur_size < saved_offset $saved_offset) -> reset offset to 0"
    saved_offset=0
  fi

  # If nothing new for non-gz files, skip quickly but ensure metadata present
  if [[ "$file" != *.gz ]]; then
    if [ "$saved_offset" -ge "$cur_size" ]; then
      log "No new bytes in $file (saved_offset=$saved_offset size=$cur_size) -> skipping"
      # update inode/offset in case absent
      file_inodes["$file"]="$cur_inode"
      file_offsets["$file"]="$cur_size"
      save_processed_files
      continue
    fi
  fi

  # Build pipeline: for gz -> gzip -dc; for non-gz -> tail from saved_offset+1
  if [[ "$file" == *.gz ]]; then
      # process gzip once and then mark -1 (immutable)
      log "Processing gz file (full read): $file"
      proc_cmd=(gzip -dc -- "$file")
      post_mark_done=1
  else
      start_byte=$((saved_offset + 1))
      log "Processing file bytes from $start_byte -> $file"
      proc_cmd=(tail -c +"$start_byte" -- "$file")
      post_mark_done=0
  fi

  # Process alerts through jq once per file
  # Each line from jq is a JSON object (alert or other); we use select in jq to only emit alerts
  lines_this_file=0
  # shellcheck disable=SC2086
  while IFS= read -r alert; do
    lines_processed=$((lines_processed+1))
    lines_this_file=$((lines_this_file+1))
    local_len=$(printf '%s' "$alert" | wc -c)
    short_line=$(printf '%s' "$alert" | cut -c1-300)
    log "Read alert (len=${local_len}) [preview: ${short_line}]"

    tcur=$(printf '%s' "$alert" | jq -r '.timestamp' 2>/dev/null || true)
    if [ -z "$tcur" ] || [ "$tcur" = "null" ]; then
      log "No timestamp in parsed alert - skipping"
      continue
    fi
    log "Parsed alert timestamp: $tcur"

    tcur_epoch=$(timestamp_to_epoch "$tcur")
    if ! [[ "$tcur_epoch" =~ ^[0-9]+$ ]]; then
      log "Failed to parse timestamp -> epoch ($tcur_epoch) - skipping"
      continue
    fi

    if (( tcur_epoch <= last_epoch )); then
      log "Alert older than last processed timestamp ($LAST_TS) — skipping"
      continue
    fi

    alert_with_epoch=$(printf '%s' "$alert" | jq --argjson e "$tcur_epoch" '. + {epoch_ts: $e}')

    log "Pushing alert to Redis (epoch=${tcur_epoch})"
    rc=0
    if [ -n "${REDIS_PASS:-}" ]; then
      echo "$alert_with_epoch" | redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASS" -x RPUSH "$REDIS_LIST" >/dev/null 2>&1 || rc=$?
    else
      echo "$alert_with_epoch" | redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -x RPUSH "$REDIS_LIST" >/dev/null 2>&1 || rc=$?
    fi

    if [ "$rc" -eq 0 ]; then
      pushed=$((pushed+1))
      log "Alert pushed successfully (pushed=$pushed)"
      if (( tcur_epoch > NEW_LAST_TS_EPOCH )); then
        NEW_LAST_TS_EPOCH=$tcur_epoch
        NEW_LAST_TS="$tcur"
        write_state_atomic "$NEW_LAST_TS"
        last_epoch=$NEW_LAST_TS_EPOCH
      fi
    else
      log "ERROR pushing alert to Redis (rc=$rc). Will continue processing."
      unset rc
    fi

    # test mode limit
    if [ "$ONCE_MODE" -eq 1 ] && [ "$pushed" -ge "$MAX_PUSHES" ]; then
      log "Reached test push limit ($MAX_PUSHES). Exiting loop."
      # update per-file offset before exit
      cur_size=$(file_size "$file")
      file_inodes["$file"]="$cur_inode"
      # for gz we will mark as processed below; for non-gz update to cur_size
      if [ "$post_mark_done" -eq 0 ]; then
        file_offsets["$file"]="$cur_size"
      fi
      save_processed_files
      on_exit
      exit 0
    fi

  done < <("${proc_cmd[@]}" | jq -c 'select(.event_type=="alert")' 2>/dev/null || true)

  log "Finished processing $file : processed ${lines_this_file} alert lines."

  # update per-file metadata after file processed
  cur_inode=$(file_inode "$file")
  cur_size=$(file_size "$file")
  file_inodes["$file"]="$cur_inode"
  if [ "$post_mark_done" -eq 1 ]; then
    # treat gz as immutable: mark -1 (done)
    file_offsets["$file"]="-1"
    log "Marked gz file done: $file"
  else
    # set offset to current file size (we read up to this)
    file_offsets["$file"]="$cur_size"
    log "Updated offset for $file -> $cur_size"
  fi

  # persist per-file progress (atomic)
  save_processed_files

done

log "Completed file loop. lines_processed=$lines_processed pushed=$pushed"

# final persist
if [ -n "${NEW_LAST_TS-}" ] && [ "$NEW_LAST_TS" != "$LAST_TS" ]; then
  write_state_atomic "$NEW_LAST_TS"
fi

save_processed_files

log "Script finished. lines_processed=$lines_processed pushed=$pushed"
log "=== END ==="

on_exit
exit 0
