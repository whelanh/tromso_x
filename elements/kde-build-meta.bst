kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/5e909db985dd41f23f3c3cb4b7b3aa38bfba4cc5.tar.gz
  ref: 9ff08bc712ba95d361fdfa94fbcaaeb74f62f5c08fe32577d991f395c68f0bff
  base-dir: kde-build-meta-x-5e909db985dd41f23f3c3cb4b7b3aa38bfba4cc5

config:
  options:
    arch: "%{arch}"
