kind: junction
description: Junction to hanthor/kde-build-meta (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/bbadca5e515e4596e19a39deea071b6d3796ed81.tar.gz
  ref: 787d21306ab84d39f1cca1bb19ab4ea7bac50a1cd52e5ba9c35e17c0c097106e
  base-dir: kde-build-meta-bbadca5e515e4596e19a39deea071b6d3796ed81

config:
  options:
    arch: "%{arch}"
