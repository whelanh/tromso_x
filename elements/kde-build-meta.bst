kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/05b4a03459e259c7d71a29ad1d384bda679293b5.tar.gz
  ref: f2ade0b31eaf69b190e335c0d38cfa1ba6e0e84fc25f27fe0a701587e8acfc0a
  base-dir: kde-build-meta-x-05b4a03459e259c7d71a29ad1d384bda679293b5

config:
  options:
    arch: "%{arch}"
