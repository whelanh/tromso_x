kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/561ebea15edcf9a44063faf77a1d785d18cefe66.tar.gz
  ref: c5c4c386f7d7290c901d47682524e38b5acb409e32b153abb01764695f8b347f
  base-dir: kde-build-meta-x-561ebea15edcf9a44063faf77a1d785d18cefe66

config:
  options:
    arch: "%{arch}"
