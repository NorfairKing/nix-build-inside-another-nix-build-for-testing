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
