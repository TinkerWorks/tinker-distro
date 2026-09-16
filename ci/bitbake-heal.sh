# bitbake-heal — self-heal a persistent workspace after a killed run.
#
# When a run is killed mid-task (cgroup OOM, job timeout), bitbake leaves
# the workdir behind without a stamp. The next run re-runs the task, but
# make is incremental: a truncated artifact from the killed run (e.g. a
# 0-byte object file) gets relinked, producing confusing failures like
# "undefined reference to `main'". Stale state arrives in waves — healing
# one recipe lets the build progress until it hits the next victim — so
# this loops: fail -> cleansstate the failed recipes -> retry, up to
# MAX_HEALS times. A failure after MAX_HEALS is a real bug: memguard_die
# reports it (with the memory diagnosis).

MAX_HEALS=3

bitbake_heal() {
  local label="$1"
  shift
  if bitbake "$@"; then
    return 0
  fi

  local attempt=0 cook bpns
  while [ "$attempt" -lt "$MAX_HEALS" ]; do
    attempt=$((attempt + 1))
    # the failed run is always the most recent bitbake invocation; its
    # cooker log is the newest <machine>/*.log (not the console-latest
    # symlink). oe-setup-builddir left the shell cwd in the build dir,
    # so the path is relative (TOPDIR/TMPDIR are bitbake vars, not
    # exported shell vars).
    cook=$(ls -t tmp/log/cooker/*/*.log 2>/dev/null \
      | grep -v console-latest | head -1)
    if [ -z "$cook" ]; then
      echo "::warning::[${label}] no cooker log found under $(pwd)/tmp/log/cooker; listing:"
      ls -R tmp/log 2>/dev/null | head -30
      break
    fi
    # "ERROR: Task (/path/recipe_1.2.bb:do_compile) failed" -> recipe_1.2
    bpns=$(grep -hoE 'Task \([^)]+\.bb:[a-z_]+' "$cook" 2>/dev/null \
      | sed -E 's|^Task \(/?.*/([^/]+)\.bb:.*|\1|' \
      | sed -E 's/_.+$//' | sort -u)
    if [ -z "$bpns" ]; then
      echo "::warning::[${label}] no failed recipe tasks in $cook; no retry"
      break
    fi
    echo "::warning::[${label}] heal $attempt/$MAX_HEALS: cleaning stale state from a killed run: $(echo $bpns)"
    bitbake -c cleansstate $bpns || true
    if bitbake "$@"; then
      echo "::warning::[${label}] succeeded after heal $attempt"
      return 0
    fi
  done
  memguard_die "$label"
}
