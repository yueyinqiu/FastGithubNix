{
  lib,
  buildDotnetModule,
  fetchFromGitHub,
  dotnetCorePackages,
}:

buildDotnetModule (finalAttrs: {
  pname = "fastgithub";
  version = "2.3.2";

  src = fetchFromGitHub {
    owner = "yuan71058";
    repo = "FastGithub";
    rev = "v${finalAttrs.version}";
    hash = "sha256-Uowf3a3J7Kvu12VWIJWyryXLQNUqmA5uMp/04+zFnpM=";
  };

  projectFile = "FastGithub/FastGithub.csproj";
  dotnet-sdk = dotnetCorePackages.sdk_8_0;

  # FastGithub targets net7.0 (EOL), so build it self-contained with a newer
  # SDK instead of depending on the insecure .NET 7 SDK/runtime.
  selfContainedBuild = true;

  # Limit to a single RID so fetch-deps only downloads the runtime packs for
  # this platform instead of every platform in meta.platforms.
  runtimeId = "linux-x64";

  # Only wrap the fastgithub executable; otherwise buildDotnetModule would
  # also wrap the self-contained runtime natives and the (non-.NET) dnscrypt-proxy.
  executables = [ "fastgithub" ];

  nugetDeps = ./deps.nix;

  # FastGithub disables git's TLS verification globally on startup
  # (git config --global http.sslverify false). Drop that: trust the CA
  # certificate explicitly instead of silently disabling verification.
  postPatch = ''
    sed -i '/GitConfigSslverify(false);/d' FastGithub.HttpServer/Certs/CertService.cs
  '';

  # dnscrypt-proxy is a prebuilt binary shipped in the repo; it loses its
  # executable bit when copied by MSBuild, so restore it here.
  postInstall = ''
    chmod +x "$out/lib/${finalAttrs.pname}/dnscrypt-proxy/dnscrypt-proxy"
  '';

  # FastGithub hard-codes `Environment.CurrentDirectory = Path.GetDirectoryName(Environment.ProcessPath)`
  # in Program.cs, so it always runs from its own install directory. Since the Nix
  # store is read-only, the wrapper must copy the whole program into a writable
  # state dir and exec it from there (it writes cacert/, rewrites dnscrypt-proxy.toml,
  # and caches IPs relative to that dir).
  postFixup = ''
    cat > "$out/bin/${finalAttrs.pname}" <<'WRAPPER'
    #!/usr/bin/env bash
    set -euo pipefail

    libdir=${placeholder "out"}/lib/${finalAttrs.pname}
    statedir="$XDG_STATE_HOME"
    if [ -z "$statedir" ]; then
      statedir="$HOME/.local/state/fastgithub"
    fi

    if [ ! -x "$statedir/fastgithub" ] || [ "$(cat "$statedir/.version" 2>/dev/null || true)" != "${finalAttrs.version}" ]; then
      mkdir -p "$statedir"
      cp -r "$libdir/." "$statedir/"
      chmod -R u+w "$statedir"
      chmod +x "$statedir/fastgithub" "$statedir/dnscrypt-proxy/dnscrypt-proxy"
      printf '%s\n' "${finalAttrs.version}" > "$statedir/.version"
    fi

    exec "$statedir/fastgithub" "$@"
    WRAPPER
    chmod +x "$out/bin/${finalAttrs.pname}"
  '';

  strictDeps = true;
  __structuredAttrs = true;

  meta = {
    description = "GitHub acceleration tool that solves GitHub inaccessibility, avatar and release loading failures, and git clone/pull/push issues in mainland China.";
    homepage = "https://github.com/yuan71058/FastGithub";
    license = lib.licenses.mit;
    mainProgram = "fastgithub";
    # runtimeId is pinned to linux-x64, so only x86_64-linux is supported.
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
})
