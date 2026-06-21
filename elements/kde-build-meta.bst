kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/d844938241fd1c6611b8e50f8b39479b555bb9b9.tar.gz
  ref: 29f3187282b37d64b5d79d759de6e8b948e0fad72e80baa8cb43d14092df6442
  base-dir: kde-build-meta-x-d844938241fd1c6611b8e50f8b39479b555bb9b9

config:
  options:
    arch: "%{arch}"
