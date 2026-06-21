kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/ccd94c4a80421c8ed4cc78c71521392efc492dfc.tar.gz
  ref: 26df07991260bbbd516439e33c1d29002e23f5f1291b71646eab25df88e1cc6c
  base-dir: kde-build-meta-x-ccd94c4a80421c8ed4cc78c71521392efc492dfc

config:
  options:
    arch: "%{arch}"
