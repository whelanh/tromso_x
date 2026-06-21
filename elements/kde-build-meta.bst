kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/b40509ccf0405d2825be7c7f9353e41a204d2b92.tar.gz
  ref: 8e8b5d34bac5f7398ec1fae8346db2ea6f92e938129083749b8e3c77f5c00417
  base-dir: kde-build-meta-x-b40509ccf0405d2825be7c7f9353e41a204d2b92

config:
  options:
    arch: "%{arch}"
