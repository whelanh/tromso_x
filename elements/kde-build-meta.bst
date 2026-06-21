kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/7c9c69d2de1cf9c536b0a016e181c31b30dc9c26.tar.gz
  ref: b73c8e70474b362152d1af13d617d34fad80c57802cc6fbe8489c4a096283ec2
  base-dir: kde-build-meta-x-7c9c69d2de1cf9c536b0a016e181c31b30dc9c26

config:
  options:
    arch: "%{arch}"
