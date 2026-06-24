kind: compose
description: Minimal KDE final layer (no Aurora branding, essential config only)

build-depends:
  - kde-build-meta.bst:freedesktop-sdk.bst:components/gcc.bst
  - oci/layers/kde-minimal-stack.bst

config:
  exclude:
    - debug
    - devel
    - extra
    - static-blocklist
