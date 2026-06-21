kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/62db80f4daa1c7ad8a785d172b0291f4a14888b3.tar.gz
  ref: 54d9c3e941ea14d8d8832051e167e8ad65ae3f88e5002705d644ac2ce46242db
  base-dir: kde-build-meta-x-62db80f4daa1c7ad8a785d172b0291f4a14888b3

config:
  options:
    arch: "%{arch}"
