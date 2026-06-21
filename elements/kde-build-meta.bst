kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/08bb3623bdac7f959c836100722a650ea32cada5.tar.gz
  ref: cb2fb8867eaedb19bf82942e78ee85fa7cc9b1313bdcb4c381b4c4e1f873199c
  base-dir: kde-build-meta-x-08bb3623bdac7f959c836100722a650ea32cada5

config:
  options:
    arch: "%{arch}"
