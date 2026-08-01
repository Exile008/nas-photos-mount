#!/system/bin/sh

ui_print "- Installing NAS Photos Mount"

case "$ARCH" in
  arm64) ;;
  *) abort "! Only arm64 devices are supported" ;;
esac

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/rclone" 0 0 0755
set_perm "$MODPATH/fusermount3" 0 0 0755

for script in \
  action.sh build-live-photo-excludes.sh cgi-lib.sh compile-ignore.sh lib.sh mount-once.sh \
  refresh-capacity.sh refresh-live-photo-filter.sh remount.sh scan-new.sh service.sh \
  start-web.sh uninstall.sh unmount.sh watchdog.sh; do
  set_perm "$MODPATH/$script" 0 0 0755
done

for cgi in "$MODPATH"/web/cgi-bin/*; do
  [ -f "$cgi" ] && set_perm "$cgi" 0 0 0755
done

ui_print "- Configuration is preserved in /data/adb/nas_photos_mount"
ui_print "- Reboot, then use the module action button to configure SMB"
