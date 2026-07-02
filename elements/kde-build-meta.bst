kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/753a438bf1832c6bf20f801aad81cb5c7ef8e5d6.tar.gz
  ref: 4473badf40f9bbecf886ee384f33fb48af936e2017369c82f1c8b6a5392dfdc4
  base-dir: kde-build-meta-x-753a438bf1832c6bf20f801aad81cb5c7ef8e5d6

config:
  options:
    arch: "%{arch}"
