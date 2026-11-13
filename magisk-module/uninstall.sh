#!/system/bin/sh
# OpenEUICC Magisk module uninstall hook.

# The app is a system app provided by this module, so ask the package manager
# to forget it (this also removes its data).
pm uninstall im.angry.openeuicc >/dev/null 2>&1

exit 0
