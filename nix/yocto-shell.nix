{ pkgs ? import <nixpkgs> { }
, stdenv ? pkgs.stdenv
, python3 ? pkgs.python3
, extraPkgs ? [ ]
, extraPythonPkgs ? [ ]
, shellHookPost ? ""
}:

let
  ncurses' = pkgs.ncurses5.overrideAttrs
    (old: {
      configureFlags = old.configureFlags ++ [ "--with-termlib" ];
      postFixup = "";
    });
  lz4' = pkgs.lz4.overrideAttrs
    (old: {
      postInstall = ''
        ln -rs $out/bin/lz4 $out/bin/lz4c
      '';
    });
  # rust-snapshot ships a prebuilt rustc that needs libz.so.1 at RUN time, but a
  # bare /usr/lib/libz.so would let the cross linker resolve -lz to the host x86
  # lib again (the reason zlib is absent from targetPkgs below). Ship only the
  # versioned SONAME: ld.so finds it, -lz does not.
  zlibRuntime = pkgs.runCommand "zlib-runtime-only" { } ''
    mkdir -p $out/lib
    cp -a ${pkgs.zlib}/lib/libz.so.1* $out/lib/
  '';
  # meta-clang's clang-native links its configure tests with -lgcc. GCC knows its
  # own install dir, clang does not: it probes /usr/lib/gcc/<triple>/<version>,
  # which a nix FHS has no reason to contain, so -lgcc fails to resolve. Expose
  # GCC's install dir at that path. Nested under lib/gcc, so it does not add
  # host libs to the cross linker's bare -L/usr/lib search (cf. zlib above).
  gccInstallDir = pkgs.runCommand "gcc-install-dir" { } ''
    mkdir -p $out/lib $out/include
    ln -s ${stdenv.cc.cc}/lib/gcc $out/lib/gcc
    # Having found that install dir, clang derives the libstdc++ headers from it
    # as <install>/../../../../include/c++/<version> = /usr/include/c++/<version>,
    # so they have to be there too or every C++ header ('atomic', 'cstring') is
    # "file not found".
    ln -s ${stdenv.cc.cc}/include/c++ $out/include/c++
  '';
  pythonWithPkgs = python3.withPackages (ps: [ ps.setuptools ps.pyaml ps.websockets ] ++ extraPythonPkgs);
  fhs = pkgs.buildFHSEnvBubblewrap {
    name = "yocto-fhs";
    targetPkgs = pkgs: with pkgs; [
      attr
      bc
      binutils
      bzip2
      chrpath
      cpio
      diffstat
      expect
      file
      stdenv.cc
      gdb
      git
      gnumake
      hostname
      kconfig-frontends
      libxcrypt
      libxcrypt-legacy
      lz4'
      # https://github.com/NixOS/nixpkgs/issues/218534
      # postFixup would create symlinks for the non-unicode version but since it breaks
      # in buildFHSEnv, we just install both variants
      ncurses'
      (ncurses'.override { unicodeSupport = false; })
      openssh
      patch
      perl
      pythonWithPkgs
      rpcsvc-proto
      unzip
      util-linux
      wget
      which
      xz
      zlibRuntime
      gccInstallDir
      # zlib/zstd removed: their dev .so symlinks land in bare /usr/lib and the
      # cross linker resolves -lz/-lzstd to the host x86 libs during libtool
      # relinks (binutils do_install). Yocto builds zlib-native/zstd-native
      # itself, so the host copies are not needed. If another host lib collides
      # the same way ("/usr/lib/libX.so file format not recognized"), drop it here too.
      bison
      flex
      pkg-config
    ] ++ (with pkgs.xorg; [
      libX11
      libXext
      libXrender
      libXi
      libXtst
      libxcb
    ]) ++ extraPkgs;
    multiPkgs = ps: [ ];
    extraOutputsToInstall = [ "dev" ];
    profile =
      let
        inherit (pkgs) lib;

        setVars = {
          # The ld wrapper reads the suffix-salted name; the bare one it ignores.
          # Without this nix bakes /nix/store/<glibc>/lib into every native
          # binary's RUNPATH, so a uninative-interpreted binary (uninative ships
          # its own, newer glibc) loads the FHS libc instead and dies on
          # GLIBC_PRIVATE symbols, e.g. gn: "undefined symbol:
          # __nptl_change_stack_perm".
          "NIX_DONT_SET_RPATH" = "1";
          "NIX_DONT_SET_RPATH_${stdenv.cc.suffixSalt}" = "1";
        };

        exportVars = [
          "LOCALE_ARCHIVE"
          "NIX_CC_WRAPPER_TARGET_HOST_${stdenv.cc.suffixSalt}"
          "NIX_CFLAGS_COMPILE"
          "NIX_CFLAGS_LINK"
          "NIX_LDFLAGS"
          "NIX_DYNAMIC_LINKER_${stdenv.cc.suffixSalt}"
        ];

        exports =
          (builtins.attrValues (builtins.mapAttrs (n: v: "export ${n}= \"${v}\"") setVars)) ++
          (builtins.map (v: "export ${v}") exportVars);

        passthroughVars = (builtins.attrNames setVars) ++ exportVars;

        # TODO limit export to native pkgs?
        nixconf = pkgs.writeText "nixvars.conf" ''
          # This exports the variables to actual build environments
          # From BB_ENV_PASSTHROUGH_ADDITIONS
          ${lib.strings.concatStringsSep "\n" exports}

          # Exclude these when hashing
          # the packages in yocto
          BB_BASEHASH_IGNORE_VARS += "${lib.strings.concatStringsSep " " passthroughVars}"
        '';
      in
      ''
        # buildFHSEnvBubblewrap configures ld.so.conf while buildFHSEnv additionally sets the LD_LIBRARY_PATH.
        # This is redundant, and incorrectly overrides the RPATH of yocto-built binaries causing the dynamic loader
        # to load libraries from the host system that they were not built against, instead of those from yocto.
        unset LD_LIBRARY_PATH

        # By default gcc-wrapper will compile executables that specify a dynamic loader that will ignore the FHS
        # ld-config causing unexpected libraries to be loaded when when the executable is run.
        export NIX_DYNAMIC_LINKER_${stdenv.cc.suffixSalt}=${
        if pkgs.stdenv.isx86_64 then
          "/lib/ld-linux-x86-64.so.2"
        else if pkgs.stdenv.isAarch64 then
          "/lib/ld-linux-aarch64.so.1"
        else
          throw "Unsupported architecture: only x86_64 and aarch64 are supported!"
        }

        # These are set by buildFHSEnvBubblewrap
        export BB_ENV_PASSTHROUGH_ADDITIONS="${lib.strings.concatStringsSep " " passthroughVars}"

        # source the config for bibake equal to --postread
        export BBPOSTCONF="${nixconf}"
        ${shellHookPost}
      '';
  };
in
fhs.env.overrideAttrs (_: { passthru = { inherit fhs; }; })
