kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/efa0347d3d9122cc7deda5bb241a6e6f83c2ecae.tar.gz
  ref: 8e31ef246954d278e82025d392d092c5a17bfd2a7a873eed1ed058922f7ea5a3
  base-dir: kde-build-meta-x-efa0347d3d9122cc7deda5bb241a6e6f83c2ecae

config:
  options:
    arch: "%{arch}"
