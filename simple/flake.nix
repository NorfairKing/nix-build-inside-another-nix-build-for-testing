{
  outputs = _:
    let
      system = "x86_64-linux";
      script = builtins.toFile "success" ''
        #!/bin/sh

        echo "Success" > $out
      '';
      success = builtins.derivation {
        name = "success";
        builder = "/bin/sh";
        args = [ script ];
        inherit system;
      };
    in
    {
      packages.${system}.default = success;
    };
}
