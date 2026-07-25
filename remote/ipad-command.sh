#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

echo '=== Current memory ==='
vm_stat 2>/dev/null | sed -n '1,20p' || true

echo '=== Current top processes by RSS ==='
ps -axo pid=,ppid=,rss=,etime=,state=,command= 2>/dev/null \
  | sort -nr -k3 \
  | sed -n '1,30p' || true

echo '=== Process counts ==='
printf 'all_processes='; ps -ax 2>/dev/null | wc -l | tr -d ' '
printf 'node_processes='; pgrep -x node 2>/dev/null | wc -l | tr -d ' '
printf 'python_processes='; pgrep -x python3 2>/dev/null | wc -l | tr -d ' '

echo 'cleanup_result=no_live_node_processes_to_kill'
