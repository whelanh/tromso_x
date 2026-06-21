kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/d3974604cd45399f5497844857d5716f9a3654f5.tar.gz
  ref: 6c3358e7155d63923a2171e568018678ec89fb5a81c8d31a26e96dcc1e3ed4fa
  base-dir: kde-build-meta-x-d3974604cd45399f5497844857d5716f9a3654f5

config:
  options:
    arch: "%{arch}"
