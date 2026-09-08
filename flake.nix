{
  # Pinned to 24.11 (glibc 2.40 / GCC 13): scarthgap native recipes (m4 gnulib)
  # don't build on GCC 15, and glibc >2.40 makes bitbake disable uninative.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    # Vendored from nix-community/nix-environments envs/yocto with zlib/zstd
    # removed from the FHS (see nix/yocto-shell.nix for why).
    devShells.${system}.default =
      import ./nix/yocto-shell.nix {
        inherit pkgs;
        python3 = pkgs.python313;
      };

    # `nix develop` only enters the FHS sandbox interactively, so scripted
    # builds use this wrapper directly: nix run .#yocto-fhs -- -c '<cmds>'
    packages.${system}.yocto-fhs = self.devShells.${system}.default.fhs;
  };
}
