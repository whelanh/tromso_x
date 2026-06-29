kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/4000111.tar.gz
  ref: 1a0bfa8240f7f1b5044edf8d845be52e15c2be483c9cdb0e0ed80ad3e0eae74b
  base-dir: kde-build-meta-x-4000111fb97cbbee23bc61cb81796581dc6e70bb

config:
  options:
    arch: "%{arch}"
