# Safe KDLP OOM demo using a memory-limited Podman container.
# Run from PowerShell in the same folder as memhog.c.

$ErrorActionPreference = "Stop"
$Image = "f26_kdlp_container"
$Name = "oom-demo"

Write-Host "1) Starting a container limited to 256 MiB..."
podman rm -f $Name 2>$null | Out-Null
podman run -d --rm --name $Name --memory=256m --memory-swap=256m $Image sleep infinity | Out-Null

Write-Host "2) Copying and compiling the test program..."
podman cp .\memhog.c "${Name}:/tmp/memhog.c"
podman exec $Name gcc -O2 -Wall /tmp/memhog.c -o /tmp/memhog

Write-Host "3) Starting process A and B (80 MiB each)..."
podman exec $Name sh -lc '/tmp/memhog 80 A > /tmp/A.log 2>&1 & echo $! > /tmp/A.pid'
podman exec $Name sh -lc '/tmp/memhog 80 B > /tmp/B.log 2>&1 & echo $! > /tmp/B.pid'
Start-Sleep -Seconds 1

Write-Host "`nCurrent processes and OOM values:"
podman exec $Name sh -lc 'for n in A B; do p=$(cat /tmp/$n.pid); echo "$n PID=$p score=$(cat /proc/$p/oom_score) adj=$(cat /proc/$p/oom_score_adj)"; done'

Write-Host "`n4) Making A much more likely to be selected (oom_score_adj=1000)..."
podman exec $Name sh -lc 'p=$(cat /tmp/A.pid); echo 1000 > /proc/$p/oom_score_adj; echo "A score=$(cat /proc/$p/oom_score) adj=$(cat /proc/$p/oom_score_adj)"'

Read-Host "Press Enter to create memory pressure"

Write-Host "5) Starting process C (110 MiB). Total demand now exceeds the 256 MiB limit..."
podman exec $Name sh -lc '/tmp/memhog 110 C > /tmp/C.log 2>&1 & echo $! > /tmp/C.pid'
Start-Sleep -Seconds 3

Write-Host "`nProcesses still alive:"
podman exec $Name sh -lc 'for n in A B C; do p=$(cat /tmp/$n.pid 2>/dev/null || true); if [ -n "$p" ] && kill -0 $p 2>/dev/null; then echo "$n alive (PID=$p)"; else echo "$n stopped"; fi; done'

Write-Host "`nCgroup memory events:"
podman exec $Name sh -lc 'cat /sys/fs/cgroup/memory.events 2>/dev/null || true'

Write-Host "`nLogs:"
podman exec $Name sh -lc 'for f in /tmp/A.log /tmp/B.log /tmp/C.log; do echo "--- $f"; cat $f 2>/dev/null || true; done'

Write-Host "`nDemo complete. Clean up with: podman rm -f $Name"
