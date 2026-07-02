kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/30402cabd180309b63629a7eb884deb4caf1c95b.tar.gz
  ref: 5b80b500a58c839c2affb7683a6958b09358bb876b090a9a65ecb2a5b1c7cca4
  base-dir: kde-build-meta-x-30402cabd180309b63629a7eb884deb4caf1c95b

config:
  options:
    arch: "%{arch}"
