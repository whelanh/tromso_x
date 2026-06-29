kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/c672d4844.tar.gz
  ref: 8296d5e6803aa6340b6e2b4159b75da753b6de66bcb5d72fdb8c7bba396c65c4
  base-dir: kde-build-meta-x-c672d48444100d46d3ee95fd5192fe0f980efe60

config:
  options:
    arch: "%{arch}"
