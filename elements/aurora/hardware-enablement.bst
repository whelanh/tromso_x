kind: stack
description: Hardware enablement packages for Aurora (fingerprint, sensors, mobile devices)

depends:
  # Fingerprint authentication
  - kde-build-meta.bst:gnomeos-deps/fprintd.bst

  # Android device USB access
  - kde-build-meta.bst:gnomeos-deps/android-udev-rules.bst

  # Sensor support (accelerometer, auto-rotation)
  - kde-build-meta.bst:gnomeos-deps/iio-sensor-proxy.bst
