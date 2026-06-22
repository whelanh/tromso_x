kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/148bfc61d550f681539c5a9bb7be3f6a63ba7629.tar.gz
  ref: 32e45315c4a5d4c4b1fc9a4e2e49a16ec807e4098afa024f035d694be8c71abd
  base-dir: kde-build-meta-x-148bfc61d550f681539c5a9bb7be3f6a63ba7629

config:
  options:
    arch: "%{arch}"
