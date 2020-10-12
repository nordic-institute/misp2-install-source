#!/bin/bash
# build_misp2_packages.sh
set -e

cd ~/misp2

[ -e ./misp2-install-source ] && [ -e ./misp2-orbeon-war ] && [ -e ./misp2-web-app ] \
      || { echo "clone misp2-install-source, misp2-orbeon-war and misp2-web-app below this ( $(pwd) ) directory!" ; exit 1;  }
cd ./misp2-install-source

chmod a+x build.sh

./build.sh -nogit
