#!/usr/bin/env bash

proc_root=${PROC_ROOT:-/proc}
sys_root=${SYS_ROOT:-/sys}

awk '/^cpu([0-9]+)? / {printf "CPU %s", $1; for (i=2; i<=NF; i++) printf " %s", $i; print ""}' "$proc_root/stat"
awk '/^(MemTotal|MemAvailable|MemFree|Buffers|Cached|SReclaimable|Shmem|SwapTotal|SwapFree):/ {print "MEM", $1, $2}' "$proc_root/meminfo"
awk -F ': *' '/^(model name|Hardware|Processor)[[:space:]]*:/ && !model {print "MODEL", $2; model=1} /^processor[[:space:]]*:/ {cores++} END {print "CORES", cores}' "$proc_root/cpuinfo"
temp=
for preferred in x86_pkg_temp TCPU_PCI TCPU; do
  for zone in "$sys_root"/class/thermal/thermal_zone*/; do
    [[ -r "$zone/type" ]] && [[ $(<"$zone/type") = "$preferred" ]] || continue
    value=$(cat "$zone/temp" 2>/dev/null)
    case "$value" in
      ''|*[!0-9]*) continue ;;
    esac
    if [ "$value" -ge 20000 ] && [ "$value" -le 120000 ]; then
      temp=$((value / 1000))
      break 2
    fi
  done
done
echo "TEMP ${temp:-0}"
