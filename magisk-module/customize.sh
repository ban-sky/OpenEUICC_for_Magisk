#!/system/bin/sh
# OpenEUICC Magisk module install hook.
#
# The privileged APK is shipped ONLY as a system app under
# /system_ext/priv-app/OpenEUICC. Never `pm install` it from here: on Android 16
# that creates an unprivileged copy in /data/app which shadows the privileged
# one, so the app starts without READ_PRIVILEGED_PHONE_STATE and crashes with
# "java.lang.SecurityException: Caller does not have permission." on launch.
#
# The previous version of this module did exactly that; this script also cleans
# up the leftover unprivileged copy.

SKIPUNZIP=0

ui_print "- Installing OpenEUICC as a privileged system app"

set_perm "$MODPATH/system/system_ext/priv-app/OpenEUICC/OpenEUICC.apk" 0 0 0644
set_perm "$MODPATH/system/system_ext/etc/permissions/privapp_whitelist_im.angry.openeuicc.xml" 0 0 0644
set_perm "$MODPATH/system/system_ext/etc/default-permissions/openeuicc.xml" 0 0 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755

# Remove an unprivileged copy installed by an older release of this module. It
# would otherwise keep shadowing the system app even after this module is
# mounted successfully.
apk_path="$(pm path im.angry.openeuicc 2>/dev/null | head -n 1)"
apk_path="${apk_path#package:}"
case "$apk_path" in
  /data/app/*)
    ui_print "- Removing outdated unprivileged copy: $apk_path"
    pm uninstall im.angry.openeuicc >/dev/null 2>&1
    ;;
esac

ui_print "- The app becomes available after a reboot."
ui_print "- If it still reports that it is not privileged, check that your"
ui_print "  root manager actually mounts this module (see README)."
