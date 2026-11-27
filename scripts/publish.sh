#!/bin/bash
#~~~~~~~~~~
# Downloads the pinned Thanos release (its official Linux amd64 build), checks it against
# SHA256.txt, packages it as the simply-cpp-thanos .deb, and publishes it into the apt repo for
# resolute (SC_DISTS overrides). The binary is a static Go build, so one build server makes it for
# every distribution - deploy.sh runs it on one.
#
# Run this in the directory deploy.sh synced it to (/var/www/build/sc-thanos).

set -euo pipefail

version=$(tr -d ' \t\n' < VERSION.txt)
checksum=$(tr -d ' \t\n' < SHA256.txt)
tarball="thanos-${version}.linux-amd64.tar.gz"
url="https://github.com/thanos-io/thanos/releases/download/v${version}/${tarball}"
licence_url="https://raw.githubusercontent.com/thanos-io/thanos/v${version}/LICENSE"
package="simply-cpp-thanos"
# A packaging revision (REVISION.txt) when the same upstream version is packaged again:
# 0.42.5-1 sorts after 0.42.5.
revision=$( [ -f REVISION.txt ] && tr -d ' \t\n' < REVISION.txt || true)
package_version="${version}${revision:+-$revision}"
deb_file="${package}_${package_version}_amd64.deb"

mkdir -p work
if [ ! -f "work/$tarball" ]; then
    echo "Downloading $url"
    wget -q -O "work/$tarball.part" "$url"
    mv "work/$tarball.part" "work/$tarball"
fi
# The release as published, or nothing: SHA256.txt is the checksum from the release's
# sha256sums.txt, taken when VERSION.txt was set.
if ! echo "$checksum  work/$tarball" | sha256sum -c --quiet -; then
    echo "$tarball doesn't match SHA256.txt: not packaged" >&2
    rm -f "work/$tarball"
    exit 1
fi
if [ ! -f "work/LICENSE-$version" ]; then
    wget -q -O "work/LICENSE-$version" "$licence_url"
fi

rm -rf pkg work/extracted
mkdir -p pkg/DEBIAN pkg/usr/bin work/extracted
# --no-same-owner: the build folder is on NFS, where chown to the tarball's owner fails.
tar xzf "work/$tarball" --no-same-owner -C work/extracted
install -m 755 "work/extracted/thanos-${version}.linux-amd64/thanos" pkg/usr/bin/thanos

cat > pkg/DEBIAN/control <<EOF
Package: $package
Version: $package_version
Architecture: amd64
Section: net
Priority: optional
Maintainer: Roelof Rossouw
Homepage: https://thanos.io
Description: Thanos, Prometheus long-term storage and downsampling, packaged for apt
 Thanos $version's official Linux amd64 build, installed as /usr/bin/thanos, so it can be
 installed like any other package instead of copied by hand. One binary serves every
 component (sidecar, store, compact, query, receive, rule); it brings no configuration,
 user or service: run it under your own units.
EOF

# copyright: upstream's licence, where Debian keeps one (/usr/share/doc/<package>/copyright).
install -d "pkg/usr/share/doc/$package"
{
    echo "$package packages Thanos $version (https://github.com/thanos-io/thanos), licensed under Apache-2.0."
    echo "The packaging scripts (https://github.com/roelofrossouw/simply-cpp-thanos) are Apache-2.0."
    echo
    echo "----- Thanos: LICENSE -----"
    cat "work/LICENSE-$version"
} > "pkg/usr/share/doc/$package/copyright"

# The binary runs: a broken download or a build for another machine stops here.
pkg/usr/bin/thanos --version

dpkg-deb --build --root-owner-group pkg "$deb_file"

pushd /var/www/build/repo >/dev/null
export GNUPGHOME=/var/www/build/signing
# resolute only (prometheus.v runs resolute); SC_DISTS="noble resolute" publishes elsewhere on demand.
for dist in ${SC_DISTS:-resolute}; do
    if reprepro list "$dist" | grep -q "$package .*$package_version"; then
        echo "$dist: $package $package_version already published"
    else
        echo "$dist: publishing $package $package_version"
        reprepro remove "$dist" "$package" || true
        reprepro includedeb "$dist" "/var/www/build/sc-thanos/$deb_file"
    fi
done
popd >/dev/null

echo "Done."
