kind: stack
description: Hardware enablement packages for Aurora (fingerprint, sensors, mobile devices)

depends:
  # Fingerprint authentication
  - kde-build-meta.bst:kde-linux-deps/fprintd.bst

  # Android device USB access
  - kde-build-meta.bst:kde-linux-deps/android-udev-rules.bst

  # Sensor support (accelerometer, auto-rotation)
  - kde-build-meta.bst:kde-linux-deps/iio-sensor-proxy.bst
