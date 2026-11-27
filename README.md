# simply-cpp-thanos

[Thanos](https://thanos.io) (Prometheus long-term storage: object-store blocks, downsampling,
retention per resolution, a global query view), its official Linux amd64 build packaged as an apt
package. There's no source of ours here beyond the packaging: the binary is the release Thanos
publishes, downloaded and checked against `SHA256.txt`.

This exists so a server or container gets Thanos with `apt install` from apt.roelof.co.za,
updated like any other package, instead of a binary copied by hand. Ubuntu has no Thanos package.

## Install

```bash
curl -fsSL https://apt.roelof.co.za/setup.sh | bash
sudo apt -y install simply-cpp-thanos
thanos --version
```

It installs `/usr/bin/thanos` and Thanos's licence, nothing else: no configuration, no user, no
service. Every component is a subcommand of the one binary (`thanos sidecar`, `thanos store`,
`thanos compact`, `thanos query`); run them under your own units. The binary is a static Go build,
so the package has no Depends. It is published for resolute only
(`SC_DISTS="noble resolute" scripts/deploy.sh` on demand).

## The version

`VERSION.txt` is the Thanos release packaged (its tag is `v<version>`), `SHA256.txt` the SHA-256 of
that release's `thanos-<version>.linux-amd64.tar.gz`, as the release's `sha256sums.txt` lists it.

## Publishing a new version

Set `VERSION.txt` and `SHA256.txt` (from the new release's `sha256sums.txt`), commit, then:

```bash
scripts/deploy.sh
```

The suite's `scripts/publish.sh --only thanos` does the same for it. The same version packaged
again (a packaging change) takes a `REVISION.txt`: 0.42.5-1.

## Licence

The packaging scripts are Apache-2.0 (`LICENSE`); Thanos itself is Apache-2.0, its licence shipped
in the package (`/usr/share/doc/simply-cpp-thanos/copyright`).
