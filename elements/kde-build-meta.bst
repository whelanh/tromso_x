kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/731c144fe751ac445fc34359caf7f458fd25deab.tar.gz
  ref: 66862a9ed2d3dbdd2d209bc6dda27657af0d00ae637faf272f873622187f858f
  base-dir: kde-build-meta-x-731c144fe751ac445fc34359caf7f458fd25deab

config:
  options:
    arch: "%{arch}"
