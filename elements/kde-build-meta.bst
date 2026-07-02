kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/0078cae474cf4ca5ca846c19271651de708a9774.tar.gz
  ref: 2401c342559276dbd768aae86ee61690b5c1809f4fd0dea2d837a7e67f2da25e
  base-dir: kde-build-meta-x-0078cae474cf4ca5ca846c19271651de708a9774

config:
  options:
    arch: "%{arch}"
