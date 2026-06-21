kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/b3a992e3f0ef3514115db3fec484daa797698645.tar.gz
  ref: f7a35df8f99fc0ca2ed098b34d009ada94d77d3f44711ccf10808c6dcbe5552c
  base-dir: kde-build-meta-x-b3a992e3f0ef3514115db3fec484daa797698645

config:
  options:
    arch: "%{arch}"
