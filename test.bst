kind: script
build-depends:
  - kde-build-meta.bst:freedesktop-sdk.bst:components/oci-builder.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:vm/prepare-image.bst
  - filename: oci/layers/tromso.bst
    config:
      location: /layer
config:
  commands:
    - ls -la /etc/ssl/
    - ls -la /etc/ssl/certs/ || true
    - ls -la /etc/pki/
    - ls -la /layer/etc/ssl/ || true
    - ls -la /layer/etc/pki/ || true
