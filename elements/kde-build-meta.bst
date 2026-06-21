kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/67a47d39a6021dc78778d113593885959caceea9.tar.gz
  ref: 6c4079b8500e8f6652957700c7f7eef80fea168d86cd392908c5cd900bb2f0de
  base-dir: kde-build-meta-x-67a47d39a6021dc78778d113593885959caceea9

config:
  options:
    arch: "%{arch}"
