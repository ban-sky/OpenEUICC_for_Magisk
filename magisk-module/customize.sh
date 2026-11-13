#!/system/bin/sh
# OpenEUICC Magisk/KernelSU module install hook.
#
# The privileged APK ships as a system app in BOTH /system/priv-app and
# /system_ext/priv-app, because KernelSU mount implementations differ in which
# partitions they overlay. The package manager keeps the /system copy when both
# are visible and ignores the duplicate, so shipping both is safe.
#
# We deliberately do NOT run `pm install` here and we do NOT uninstall anything
# here. Installing the APK into /data/app creates an unprivileged copy that
# shadows the system app (the original Android 16 crash), and uninstalling at
# install time can leave the user with no app at all if the module turns out not
# to be mounted after the reboot. service.sh makes that decision at boot, when
# the real mount state is known.

SKIPUNZIP=0

ui_print "- Installing OpenEUICC as a privileged system app"

for apk in \
  "$MODPATH/system/priv-app/OpenEUICC/OpenEUICC.apk" \
  "$MODPATH/system/system_ext/priv-app/OpenEUICC/OpenEUICC.apk"; do
  if [ -f "$apk" ]; then
    set_perm "$apk" 0 0 0644
  fi
done

set_perm "$MODPATH/system/etc/permissions/privapp_whitelist_im.angry.openeuicc.xml" 0 0 0644
set_perm "$MODPATH/system/system_ext/etc/permissions/privapp_whitelist_im.angry.openeuicc.xml" 0 0 0644
set_perm "$MODPATH/system/system_ext/etc/default-permissions/openeuicc.xml" 0 0 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755

if [ -f "$MODPATH/system/priv-app/OpenEUICC/OpenEUICC.apk" ]; then
  ui_print "- APK packaged for /system/priv-app and /system_ext/priv-app"
else
  ui_print "! OpenEUICC.apk missing from the module archive"
  ui_print "! The module will not provide the app; re-download the zip"
fi

ui_print "- Reboot to activate the system app."
ui_print "- After boot, /data/local/tmp/openeuicc-boot.log records whether the"
ui_print "  module was mounted. If it was not, the app is installed as a normal"
ui_print "  app and explains what to fix; see README for KernelSU mount notes."
