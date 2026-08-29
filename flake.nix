{
  description = "pandas: version-bumped independently from nixpkgs through a Python package overlay.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-lib = {
      url = "github:jgus/flake-lib/v1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { nixpkgs, flake-utils, flake-lib, ... }:
    let
      pin = import ./pin.nix;
      inherit (pin) version hash;
      source = { type = "pypi"; pname = "pandas"; format = "sdist"; };
      overlay = final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (pyfinal: pyprev: {
            pandas = pyprev.pandas.overridePythonAttrs (oldAttrs: {
              inherit version;
              doCheck = false;
              postPatch =
                if final.lib.hasPrefix "2." version then ''
                  substituteInPlace pyproject.toml \
                    --replace-fail "numpy>=2.0" numpy
                '' else if version == "3.0.5" then ''
                  substituteInPlace pyproject.toml \
                    --replace-fail "numpy>=2.0.0,!=2.5.0" numpy
                '' else oldAttrs.postPatch;
              src = pyfinal.fetchPypi { inherit version hash; pname = "pandas"; };
            });
          })
        ];
      };
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          packages = {
            pandas = pkgs.python3.pkgs.pandas;
            default = pkgs.python3.pkgs.pandas;
            update-version = flake-lib.lib.mkUpdateVersion { inherit pkgs source; buildAttr = "pandas"; };
            update-branches = flake-lib.lib.mkUpdateBranches {
              inherit pkgs source;
              pinSchema = "pypi";
              excludePrereleases = true;
            };
          };
        }) // {
      overlays.default = overlay;
    };
}
