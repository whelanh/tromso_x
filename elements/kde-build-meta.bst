kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/3de861b849894cd7af277c3cbcd7ff72ec99a206.tar.gz
  ref: dda885984c97aa344847d2a4c88204d236bfba2311eaaa95dc1aaa3fd78df805
  base-dir: kde-build-meta-x-3de861b849894cd7af277c3cbcd7ff72ec99a206

config:
  options:
    arch: "%{arch}"
