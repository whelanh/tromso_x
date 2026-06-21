kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/d49e4c73eb53b3978cb953204b3e777447d8f284.tar.gz
  ref: 24e91451d0924af85e4b5cdcd667d19b002230b8b6a4c786eb7e29eb2eb4f762
  base-dir: kde-build-meta-x-d49e4c73eb53b3978cb953204b3e777447d8f284

config:
  options:
    arch: "%{arch}"
