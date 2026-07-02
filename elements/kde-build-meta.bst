kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/2b0f29c94924258e4185eb9235f8114b4c46957c.tar.gz
  ref: 2017360db692fa4aaa56d6c67e5b14a26cea36482049471709d06681efce5b85
  base-dir: kde-build-meta-x-2b0f29c94924258e4185eb9235f8114b4c46957c

config:
  options:
    arch: "%{arch}"
