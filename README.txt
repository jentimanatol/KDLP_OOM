KDLP Midpoint Presentation — Linux Out-of-Memory Handling

Files:

- memhog.c                    Small memory-pressure test program
- oom_demo.ps1                PowerShell/Podman live-demo helper


1. Open PowerShell in this folder.
2. Confirm the KDLP image exists:
      podman images
   The script expects: f26_kdlp_container
3. Run:
      .\oom_demo.ps1
4. The script pauses before creating memory pressure, so you can explain the scores.

Expected behavior:
- A and B each hold about 80 MiB.
- A gets oom_score_adj=1000.
- C adds 110 MiB, exceeding the 256 MiB cgroup limit.
- A should be strongly preferred for selection because of its adjustment.

If 110 MiB does not trigger pressure on your machine, change C from 110 to 130 MiB.
If more than one process stops, that is still valid: explain that the first stop may not free enough memory to satisfy the allocation.

Safety:
The demo limits only the Podman container to 256 MiB. Do not test by exhausting the host machine's memory.
