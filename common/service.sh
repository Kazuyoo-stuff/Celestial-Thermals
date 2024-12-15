#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future

# // Waiting for boot completed
  while [ "$(getprop sys.boot_completed | tr -d '\r')" != "1" ]; do sleep 3; done
  
# // Sync to data in the rare case a device crashes
  sync
  
# write to file
write () {
	# Bail out if file does not exist
	[[ ! -f "$1" ]] && return 1

	# Make file writable in case it is not already
	chmod +w "$1" 2> /dev/null

	# Write the new value and bail if there's an error
	if ! echo "$2" > "$1" 2> /dev/null; then
		echo "Failed: $1 → $2"
		return 1
	fi

	# Log the success
	echo "$1 → $2"
}

# path
    MODDIR=${0%/*}
  
# // variable detect thermal
  thermal=$(getprop | grep "init.svc.*thermal*" | grep "\[running\]" | sed -n 's/.*\[//;s/\].*//p')
  if [[ "$thermal" ]]; then
    THERMAL=running
  elif [[ -z "$(getprop | grep "init.svc.*thermal*")" ]]; then
    THERMAL=unknown
  else
    THERMAL=stopped
  fi

# // Device online functions
  wait_until_login() {
    # // whether in lock screen, tested on Android 7.1 & 10.0
    # // in case of other magisk module remounting /data as RW
    while [ "$(dumpsys window policy | grep mInputRestricted=true)" != "" ]; do
        sleep 0.1
    done
    # // we doesn't have the permission to rw "/sdcard" before the user unlocks the screen
    while [ ! -d "/sdcard/Android" ]; do
        sleep 1
    done
  }
  wait_until_login
  
# information in module.prop or description module
 end_tweak () {
   if [ "$THERMAL" == "stopped" ]; then
     sed -Ei 's/^description=(\[.*][[:space:]]*)?/description=[ Thermal Not Stopped...❌ ] /g' "$MODDIR/module.prop"
   else
     sed -Ei 's/^description=(\[.*][[:space:]]*)?/description=[ Thermal Has Stopped...✅ ] /g' "$MODDIR/module.prop"
   fi 
 }
  
# // disable limit gpu freq
  for gpufreq in /proc/gpufreq; do
    if [ -d "/proc/gpufreq" ]; then
      write $gpufreq/gpufreq_power_limited "0"
      write $gpufreq/gpufreq_limited_thermal_ignore "1"
      write $gpufreq/gpufreq_limited_oc_ignore "1"
      write $gpufreq/gpufreq_limited_low_batt_volume_ignore "1"
      write $gpufreq/gpufreq_limited_low_batt_volt_ignore "1"
    fi
  done
  
# // Disable Core control / hotplug
  for cpu in /sys/devices/system/cpu/cpu[0,4,7]/core_ctl; do
    chmod 666 $cpu/enable
	  write $cpu/enable "0"
	chmod 444 $cpu/enable
  done

# // Disable msm_thermal
  find /sys -name enabled | grep 'msm_thermal' | while IFS= read -r msm_thermal_status; do
    if [ "$(cat "$msm_thermal_status")" = 'Y' ]; then
      write $msm_thermal_status "N"
    fi
    if [ "$(cat "$msm_thermal_status")" = '1' ]; then
      write $msm_thermal_status "0"
    fi
  done
  
# Stops and kills processes of thermal related binaries
  for thermbin in $(find /system/bin/ /system/vendor/bin/ -name *therma* | sed 's#.*/##'); do
    pid=$(ps | grep "$thermbin" | awk '{print $2}')
    if [ ! -z "$pid" ]; then
        su -c kill -9 "$pid"
    fi
        su -c stop "$thermbin"
  done
  
# Reset init.svc.*thermal* properties to stopped
  for thermsvc in $(getprop | grep init.svc.*thermal* | cut -d: -f1 | sed 's/[][]//g'); do
    current_status=$(getprop "$thermsvc")
    if [[ "$current_status" == "running" ]]; then
       resetprop -n $thermsvc "restarting"
    elif [[ "$current_status" == "stopped" ]]; then
       resetprop -n $thermsvc "stopped"
    fi
  done
  
# Clearing thermal debug process PID information
  for thermalpid in $(getprop | grep init.svc_debug_pid.*thermal* | cut -d: -f1 | sed 's/[][]//g'); do
    resetprop -n $thermalpid ""
  done
  
# Stopping any thermal processes found
  for therminit in $(find /system/etc/init/ /system/vendor/etc/init/ -name '*therma*'); do
    pid=$(ps | grep "$therminit" | awk '{print $2}')
    if [ ! -z "$pid" ]; then
        su -c kill -9 "$pid"
    fi
  done

# Make thermal device related files inaccessible by changing their permissions.
  for thermdevtemp in $(find /sys/devices/virtual/thermal/thermal_zone*/ -name '*temp*' -o -name '*trip_point_*' -o -name '*type*'); do
      chmod -R 000 "$thermdevtemp"
  done
  
# Restrict access to thermal files in system-on-chip (SoC) firmware.
  for thermdevsoc in $(find /sys/firmware/devicetree/base/soc/* -name '*thermal*' -o -name '*temp*' -o -name '*limit_info*' -o -name '*name*'); do
      chmod -R 000 "$thermdevsoc"
  done
  
# Blocks access to files that manage or report GPU temperature (kgsl).
  for kgsltemp in $(find /sys/devices/soc/*/kgsl/kgsl-3d0/ -name '*temp*'); do
    chmod -R 000 "$kgsltemp"
  done
  
# // Disable thermal zones
  for thermmode in /sys/devices/virtual/thermal/thermal_zone*/mode; do
    chmod -R 644 "$thermmode"
    write $thermdevmode "disabled"
  done

# // Other thermal disables
  for sched in /proc/sys/kernel; do
    write $sched/sched_boost "0"
  done
  
# // Disable I/O statistics accounting
  for queue in /sys/block/*/queue; do
	 write $queue/iostats "0"
	 write $queue/iosched/slice_idle "0"
  done

# // Disable Via Props  
  if resetprop dalvik.vm.dexopt.thermal-cutoff | grep -q '2'; then
    resetprop -n dalvik.vm.dexopt.thermal-cutoff 0
  fi
  
  if resetprop sys.thermal.enable | grep -q 'true'; then
    resetprop -n sys.thermal.enable false
  fi
  
  if resetprop ro.thermal_warmreset | grep -q 'true'; then
    resetprop -n ro.thermal_warmreset false
  fi
  
# // disable thermal service
  cmd thermalservice override-status 0
  
# // remove cache thermal
  rm -f /data/vendor/thermal/config
  rm -f /data/vendor/thermal/thermal.dump
  rm -f /data/vendor/thermal/thermal_history.dump
   
# Always return success, even if the last write fails
  sync && end_tweak && exit 0
   
# This script will be executed in late_start service mode
