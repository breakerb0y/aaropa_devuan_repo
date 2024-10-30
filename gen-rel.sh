#!/bin/sh
set -e

do_hash() {
  HASH_NAME=$1
  HASH_CMD=$2
  echo "${HASH_NAME}:"
  for f in $(find -type f); do
    f=$(echo $f | cut -c3-) # remove ./ prefix
    if [ "$f" = "Release" ]; then
      continue
    fi
    echo " $(${HASH_CMD} ${f} | cut -d" " -f1) $(wc -c $f)"
  done
}

for dir in dists/*; do
  dist=$(basename $dir)
  dpkg-scanpackages --arch amd64 pool/$dist | gzip -9 >$dir/main/binary-amd64/Packages.gz
  cd $dir
  cat <<EOF >Release
Origin: BlissOS
Label: BlissOS
Suite: $(case $dist in ceres) echo "unstable" ;; excalibur) echo "testing" ;; *) echo "stable" ;; esac)
Codename: $dist
Version: 1.0
Architectures: amd64
Components: main
Description: BlissOS Debian buildiso repo
Date: $(date -Ru)
$(do_hash "MD5Sum" "md5sum")
$(do_hash "SHA1" "sha1sum")
$(do_hash "SHA256" "sha256sum")
EOF
  cd ../..
done
