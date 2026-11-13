#!/system/bin/sh
# OpenEUICC Magisk/KernelSU module install hook.
#
# The privileged APK is shipped ONLY as a system app. Never `pm install` it from
# here: on Android 16 that creates an unprivileged copy in /data/app which
# shadows the privileged one, so the app starts without
# READ_PRIVILEGED_PHONE_STATE and reports "not running as a system app".
#
# The APK lives in /system/priv-app/OpenEUICC on purpose: /system is the one
# partition every KernelSU/Magisk mount implementation (overlayfs, magic mount,
# mountify, meta-overlayfs) is guaranteed to cover. Older releases used
# /system_ext, which several KernelSU setups do not overlay, leaving the app
# installed but unprivileged.
#
# An older release of this module installed a /data/app copy. Remove it, or it
# keeps shadowing the system app even after this module mounts successfully.

SKIPUNZIP=0

ui_print "- Installing OpenEUICC as a privileged system app (/system/priv-app)"

APK="$MODPATH/system/priv-app/OpenEUICC/OpenEUICC.apk"
if [ ! -f "$APK" ]; then
  abort "! OpenEUICC.apk missing from the module archive"
fi

set_perm "$APK" 0 0 0644
set_perm "$MODPATH/system/etc/permissions/privapp_whitelist_im.angry.openeuicc.xml" 0 0 0644
set_perm "$MODPATH/system/system_ext/etc/permissions/privapp_whitelist_im.angry.openeuicc.xml" 0 0 0644
set_perm "$MODPATH/system/system_ext/etc/default-permissions/openeuicc.xml" 0 0 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755

# Remove an unprivileged copy installed by an older release of this module. It
# would otherwise keep shadowing the system app even after this module is
# mounted successfully. If `pm` is not usable yet, service.sh retries on boot.
apk_path="$(pm path im.angry.openeuicc 2>/dev/null | head -n 1 || true)"
apk_path="${apk_path#package:}"
case "$apk_path" in
  /data/app/*)
    ui_print "- Removing outdated unprivileged copy: $apk_path"
    pm uninstall im.angry.openeuicc >/dev/null 2>&1 || true
    ;;
esac

ui_print "- Reboot to activate the system app."
ui_print "- If the app still reports that it is not privileged, the module is not"
ui_print "  mounted: check /system/priv-app/OpenEUICC/OpenEUICC.apk, and see README"
ui_print "  for KernelSU mount notes (mountify / metamodule)."
