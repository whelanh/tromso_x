kind: junction
description: Junction to hanthor/kde-build-meta (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/e3f159b.tar.gz
  ref: d465b79aeb70bb3aeb4f809bcec39b03651b929bb2c9d8f9db3d4b56ab7fefe0
  base-dir: kde-build-meta-e3f159b14edcf6442e8be74b48be47ec26290717

config:
  options:
    arch: "%{arch}"
