kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/e05bc0691d97f4b3ca5ba3716bf6b954fa9d01e8.tar.gz
  ref: 96d19537d2d3e40edce1f662d2306fd8a45177534e1dfb0157bec8f0d20bfdc7
  base-dir: kde-build-meta-x-e05bc0691d97f4b3ca5ba3716bf6b954fa9d01e8

config:
  options:
    arch: "%{arch}"
