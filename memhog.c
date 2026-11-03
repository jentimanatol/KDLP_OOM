#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <MiB> <name>\n", argv[0]);
        return 1;
    }

    long mib = strtol(argv[1], NULL, 10);
    const char *name = argv[2];
    if (mib <= 0) {
        fprintf(stderr, "MiB must be positive\n");
        return 1;
    }

    size_t bytes = (size_t)mib * 1024 * 1024;
    unsigned char *p = malloc(bytes);
    if (!p) {
        perror("malloc");
        return 1;
    }

    /* Touch each page so the allocation becomes resident memory. */
    for (size_t i = 0; i < bytes; i += 4096)
        p[i] = (unsigned char)(i & 0xff);

    printf("%s: PID=%d holding %ld MiB\n", name, getpid(), mib);
    fflush(stdout);

    for (;;) {
        sleep(1);
        /* Keep the compiler from treating the allocation as unused. */
        p[0]++;
    }
}
