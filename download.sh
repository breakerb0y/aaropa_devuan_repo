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

# avoid command failure
exit_check() { [ "$1" = 0 ] || exit "$1"; }
trap 'exit_check $?' EXIT

ARCH=($(grep Architectures dist/conf/distributions | awk -F : '{print $2}'))
SIGNKEY=$(grep SignWith dist/conf/distributions | awk '{print $2}')
[ "$SIGNKEY" = "yes" ] && SIGNKEY=

if command -v aria2c &>/dev/null; then
  DOWNLOAD=download_with_aria2
else
  DOWNLOAD=download_with_wget
fi
export DOWNLOAD

while read -r repo; do
  url=${repo}/download

  # Download metadata
  if ! $DOWNLOAD "${url}/metadata.yml"; then
    echo "WARNING: Repository '$repo' does not provide a metadata.yml. Skipping..."
    continue
  fi

  repo_name=$(grep Name metadata.yml | awk '{print $2}')
  repo_ver=$(grep Version metadata.yml | awk '{print $2}')
  repo_variants=($(grep Variants metadata.yml | awk -F : '{print $2}'))
  rm -f metadata.yml

  for arch in "${ARCH[@]}"; do
    [ "$arch" = source ] && continue

    base_name=${repo_name}_${repo_ver}_${arch}
    $DOWNLOAD "${url}/${base_name}.buildinfo"
    $DOWNLOAD "${url}/${base_name}.changes"

    # Sign the .changes file
    ./debsign.sh ${SIGNKEY:+-k "$SIGNKEY"} "${base_name}.changes"

    # Download .deb
    for variant in "${repo_variants[@]}"; do
      [ "$variant" = "default" ] && pkgvar= || pkgvar=$variant
      $DOWNLOAD "${url}/${repo_name}${pkgvar:+-${pkgvar}}_${repo_ver}_${arch}.deb"
    done
  done
done <repos.lst

{
  cd dist
  for changes in ../*.changes; do
    reprepro include $RELEASE "$changes"
  done
}
