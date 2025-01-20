let
  pkgs = import <nixpkgs> {};
in pkgs.mkShell {
  packages = [
    pkgs.pyright
    (pkgs.python3.withPackages (python-pkgs: [
      python-pkgs.screeninfo
      python-pkgs.pyinstaller
    ]))
  ];
}

