{
  lib,
  stdenv,
  rustPlatform,
  rustc,
  versionCheckHook,
  fetchFromGitHub,
  pkg-config,
  patchelf,
  vulkan-loader,
  libxkbcommon,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxrandr,
  wayland,
  dbus,
  craft-fonts,

  nix-update-script,
}:

let
  runtimeDeps = [
    libxkbcommon
    libx11
    libxcb
    libxcursor
    libxi
    wayland
    vulkan-loader
    libxrandr
    dbus
  ];
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "pdfcraft";
  version = "0.16.1";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "pdfcraft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-/OIb4TcNQ92z2PO7kPJxHkPny6kXYz8kjVT+JDzYnMo=";
  };

  cargoHash = "sha256-3fRYRG00cvmGrveRLhu+e+e0F3LoWUJNPwEu380HqXE=";

  postPatch =
    # remove unused patch lines from Cargo.toml, otherwise building will fail
    ''
      sed -i -E '/^(egui_demo_lib|egui_inspection|egui_system_font_provider) = /d' Cargo.toml
    ''
    # rten-gemm uses AVX512-VNNI intrinsics that fail to compile with nixpkgs rustc.
    + lib.optionalString stdenv.hostPlatform.isx86_64 ''
          substituteInPlace "$cargoDepsCopy"/source-registry-0/rten-gemm-*/src/i8dot.rs \
            --replace-fail \
            '            if let Some(isa) = x86_64::Avx512VnniIsa::new() {
                      return unsafe { dispatch_avx512_vnni(isa, self) };
                  }
      ' \
            ""
    '';

  __structuredAttrs = true;
  strictDeps = true;

  env = {
    CRAFT_FONTS_DIR = "${craft-fonts}";
    CRAFT_FONTS_REQUIRED = "1";
  };

  cargoBuildFlags = [
    "--package=pdfcraft"
    "--package=pdfcraft-cli"
  ];

  nativeBuildInputs = [
    pkg-config
    patchelf
  ];

  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    install -Dm644 packaging/linux/ai.storyteller.pdfcraft.desktop \
      $out/share/applications/ai.storyteller.pdfcraft.desktop
    mkdir -p $out/share/icons
    cp -R assets/app-icon/hicolor $out/share/icons/
  '';

  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    patchelf --add-rpath ${lib.makeLibraryPath runtimeDeps} $out/bin/pdfcraft
  '';

  # The `pdfcraft` crate runs live GPU tests; software rendering in CI is too slow.
  cargoTestFlags = [
    "--package=pdfcraft-cli"
  ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Open-source PDF workbench for reading, organizing, and securing documents";
    homepage = "https://github.com/storytold/pdfcraft";
    changelog = "https://github.com/storytold/pdfcraft/releases/tag/v${finalAttrs.version}";
    license =
      with lib.licenses;
      AND [
        (OR [
          mit
          asl20
        ])
        ofl
      ];
    maintainers = with lib.maintainers; [ cleboost ];
    mainProgram = "pdfcraft";
    platforms = rustc.meta.platforms;
  };
})
