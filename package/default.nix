{
  lib,
  buildDotnetModule,
  fetchFromGitHub,
  dotnetCorePackages,
}:

buildDotnetModule (finalAttrs: {
  pname = "fast-github";
  version = "2.3.2";

  src = fetchFromGitHub {
    owner = "yuan71058";
    repo = "FastGithub";
    rev = "v${finalAttrs.version}";
    hash = "sha256-Uowf3a3J7Kvu12VWIJWyryXLQNUqmA5uMp/04+zFnpM=";
  };

  projectFile = "FastGithub/FastGithub.csproj";
  dotnet-sdk = dotnetCorePackages.sdk_10_0;

  # FastGithub targets net7.0 (EOL), so build it self-contained with a newer
  # SDK instead of depending on the insecure .NET 7 SDK/runtime.
  selfContainedBuild = true;

  # runtimeId is left unset so buildDotnetModule picks `systemToDotnetRid` per
  # target platform, which also overrides the win-x64 hard-coded in
  # Directory.Build.props. meta.platforms below is what bounds fetch-deps to
  # only the runtime packs we actually need.

  # Only wrap the fastgithub executable; otherwise buildDotnetModule would
  # also wrap the self-contained runtime natives and the (non-.NET) dnscrypt-proxy.
  executables = [ "fastgithub" ];

  nugetDeps = ./deps.nix;

  # FastGithub disables git's TLS verification globally on startup
  # (git config --global http.sslverify false). Drop that: trust the CA
  # certificate explicitly instead of silently disabling verification.
  postPatch = ''
    sed -i '/GitConfigSslverify(false);/d' FastGithub.HttpServer/Certs/CertService.cs
    # FastGithub forces its working directory to the program directory. Drop
    # that so the wrapper can point CWD at a writable state dir (the store is
    # read-only), while ContentRootPath stays in the store for appsettings.json.
    sed -i '/Environment\.CurrentDirectory = contentRoot;/d' FastGithub/Program.cs
  '';

  # dnscrypt-proxy is a prebuilt binary shipped in the repo; it loses its
  # executable bit when copied by MSBuild, so restore it here.
  postInstall = ''
    chmod +x "$out/lib/${finalAttrs.pname}/dnscrypt-proxy/dnscrypt-proxy"
  '';

  # FastGithub resolves cacert/, dnscrypt-proxy/, dnsendpoints.json, logs/ and
  # appsettings/ relative to its working directory. With the Program.cs patch
  # above, CWD is whatever the wrapper sets, so point it at a writable state
  # dir and symlink the read-only resources there (the store stays read-only).
  postFixup = ''
    rm -f "$out/bin/fastgithub"
    cat > "$out/bin/${finalAttrs.pname}" <<'WRAPPER'
    #!/usr/bin/env bash
    set -euo pipefail

    libdir=${placeholder "out"}/lib/${finalAttrs.pname}
    statedir="$XDG_STATE_HOME"
    if [ -z "$statedir" ]; then
      statedir="$HOME/.local/state/fastgithub"
    fi

    mkdir -p "$statedir/dnscrypt-proxy"
    # Read-only resources: symlink into the writable state dir.
    ln -sfn "$libdir/appsettings" "$statedir/appsettings"
    ln -sfn "$libdir/dnscrypt-proxy/dnscrypt-proxy" "$statedir/dnscrypt-proxy/dnscrypt-proxy"
    # dnscrypt-proxy.toml is rewritten at startup, so it needs a writable copy.
    [ -e "$statedir/dnscrypt-proxy/dnscrypt-proxy.toml" ] || install -m 644 "$libdir/dnscrypt-proxy/dnscrypt-proxy.toml" "$statedir/dnscrypt-proxy/"

    cd "$statedir"
    exec "$libdir/fastgithub" "$@"
    WRAPPER
    chmod +x "$out/bin/${finalAttrs.pname}"
  '';

  strictDeps = true;
  __structuredAttrs = true;

  meta = {
    description = "GitHub acceleration tool that solves GitHub inaccessibility, avatar and release loading failures, and git clone/pull/push issues in mainland China.";
    homepage = "https://github.com/yuan71058/FastGithub";
    license = lib.licenses.mit;
    mainProgram = "fast-github";
    # platforms defaults to dotnet-sdk's (x86_64-linux, aarch64-linux,
    # aarch64-darwin), which is exactly the set FastGithub ships dnscrypt-proxy
    # binaries for and .NET 7 has runtime packs for.
    maintainers = [ ];
  };
})
