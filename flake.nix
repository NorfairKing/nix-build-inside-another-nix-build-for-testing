{
  description = "nix-build-inside-another-nix-build-for-testing";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-25.05";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs =
    { self
    , nixpkgs
    , pre-commit-hooks
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # makePureImpure : Derivation -> Derivation
      # Copied from https://github.com/NorfairKing/pure-impure-nix
      # See https://github.com/NorfairKing/pure-impure-nix/blob/0941bd8b379827fb0341341f999dd27fd615328e/flake.nix#L17-L55 for an explanation.
      makePureImpure = drv: drv.overrideAttrs (old:
        let
          magicString = builtins.unsafeDiscardStringContext (builtins.substring 0 12 (baseNameOf drv.drvPath));
          outputHashAlgo = "sha256";
          outputHash = builtins.hashString outputHashAlgo magicString;
        in
        {
          preferHashedMirrors = false;
          inherit outputHashAlgo;
          inherit outputHash;
          buildCommand = ''
            ${old.buildCommand or ""}
            rm -rf $out
            echo -n "${magicString}" > $out
          '';
        });
    in
    {
      checks.${system} = {
        eval-bare-attr = pkgs.runCommand "nix-eval-bare-attr" { buildInputs = [ pkgs.nix ]; } ''
          export NIX_CONFIG="experimental-features = nix-command flakes"
          export NIX_STATE_DIR=$(mktemp -d)
          nix eval ${./bare-attr}#example > $out
        '';
        show-empty = pkgs.runCommand "nix-show-empty" { buildInputs = [ pkgs.nix ]; } ''
          export NIX_CONFIG="experimental-features = nix-command flakes"
          export NIX_STATE_DIR=$(mktemp -d)
          nix flake show ${./empty} > $out
        '';
        build-simple = pkgs.runCommand "nix-build-simple" { buildInputs = [ pkgs.nix ]; } ''
          export NIX_CONFIG="experimental-features = nix-command flakes"
          export NIX_STATE_DIR=$(mktemp -d)
          export NIX_LOG_DIR=$(mktemp -d)
          nix build ${./simple}# > $out
        '';
        build-this-shell = makePureImpure (pkgs.runCommand "nix-build-this-shell" { buildInputs = [ pkgs.nix pkgs.cacert ]; } ''
          sandboxdir=$(mktemp -d)
          export NIX_CONFIG=$'experimental-features = nix-command flakes\nsandbox-build-dir = '"$sandboxdir"
          export NIX_STATE_DIR=$(mktemp -d)
          export NIX_LOG_DIR=$(mktemp -d)
          export NIX_STORE_DIR=$(mktemp -d)
          export HOME=$(mktemp -d)
          nix build "${self}#devShells.${system}.default"
          touch $out
        '');
        pre-commit = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixpkgs-fmt.enable = true;
          };
        };
      };
      devShells.${system}.default = pkgs.mkShell {
        name = "pure-impure-nix-shell";
        shellHook = self.checks.${system}.pre-commit.shellHook;
      };
    };
}
