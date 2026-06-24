kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/c7a86251d8f49f4d2eed4a9bac1453573e0e3978.tar.gz
  ref: 73d169097597cc1350a6c9e691c1db49ec61d2ed40a3d74cb7427203d2ea3d72
  base-dir: kde-build-meta-x-c7a86251d8f49f4d2eed4a9bac1453573e0e3978

config:
  options:
    arch: "%{arch}"
