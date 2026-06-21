kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/5f7765b462d855404bfced3535df5235f5f18ba8.tar.gz
  ref: 065ae76839b84c59e48b984148be20d9dd102243aa5926c76b4ee2230362a59a
  base-dir: kde-build-meta-x-5f7765b462d855404bfced3535df5235f5f18ba8

config:
  options:
    arch: "%{arch}"
