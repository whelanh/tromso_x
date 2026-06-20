kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/e50f20c07fb742866d2e5aea54753c72453546b0.tar.gz
  ref: 15dbb5e598b0e70159a2e6ae344fff3269ed1f9c2d9bf79caf1f9240620692bc
  base-dir: kde-build-meta-x-e50f20c07fb742866d2e5aea54753c72453546b0

config:
  options:
    arch: "%{arch}"
