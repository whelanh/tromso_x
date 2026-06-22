kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/0d375537ff3df520c07f49106670611a21481925.tar.gz
  ref: e51c36f1c180ba46be317e7f60b445ca2755fdd3249ba00c90c3ad2536999b1c
  base-dir: kde-build-meta-x-0d375537ff3df520c07f49106670611a21481925

config:
  options:
    arch: "%{arch}"
