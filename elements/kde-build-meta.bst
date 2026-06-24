kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/f56e8ad65229100eadbae522c881b851d4d0ebad.tar.gz
  ref: 629de40e91cc8386d074ad05ac424207f7a931b58ba34b7a7ee1957cc78c0c31
  base-dir: kde-build-meta-x-f56e8ad65229100eadbae522c881b851d4d0ebad

config:
  options:
    arch: "%{arch}"
