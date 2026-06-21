kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/a72eaccb13750a3b02c0bee2ecaed7445a077134.tar.gz
  ref: 381a1106bd827728820e6a52d513cf2fceade00aa021911abd795c1c5fab5c38
  base-dir: kde-build-meta-x-a72eaccb13750a3b02c0bee2ecaed7445a077134

config:
  options:
    arch: "%{arch}"
