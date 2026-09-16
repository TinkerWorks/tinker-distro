# bitbake-heal — self-heal a persistent workspace after a killed run.
#
# When a run is killed mid-task (cgroup OOM, job timeout), bitbake leaves
# the workdir behind without a stamp. The next run re-runs the task, but
# make is incremental: a truncated artifact from the killed run (e.g. a
# 0-byte object file) gets relinked, producing confusing failures like
# "undefined reference to `main'".
#
# bitbake_heal LABEL TARGET...
#   run bitbake; on failure, collect the failed recipes from the latest
#   cooker log, cleansstate them (workdir + stamps + sstate), retry once.
#   A second failure is a real bug: memguard_die reports it (with the
#   memory diagnosis).

bitbake_heal() {
  local label="$1"
  shift
  if bitbake "$@"; then
    return 0
  fi

  # the failed run is always the most recent bitbake invocation; its cooker
  # log is the newest <machine>/*.log (not the console-latest symlink).
  # oe-setup-builddir left the shell cwd in the build dir, so the path is
  # relative (TOPDIR/TMPDIR are bitbake vars, not exported shell vars).
  local cook
  cook=$(ls -t tmp/log/cooker/*/*.log 2>/dev/null \
    | grep -v console-latest | head -1)
  if [ -z "$cook" ]; then
    echo "::warning::[${label}] no cooker log found under $(pwd)/tmp/log/cooker; listing:"
    ls -R tmp/log 2>/dev/null | head -30
  fi
  # "ERROR: Task (/path/recipe_1.2.bb:do_compile) failed" -> recipe_1.2
  local bpns
  bpns=$(grep -hoE 'Task \([^)]+\.bb:[a-z_]+' "$cook" 2>/dev/null \
    | sed -E 's|^Task \(/?.*/([^/]+)\.bb:.*|\1|' \
    | sed -E 's/_.+$//' | sort -u)

  if [ -n "$bpns" ]; then
    echo "::warning::[${label}] failed — cleaning possibly stale state from a killed run: $(echo $bpns)"
    bitbake -c cleansstate $bpns || true
    if bitbake "$@"; then
      echo "::warning::[${label}] retry after cleansstate succeeded"
      return 0
    fi
  else
    echo "::warning::[${label}] no failed recipe tasks in ${cook:-no cooker log}; no retry"
  fi
  memguard_die "$label"
}
