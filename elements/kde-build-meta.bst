kind: junction
description: Junction to hanthor/kde-build-meta (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/ecadd31.tar.gz
  ref: ed4f0ede25da4b472001ec5ac625a5d315d70a3e01bc4d9127e835ab5590e71b
  base-dir: kde-build-meta-ecadd3149743c2cee7a8e31d0e4ef12be7c38273

config:
  options:
    arch: "%{arch}"
