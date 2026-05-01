kind: compose
description: Aurora unified boot runtime

build-depends:
  - oci/layers/aurora-stack.bst

config:
  include:
    - runtime
    - bootc
    - ostree-boot
  exclude:
    - debug
    - devel
    - static-blocklist
