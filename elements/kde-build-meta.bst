kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/811ad5a3de2aa3ff16ce2943b8b0e2aa92765133.tar.gz
  ref: 121abbef12361ad682b40f0f9ced6041bc2d5c8a4e13987ba74535d800b7dcc0
  base-dir: kde-build-meta-x-811ad5a3de2aa3ff16ce2943b8b0e2aa92765133

config:
  options:
    arch: "%{arch}"
