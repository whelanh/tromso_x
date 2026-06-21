kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/a3a1afcbbf694bfbf954d506ece85bffae8915f2.tar.gz
  ref: 6592fd9315f1a17d573ce98a92f9024d5e99997992b8632b61e66ce9414210ae
  base-dir: kde-build-meta-x-a3a1afcbbf694bfbf954d506ece85bffae8915f2

config:
  options:
    arch: "%{arch}"
