#!/bin/bash

RELEASE=unstable

# Function to download files using aria2c
download_with_aria2() {
  echo "Downloading $1 using aria2c..."
  aria2c -x 16 -s 16 -q "$1"
}

# Function to download files using wget
download_with_wget() {
  echo "Downloading $1 using wget..."
  wget -q "$1"
}

set_downloader() {
  if command -v aria2c &>/dev/null; then
    DOWNLOAD=download_with_aria2
  else
    DOWNLOAD=download_with_wget
  fi
  export DOWNLOAD
}

init_repo() {
  local repo
  while read -r repo; do
    repo=($repo)
    export "repo_${repo[0]%:}"="${repo[1]}"
  done <repos.yml
}

ARCH=($(grep Architectures conf/distributions | awk -F : '{print $2}'))

init_repo
set_downloader

signkey=$1
[ "$signkey" ] || signkey=$(grep SignWith conf/distributions | awk '{print $2}')
[ "$signkey" = "yes" ] && signkey=

for arch in "${ARCH[@]}"; do
  [ "$arch" = source ] && continue
  while read -r pkg; do
    pkg=($pkg)
    $DOWNLOAD "$(eval echo "\$repo_${pkg[0]%:}")/download/${pkg[1]}_${pkg[2]}_${arch}.deb"
  done <packages.conf
  while read -r info; do
    info=($info)
    name=${info[1]}_${info[2]}_${arch}
    base="$(eval echo "\$repo_${info[0]%:}")/download/${name}"
    $DOWNLOAD "${base}.buildinfo"
    $DOWNLOAD "${base}.changes"
    ./debsign.sh ${signkey:+-k "$signkey"} "${name}.changes"
  done <buildinfo.conf
done

mkdir -p tmp
mv *.{deb,buildinfo,changes} tmp

for changes in tmp/*.changes; do
  reprepro include $RELEASE "$changes"
done
