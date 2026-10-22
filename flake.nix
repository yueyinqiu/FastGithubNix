{
  description = "Nix packaging for FastGithub";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    {
      packages = forAllSystems (
        system:
        let
          package = nixpkgs.legacyPackages.${system}.callPackage ./package { };
        in
        {
          fastgithub = package;
          default = package;
        }
      );
    };
}
