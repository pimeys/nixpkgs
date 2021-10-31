{ lib, rustPlatform, fetchFromGitHub, gtk, webkitgtk, glib, pkg-config }:

rustPlatform.buildRustPackage rec {
  pname = "gnvim-unwrapped";
  version = "6ba47373545c6e9be3677a3ae695415809cf2fdf";

  src = fetchFromGitHub {
    owner = "vhakulinen";
    repo = "gnvim";
    rev = "${version}";
    sha256 = "sha256-lXqywzy0KUKqylShIH3ykGzLEnieN3rYPdnC2lCG+pQ=";
  };

  cargoSha256 = "sha256-iv2RUUcFonGlemSalhJ2FFZoV4NOk2LGCWmauSjh4Eg=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ gtk webkitgtk glib ];

  # The default build script tries to get the version through Git, so we
  # replace it
  postPatch = ''
    cat << EOF > build.rs
    use std::env;
    use std::fs::File;
    use std::io::Write;
    use std::path::Path;

    fn main() {
        let out_dir = env::var("OUT_DIR").unwrap();
        let dest_path = Path::new(&out_dir).join("gnvim_version.rs");
        let mut f = File::create(&dest_path).unwrap();
        f.write_all(b"const VERSION: &str = \"${version}\";").unwrap();
    }
    EOF

    # Install the binary ourselves, since the Makefile doesn't have the path
    # containing the target architecture
    sed -e "/target\/release/d" -i Makefile
  '';

  postInstall = ''
    make install PREFIX="${placeholder "out"}"
  '';

  meta = with lib; {
    description = "GUI for neovim, without any web bloat";
    homepage = "https://github.com/vhakulinen/gnvim";
    license = licenses.mit;
    maintainers = with maintainers; [ minijackson ];
  };
}
