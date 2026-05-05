kind: compose
description: Aurora unified boot runtime

build-depends:
  - oci/layers/aurora-stack.bst

config:
  exclude:
    - devel
    - debug
    - static-blocklist
