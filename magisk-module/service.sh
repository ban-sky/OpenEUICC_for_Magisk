#!/system/bin/sh
# OpenEUICC Magisk module late-start service.
#
# READ_PHONE_STATE is a dangerous (runtime) permission. A privileged system app
# does not get it automatically, so grant it once the system has booted. This
# replaces the `pm grant` call that used to live in customize.sh, where the
# package is often not visible yet.

MODDIR=${0%/*}

# Wait until the package manager has finished booting.
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 120 ]; do
  sleep 5
  i=$((i + 1))
done
sleep 5

# The module provides a system app; make sure a stale "disabled" state or a
# leftover unprivileged install does not hide it.
pm enable im.angry.openeuicc >/dev/null 2>&1
pm grant im.angry.openeuicc android.permission.READ_PHONE_STATE >/dev/null 2>&1
pm grant im.angry.openeuicc android.permission.POST_NOTIFICATIONS >/dev/null 2>&1

exit 0
