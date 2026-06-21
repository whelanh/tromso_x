kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/0676d853c9dab5ee7005935c386c0bc8ef56d342.tar.gz
  ref: 6a643ea4ecc0f244e79b7a033bfa4fe68d984bbe16219f8cdae4a3817c6d615e
  base-dir: kde-build-meta-x-0676d853c9dab5ee7005935c386c0bc8ef56d342

config:
  options:
    arch: "%{arch}"
