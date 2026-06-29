kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/008e76e50.tar.gz
  ref: 5dea4ccc5367893a1242f862cbadbff0b0afdc12731065dc2eaf733113b4a654
  base-dir: kde-build-meta-x-008e76e50eb1d4ed44cea3d2c04c4cb8adfbc8e2

config:
  options:
    arch: "%{arch}"
