kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/43077a427f525b435ca47141c47a2a41d3c8ca92.tar.gz
  ref: de6a54187c2ef86636fb06d109f21d5d592f203a9977e3aa43a90629a1f7667c
  base-dir: kde-build-meta-x-43077a427f525b435ca47141c47a2a41d3c8ca92

config:
  options:
    arch: "%{arch}"
