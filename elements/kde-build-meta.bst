kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/7568f8e948f176d20ac51a6baae475d6387ec281.tar.gz
  ref: 67fe946c14f7e14a100c16d421b09c32728728606e85804e1bb920aa1f9ca5d6
  base-dir: kde-build-meta-x-7568f8e948f176d20ac51a6baae475d6387ec281

config:
  options:
    arch: "%{arch}"
