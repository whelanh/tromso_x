kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/06b16d020dcda54c7bf1230f9d3cd40ef778bc76.tar.gz
  ref: 011660fb1bfcf48fcd7f0ad4ffe73b791c1dc66e4a187bffbfc59b134fd5a870
  base-dir: kde-build-meta-x-06b16d020dcda54c7bf1230f9d3cd40ef778bc76

config:
  options:
    arch: "%{arch}"
