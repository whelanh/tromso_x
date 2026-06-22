kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/16af5f9664012783bd1747b8adc9ca0a4ed7ea7b.tar.gz
  ref: b26fac5af9e62a078ac1524e49c0a85443db2cc2fc2e6b00020e20339d6acba8
  base-dir: kde-build-meta-x-16af5f9664012783bd1747b8adc9ca0a4ed7ea7b

config:
  options:
    arch: "%{arch}"
