kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/fddb2334f843050a56ebf4dd726b69bea38a14b3.tar.gz
  ref: b52571509c89fdc9fd749f458e2edf78b56dbb05a891cb02ae0564962716b313
  base-dir: kde-build-meta-x-fddb2334f843050a56ebf4dd726b69bea38a14b3

config:
  options:
    arch: "%{arch}"
