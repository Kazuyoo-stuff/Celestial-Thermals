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
  
# Function to write a value to a specified file
write () {
    local file="$1"
    local value="$2"

    # Check arguments
    if [[ -z "$file" || -z "$value" ]]; then
        return 1
    fi

    # Make sure the file exists
    if [[ ! -f "$file" ]]; then
        return 1
    fi

    # Change file permissions to writable if needed
    if [[ ! -w "$file" ]]; then
        chmod +w "$file" 2>/dev/null || {
            return 1
        }
    fi

    # Write values to file
    if ! echo "$value" > "$file" 2>/dev/null; then
        echo "Failed : $1 → $2"
        return 1
    fi

	# Log the success
	echo "$1 → $2"
    return 0
}

# path
    MODDIR=${0%/*}
  
# // variable detect thermal
  thermal=$(getprop | grep "*thermal*" | grep "\[running\]" | sed -n 's/.*\[//;s/\].*//p')
  if [[ "$thermal" ]]; then
    THERMAL=running
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
     su -lp 2000 -c "cmd notification post -S bigtext -t 'Celestial-Thermals🌡️' tag 'Thermal Status : Stopped'" >/dev/null 2>&1
   else
     su -lp 2000 -c "cmd notification post -S bigtext -t 'Celestial-Thermals🌡️' tag 'Thermal Status : Running'" >/dev/null 2>&1
   fi 
 }
  
# // disable limit gpu freq
  for gpufreq in /proc/gpufreq; do
    if [ -d "/proc/gpufreq/" ]; then
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
      write "$msm_thermal_status" "N"
    fi
    if [ "$(cat "$msm_thermal_status")" = '1' ]; then
      write "$msm_thermal_status" "0"
    fi
  done
  
# Stop thermal process PID via /proc
  for pid in $(grep -l 'thermal' /proc/*/comm 2>/dev/null | awk -F'/' '{print $3}'); do
    if [ -z "$thermal_pids" ]; then
      su -c kill -9 "$pid"
    fi
   done
  
# Stops and kills processes of thermal related binaries
  for thermbin in $(find /system/bin/ /system/vendor/bin/ -name '*thermal*' | sed 's#.*/##'); do
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
       resetprop -n "$thermsvc" "restarting"
    elif [[ "$current_status" == "stopped" ]]; then
       resetprop -n "$thermsvc" "stopped"
    fi
  done
  
# Disable sys.*thermal* properties to stopped
  for thermsys in $(getprop | grep sys.*thermal* | cut -d: -f1 | sed 's/[][]//g'); do
    current_status=$(getprop "$thermsys")
    if [ "$current_status" = '1' ]; then
      resetprop -n "$thermsys" "0"
    fi
  done
 
# Clearing thermal debug process PID information
  for thermalpid in $(getprop | grep init.svc_debug_pid.*thermal* | cut -d: -f1 | sed 's/[][]//g'); do
    resetprop -n "$thermalpid" ""
  done
  
# Stopping any thermal processes found
  for therminit in $(find /system/etc/init/ /system/vendor/etc/init/ -name '*thermal*'); do
    pid=$(ps | grep "$therminit" | awk '{print $2}')
    if [ ! -z "$pid" ]; then
        su -c kill -9 "$pid"
        su -c stop "$therminit"
    fi
  done

# Make thermal device related files inaccessible by changing their permissions.
  for thermdevtemp in $(find /sys/devices/virtual/thermal/thermal_zone*/ -name '*temp*' -o -name '*trip_point_*' -o -name '*type*'); do
      chmod -R 000 "$thermdevtemp"
  done
  
# Restrict access to thermal files in system-on-chip (SoC) firmware.
  for thermdevsoc in $(find /sys/firmware/devicetree/base/soc/*/ -name '*thermal*' -o -name '*temp*' -o -name '*limit_info*' -o -name '*name*'); do
    if [ -d "/sys/firmware/devicetree/base/soc/" ]; then
      chmod -R 000 "$thermdevsoc"
    fi
  done
  
# Set hwmon access permission to inaccessible
  for hwmon in /sys/devices/virtual/hwmon/hwmon*; do
    if [ -d "/sys/devices/virtual/hwmon/" ]; then
      chmod -R 000 "$hwmon"
    fi
  done
    
# Blocks access to files that manage or report GPU temperature (kgsl).
  for kgsltemp in $(find /sys/devices/soc/*/kgsl/kgsl-3d0/ -name '*temp*'); do
    if [ -d "/sys/devices/soc/" ]; then
      chmod -R 000 "$kgsltemp"
    fi
  done

# // Disable thermal zones
  for thermmode in /sys/devices/virtual/thermal/thermal_zone*/mode; do
    chmod -R 644 "$thermmode"
    write "$thermdevmode" "disabled"
  done
  
# temperature power supply (thx to @WeAreRavenS)
  for power_supply in /sys/class/power_supply/*; do
    if [ -d "/sys/class/power_supply/bms/" ]; then
      chmod 000 $power_supply/temp
      chmod 644 $power_supply/temp_cool
      chmod 644 $power_supply/temp_hot
      chmod 644 $power_supply/temp_warm
      write $power_supply/temp_cool "150"
      write $power_supply/temp_hot "480"
      write $power_supply/temp_warm "460"
      chmod 444 $power_supply/temp_cool
      chmod 444 $power_supply/temp_hot
      chmod 444 $power_supply/temp_warm
    fi
  done
  
# Gpu Throttling Disabler
  for kgsl in /sys/class/kgsl/kgsl-3d0; do
    if [ -d "/sys/class/kgsl/kgsl-3d0/" ]; then
      write $kgsl/throttling "0"
      write $kgsl/max_gpuclk "0"
      write $kgsl/force_clk_on "1"
      write $kgsl/adreno_idler_active "N"
      write $kgsl/thermal_pwrlevel "0"
    fi
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

  if [ -e /sys/class/thermal/thermal_message/sconfig ]; then
    chmod 644 /sys/class/thermal/thermal_message/sconfig
    write /sys/class/thermal/thermal_message/sconfig "10"
    chmod 444 /sys/class/thermal/thermal_message/sconfig
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
