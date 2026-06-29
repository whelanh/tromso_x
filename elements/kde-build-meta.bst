kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/455d6882cfaf1ef2ccac89388b95decae0c302d2.tar.gz
  ref: 28ed4477e2b7f63b348537f5f7613d9bcdc91b6c2628e4ceea5239aee03dd244
  base-dir: kde-build-meta-x-455d6882cfaf1ef2ccac89388b95decae0c302d2

config:
  options:
    arch: "%{arch}"
