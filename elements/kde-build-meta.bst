kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/0e2f5d3bfc2422b421706e4c8e5f2c34c39ae1d8.tar.gz
  ref: 38a6135161e570bcdbce764bafc8c57773aa014f64b5c5478d562874a7ab1706
  base-dir: kde-build-meta-x-0e2f5d3bfc2422b421706e4c8e5f2c34c39ae1d8

config:
  options:
    arch: "%{arch}"
