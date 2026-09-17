# nix-fhs.sh — run bitbake inside the yocto FHS (flake output .#yocto-fhs).
#
# The job container is a bare nixos/nix image: nix is installed system-wide
# (multi-user layout) but no daemon runs in a pod, so nix is forced into
# single-user mode against a private store on the persistent work volume.
# The FHS closure and the nixpkgs flake input are fetched once and reused
# by later runs.
#
#   source ci/nix-fhs.sh
#   fhs_run 'source poky/oe-init-build-env build && bitbake foo'

export HOME=/__w/home
export NIX_REMOTE=local
export NIX_CONFIG='experimental-features = nix-command flakes'
export NIX_STORE_DIR=/__w/nix-store
export NIX_STATE_DIR=/__w/nix-state
export NIX_LOG_DIR=/__w/nix-log
mkdir -p "$HOME" "$NIX_STORE_DIR" "$NIX_STATE_DIR" "$NIX_LOG_DIR"

# fhs_run '<script>' — run a POSIX shell script inside the FHS. The repo
# root (cwd) and the environment are preserved; the script's exit code is
# the wrapper's exit code.
fhs_run() {
  nix run .#yocto-fhs -- -c "$1"
}
