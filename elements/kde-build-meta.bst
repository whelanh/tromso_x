kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/784405fdadf000d0d795c2673db54bd1e68f2640.tar.gz
  ref: 8430db1a018007a496de56f49aad166458d3cd7a6d64e3a4f8134f09e6e077bb
  base-dir: kde-build-meta-x-784405fdadf000d0d795c2673db54bd1e68f2640

config:
  options:
    arch: "%{arch}"
