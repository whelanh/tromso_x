kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/35753a1b4efbad65129f14e06d696900842c0278.tar.gz
  ref: 8cc02cd052a4f9dda87c0a79fc3ae665532873e1879c2c4aeecac80a9bf0475b
  base-dir: kde-build-meta-x-35753a1b4efbad65129f14e06d696900842c0278

config:
  options:
    arch: "%{arch}"
