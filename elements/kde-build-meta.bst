kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/e8e3fbb5d1fc13abcbedda315abbcc7d40580d14.tar.gz
  ref: 6cf2f21e3d097f9cd3a870001fa9692036c54906f15d98c255631bac2e91ad8d
  base-dir: kde-build-meta-x-e8e3fbb5d1fc13abcbedda315abbcc7d40580d14

config:
  options:
    arch: "%{arch}"
