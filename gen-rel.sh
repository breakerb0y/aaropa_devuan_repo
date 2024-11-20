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
  case $dist in
  ceres) suite=unstable ;;
  excalibur) suite=testing ;;
  *) suite=stable ;;
  esac
  
  for archdir in $dir/main/binary-*; do
    pkgfile=$archdir/Packages
    arch=${archdir##*-}
    dpkg-scanpackages --multiversion --arch $arch pool/$dist >$pkgfile
    cat $pkgfile | gzip -9 >$pkgfile.gz
    cd $dir
    cat <<EOF >Release
Origin: BlissOS
Label: BlissOS
Suite: $suite
Codename: $dist
Version: 1.0
Architectures: $arch
Components: main
Date: $(date -Ru)
$(do_hash "SHA256" "sha256sum")
EOF
    cd ..
  done
  cd ..
done
