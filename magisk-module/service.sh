#!/system/bin/sh
# OpenEUICC Magisk/KernelSU module late-start service.
#
# Two jobs, both after the system has booted:
#
#  1. Self-heal a stale unprivileged copy. Older releases (and hzy132's module)
#     ran `pm install`, which puts the APK in /data/app. Such a copy shadows the
#     system app: Android keeps the updated data app, the app is no longer
#     privileged, and it reports "not running as a system app". Once we can see
#     the module's APK on disk, remove the data copy so the system app wins.
#
#  2. Grant the runtime permissions a system app does not get by itself, and
#     write a small boot report so mount problems are diagnosable.

MODDIR=${0%/*}
LOG=/data/local/tmp/openeuicc-boot.log

i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 120 ]; do
  sleep 5
  i=$((i + 1))
done
sleep 5

SYSTEM_APK=""
if [ -f /system/priv-app/OpenEUICC/OpenEUICC.apk ]; then
  SYSTEM_APK=/system/priv-app/OpenEUICC/OpenEUICC.apk
elif [ -f /system_ext/priv-app/OpenEUICC/OpenEUICC.apk ]; then
  SYSTEM_APK=/system_ext/priv-app/OpenEUICC/OpenEUICC.apk
fi

APK_PATH="$(pm path im.angry.openeuicc 2>/dev/null | head -n 1 || true)"
APK_PATH="${APK_PATH#package:}"

{
  echo "== openeuicc $(date) =="
  echo "module dir: $MODDIR"
  echo "system apk: ${SYSTEM_APK:-missing}"
  echo "pm path: ${APK_PATH:-none}"
} > "$LOG" 2>&1

case "$APK_PATH" in
  /data/app/*)
    if [ -n "$SYSTEM_APK" ]; then
      # The package manager may still be settling right after boot, so retry.
      attempt=0
      while [ "$attempt" -lt 3 ]; do
        attempt=$((attempt + 1))
        echo "removing unprivileged copy (attempt $attempt): $APK_PATH" >> "$LOG"
        pm uninstall im.angry.openeuicc >> "$LOG" 2>&1
        # Bring the system copy back if the uninstall removed the package
        # entirely (it should not: only the /data/app update is removed).
        pm install-existing --user 0 im.angry.openeuicc >> "$LOG" 2>&1
        APK_PATH="$(pm path im.angry.openeuicc 2>/dev/null | head -n 1 || true)"
        APK_PATH="${APK_PATH#package:}"
        echo "pm path after heal: ${APK_PATH:-none}" >> "$LOG"
        case "$APK_PATH" in
          /data/app/*) sleep 10 ;;
          *) break ;;
        esac
      done
    else
      echo "system apk not mounted; leaving data copy alone" >> "$LOG"
    fi
    ;;
esac

# The module provides a system app; make sure a stale "disabled" state does not
# hide it, and grant the runtime permissions.
pm enable im.angry.openeuicc >> "$LOG" 2>&1
pm grant im.angry.openeuicc android.permission.READ_PHONE_STATE >> "$LOG" 2>&1
pm grant im.angry.openeuicc android.permission.POST_NOTIFICATIONS >> "$LOG" 2>&1

exit 0
