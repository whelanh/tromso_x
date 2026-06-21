kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/bbd0717d3cbb481db37e53a566632a205c5c63b1.tar.gz
  ref: 8714b8ffdec8c1b214bb6fd644339984084ffeae924eddb7259c5a669067700b
  base-dir: kde-build-meta-x-bbd0717d3cbb481db37e53a566632a205c5c63b1

config:
  options:
    arch: "%{arch}"
