# memguard — make cgroup OOM kills obvious in the CI log.
#
# The job container runs in its own memory cgroup (limit set by the ARC
# job-pod extension). When the kernel OOM-kills bitbake, the host dmesg
# holds the answer but is not visible from here; the cgroup's own
# counters are. So:
#   - memguard_start: background watcher sampling memory.current/peak
#     into memtrace.log (workspace-persistent)
#   - memguard_die:   on build failure, print limit/peak/events + the
#     watcher trace tail; oom_kill > 0 is conclusive
#
# Usage in a step:
#   source ci/memguard.sh
#   memguard_start
#   bitbake ... || memguard_die "BuildName"
#   memguard_stop

MEMGUARD_LOG="${GITHUB_WORKSPACE}/memtrace.log"

memguard_start() {
  (
    while :; do
      printf '%s current=%s peak=%s\n' \
        "$(date -u +%H:%M:%S)" \
        "$(cat /sys/fs/cgroup/memory.current 2>/dev/null)" \
        "$(cat /sys/fs/cgroup/memory.peak 2>/dev/null)"
      sleep 5
    done >>"$MEMGUARD_LOG" 2>/dev/null
  ) &
  MEMGUARD_PID=$!
}

memguard_die() {
  kill "${MEMGUARD_PID:-}" 2>/dev/null
  local label="${1:-build}"
  local oom
  echo "::error::[${label}] failed — memory diagnosis:"
  echo "cgroup limit : $(cat /sys/fs/cgroup/memory.max 2>/dev/null)"
  echo "cgroup peak  : $(cat /sys/fs/cgroup/memory.peak 2>/dev/null)"
  echo "cgroup events:"
  cat /sys/fs/cgroup/memory.events 2>/dev/null
  oom=$(awk '/^oom_kill/ {print $2}' /sys/fs/cgroup/memory.events 2>/dev/null)
  if [ "${oom:-0}" -gt 0 ]; then
    echo "::error::[${label}] OOM-KILLED: the cgroup limit was hit (${oom} kill(s)); raise the job memory limit or lower BB_NUMBER_THREADS/PARALLEL_MAKE"
  fi
  echo "memtrace tail:"
  tail -5 "$MEMGUARD_LOG" 2>/dev/null
  exit 1
}

memguard_stop() {
  kill "${MEMGUARD_PID:-}" 2>/dev/null
}
