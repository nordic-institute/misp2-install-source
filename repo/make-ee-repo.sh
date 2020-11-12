#!/bin/bash
set -x
deb_home="$(dirname "$0")/.."
cp $deb_home/xtee-misp2-*.deb $deb_home/repo/dists/bionic/main/binary-amd64/
rm -f $deb_home/repo/cache/packages-amd64.db
apt-ftparchive generate $deb_home/repo/apt-ftparchive-ee-repo.conf
apt-ftparchive -c=$deb_home/repo/apt-ftparchive-ee-repo.conf release $deb_home/repo/dists/bionic > $deb_home/repo/dists/bionic/Release
gpg --digest-algo SHA512 --yes --homedir ~/.gnupg/ -u ${DEB_SIGN_KEYID} -bao $deb_home/repo/dists/bionic/Release.gpg $deb_home/repo/dists/bionic/Release

