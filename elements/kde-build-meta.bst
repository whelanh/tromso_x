kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/db815882458c7d0065113e02ca15c26af7836e2f.tar.gz
  ref: acb8384412335d703503d60042cd533c5031350eb2806a087a0526977899c756
  base-dir: kde-build-meta-x-db815882458c7d0065113e02ca15c26af7836e2f

config:
  options:
    arch: "%{arch}"
