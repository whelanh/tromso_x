kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/f5d5e509a5d66b9833818332e5a3e629e2d139cc.tar.gz
  ref: 9e7b93be18df8d777f75da2fa8c9fc2445de58a59aa16d7d53db474b1e035a6b
  base-dir: kde-build-meta-x-f5d5e509a5d66b9833818332e5a3e629e2d139cc

config:
  options:
    arch: "%{arch}"
