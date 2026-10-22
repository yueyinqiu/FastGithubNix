# FastGithub-Nix

Nix packaging for [FastGithub](https://github.com/yuan71058/FastGithub) — a GitHub acceleration tool that solves GitHub inaccessibility, avatar and release loading failures, and `git clone` / `pull` / `push` issues in mainland China.

## Adding as a flake input

```nix
{
  inputs = {
    fast-github.url = "github:yueyinqiu/FastGithub-Nix";
  };
}
```

## Package

The binary is exposed as `fast-github`:

```nix
fast-github.packages.${system}.fast-github
```

Or try it directly from the CLI:

```console
$ nix run github:yueyinqiu/FastGithub-Nix
```

## Usage

FastGithub runs as a normal user (it only listens on the non-privileged local
ports `38457` and `5533+`):

```console
$ fast-github
```

Then set your system proxy (or the proxy of the process you want to accelerate)
to:

```
http://127.0.0.1:38457
```

FastGithub is a MITM proxy: on first launch it generates a per-machine CA
certificate under its state directory (`$XDG_STATE_HOME/fastgithub/cacert/`,
defaulting to `~/.local/state/fastgithub/cacert/`) and tries to trust it
system-wide. On NixOS the automatic installer is a no-op (the expected
`update-ca-certificates` paths do not exist), so it just prints a warning and
you trust `cacert/fastgithub.crt` manually if you need it.

> FastGithub decrypts all GitHub traffic it proxies, so treat its CA
> certificate as sensitive and only run a copy you trust.

---

All documentation and `description` fields in this repository are AI-generated.
