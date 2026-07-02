kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/1e30bf8052bf4c374a3ea460ae12a29b7be5977b.tar.gz
  ref: a5e2224fa035cd8d12e33df78844889ddbcfc5a7d4a56cca51f435fe4b044fe8
  base-dir: kde-build-meta-x-1e30bf8052bf4c374a3ea460ae12a29b7be5977b

config:
  options:
    arch: "%{arch}"
