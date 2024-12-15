#!/bin/sh
SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=false
LATESTARTSERVICE=true

REPLACE="
"

# array / variabel
NAME="Celestial-Thermal | Kzyo"
VERSION="1.0"
ANDROIDVERSION=$(getprop ro.build.version.release)
DATE="Frid 29 Nov 2024"
DEVICES=$(getprop ro.product.board)
MANUFACTURER=$(getprop ro.product.manufacturer)
API=$(getprop ro.build.version.sdk)

# trimming
trim_partition () {
    fstrim -v /system
    sleep 0.1
    fstrim -v /vendor
    sleep 0.1
    fstrim -v /data
    sleep 0.1
    fstrim -v /cache
    sleep 0.1
    fstrim -v /system
    sleep 0.1
    fstrim -v /vendor
    sleep 0.1
    fstrim -v /metadata
    sleep 0.1
    fstrim -v /odm
    sleep 0.1
    fstrim -v /system_ext
    sleep 0.1
    fstrim -v /product
    sleep 0.1
    fstrim -v /data
    sleep 0.1
    fstrim -v /cache
    sleep 0.1
}

sleep 0.2
ui_print ""
ui_print "░█▀▀█ ── ▀▀█▀▀ ░█─░█ ░█▀▀▀ ░█▀▀█ ░█▀▄▀█ ─█▀▀█ ░█─── 
░█─── ▀▀ ─░█── ░█▀▀█ ░█▀▀▀ ░█▄▄▀ ░█░█░█ ░█▄▄█ ░█─── 
░█▄▄█ ── ─░█── ░█─░█ ░█▄▄▄ ░█─░█ ░█──░█ ░█─░█ ░█▄▄█"
ui_print ""
sleep 0.5
ui_print "    disable thermal throttling."
ui_print ""
sleep 0.2
ui_print "***************************************"
ui_print "- Name            : ${NAME}"
sleep 0.2
ui_print "- Version         : ${VERSION}"
sleep 0.2
ui_print "- Android Version : ${ANDROIDVERSION}"
sleep 0.2
ui_print "- Build Date      : ${DATE}"
sleep 0.2
ui_print "***************************************"
ui_print "- Devices         : ${DEVICES}"
sleep 0.2
ui_print "- Manufacturer    : ${MANUFACTURER}"
ui_print "***************************************"
sleep 0.2
ui_print "- Extracting module files"
sleep 2
unzip -o "$ZIPFILE" 'common/*' -d $MODPATH >&2
unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >&2
ui_print "- Trimming up Partitions"
sleep 2
trim_partition &>/dev/null
sleep 0.5

# Set permissions
set_perm_recursive $MODPATH 0 0 0755 0644
