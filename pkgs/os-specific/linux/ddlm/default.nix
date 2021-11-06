{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "ddlm";
  version = "2021-07-05";

  src = fetchFromGitHub {
    owner = "deathowl";
    repo = pname;
    rev = "f43920d8a3527fbbd724e2b894a120eb9ba784bb";
    sha256 = "sha256-d8bVaw4UM9ti1+3YKWaptwWOfwLTdMPn5qDOoq5N9Fc=";
  };

  cargoSha256 = "sha256-8kY033e2qDMxgmolFJrSwCuajQHB9m8TyI/DNerNmRE=";

  meta = with lib; {
    description = "deathowl's dummy login manager";
    homepage = "https://github.com/deathowl/ddlm";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ pimeys ];
    platforms = platforms.linux;
  };
}
