kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/7e6308f096dd4366afffa69b5c4b0383c1513481.tar.gz
  ref: 3f29c0b7abe38e4ee28cd8deef04d7c852ff39c854384e132891ee9f4c1aaa77
  base-dir: kde-build-meta-x-7e6308f096dd4366afffa69b5c4b0383c1513481

config:
  options:
    arch: "%{arch}"
