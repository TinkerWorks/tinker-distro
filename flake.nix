{
  inputs.nix-environments.url = "github:nix-community/nix-environments";

  outputs = { self, nixpkgs, nix-environments }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    devShells.${system}.default = 
      nix-environments.devShells.${system}.yocto.override {
        python3 = pkgs.python313;
      };
  };
}