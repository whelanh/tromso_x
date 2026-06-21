kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/6c5301e89d9d9d4b1166ea1ad1f336ce69e6718f.tar.gz
  ref: 5cc460d72e271d5cdbeb67cd01c375c976fc4d174e3d640edb575993b5a21217
  base-dir: kde-build-meta-x-6c5301e89d9d9d4b1166ea1ad1f336ce69e6718f

config:
  options:
    arch: "%{arch}"
