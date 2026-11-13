#!/system/bin/sh
# OpenEUICC Magisk/KernelSU post-fs-data hook.
#
# Runs before the package manager scans installed packages, i.e. exactly when
# the module mount has (or has not) been applied. It only records the mount
# state, so a device where the module is not mounted can be diagnosed without
# guessing: /data/local/tmp/openeuicc-mount.log

MODDIR=${0%/*}
LOG=/data/local/tmp/openeuicc-mount.log

{
  echo "== openeuicc mount check $(date) =="
  echo "module dir: $MODDIR"
  for path in \
    /system/priv-app/OpenEUICC/OpenEUICC.apk \
    /system_ext/priv-app/OpenEUICC/OpenEUICC.apk; do
    if [ -f "$path" ]; then
      echo "$path: present ($(ls -l "$path" 2>/dev/null))"
    else
      echo "$path: missing"
    fi
  done
  echo "mounts:"
  mount 2>/dev/null | grep -iE " (system|system_ext) " | head -n 10
} > "$LOG" 2>&1

exit 0
