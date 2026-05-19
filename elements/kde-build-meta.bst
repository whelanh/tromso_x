kind: junction
description: Junction to hanthor/kde-build-meta (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/9967fed.tar.gz
  ref: 15f530ee9bee1fc58cf56174e60c43e82d9dd74661b757d0c2a4b921316244da
  base-dir: kde-build-meta-9967fed11efc5ef24c51fa7035594ad51b8daf3b

config:
  options:
    arch: "%{arch}"
