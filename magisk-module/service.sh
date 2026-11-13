#!/system/bin/sh
# OpenEUICC Magisk/KernelSU module late-start service.
#
# The module must never leave the device without a usable app. After the system
# has booted we know the real mount state, and then:
#
#  * system APK visible  -> a /data/app copy left over from older installs (or
#    from a previous fallback) would shadow it and run unprivileged, so remove
#    that copy and let the system app win;
#  * system APK missing  -> the module is not mounted (KernelSU mount mode), so
#    install the APK as a normal app instead of leaving nothing behind: the
#    activity then shows the "not a system app" explanation instead of the app
#    silently disappearing. It also stays updatable once the mount is fixed.
#
# Everything is written to /data/local/tmp/openeuicc-boot.log.

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

MODULE_APK=""
for apk in \
  "$MODDIR/system/priv-app/OpenEUICC/OpenEUICC.apk" \
  "$MODDIR/system/system_ext/priv-app/OpenEUICC/OpenEUICC.apk"; do
  if [ -f "$apk" ]; then
    MODULE_APK=$apk
    break
  fi
done

current_path() {
  path="$(pm path im.angry.openeuicc 2>/dev/null | head -n 1 || true)"
  echo "${path#package:}"
}

APK_PATH="$(current_path)"

{
  echo "== openeuicc $(date) =="
  echo "module dir: $MODDIR"
  echo "system apk: ${SYSTEM_APK:-missing}"
  echo "module apk: ${MODULE_APK:-missing}"
  echo "pm path: ${APK_PATH:-none}"
} > "$LOG" 2>&1

if [ -n "$SYSTEM_APK" ]; then
  # Promote the system app: drop a stale /data/app copy that would shadow it.
  attempt=0
  while [ "$attempt" -lt 3 ]; do
    case "$APK_PATH" in
      /data/app/*) ;;
      *) break ;;
    esac
    attempt=$((attempt + 1))
    echo "removing unprivileged copy (attempt $attempt): $APK_PATH" >> "$LOG"
    pm uninstall im.angry.openeuicc >> "$LOG" 2>&1
    pm install-existing --user 0 im.angry.openeuicc >> "$LOG" 2>&1
    APK_PATH="$(current_path)"
    echo "pm path after heal: ${APK_PATH:-none}" >> "$LOG"
    case "$APK_PATH" in
      /data/app/*) sleep 10 ;;
      *) break ;;
    esac
  done
elif [ -z "$APK_PATH" ] && [ -n "$MODULE_APK" ]; then
  # The module is not mounted. Do not leave the user without an app: install the
  # same APK as a normal app so it can explain what is wrong.
  echo "module not mounted; installing fallback app" >> "$LOG"
  tmp_apk=/data/local/tmp/OpenEUICC-fallback.apk
  cp -f "$MODULE_APK" "$tmp_apk" >> "$LOG" 2>&1
  chmod 0644 "$tmp_apk" >> "$LOG" 2>&1
  pm install -r "$tmp_apk" >> "$LOG" 2>&1
  rm -f "$tmp_apk"
  echo "pm path after fallback: $(current_path)" >> "$LOG"
fi

# The module provides a system app; make sure a stale "disabled" state does not
# hide it, and grant the runtime permissions.
pm enable im.angry.openeuicc >> "$LOG" 2>&1
pm grant im.angry.openeuicc android.permission.READ_PHONE_STATE >> "$LOG" 2>&1
pm grant im.angry.openeuicc android.permission.POST_NOTIFICATIONS >> "$LOG" 2>&1

exit 0
