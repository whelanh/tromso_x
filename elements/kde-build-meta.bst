kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/1cca375f716b28d16bd92b9b75e24f373288861a.tar.gz
  ref: 73fc132bf88ace172df0a6e984431f209dbedb2c373b2232ae7976ddeca96046
  base-dir: kde-build-meta-x-1cca375f716b28d16bd92b9b75e24f373288861a

config:
  options:
    arch: "%{arch}"
