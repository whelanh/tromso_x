kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/93e270c07623fddd3ba3b19d6a6cbdb49aef9b2e.tar.gz
  ref: 36392423bc95d2110d845b2546622bfc625655be00552696b5639e2405a59752
  base-dir: kde-build-meta-x-93e270c07623fddd3ba3b19d6a6cbdb49aef9b2e

config:
  options:
    arch: "%{arch}"
