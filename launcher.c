#define _GNU_SOURCE
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdbool.h>
#include <errno.h>
#include <string.h>

/*
    Small launcher to perform the equivalent of this bash one-liner,
    but as a self-contained executable:

    PATH=$(pwd)/AppImage/usr/bin:$PATH \
    RUBYLIB=$(echo $(pwd)/AppImage/bundles/bundle{/usr/lib/ruby/vendor_ruby/2.5.0,/usr/lib/x86_64-linux-gnu/ruby/vendor_ruby/2.5.0,/usr/lib/ruby/vendor_ruby,/usr/lib/ruby/2.5.0,/usr/lib/x86_64-linux-gnu/ruby/2.5.0} | tr ' ' ':') \
    sonic-pi

*/

int main(int argc, char *argv[]) {
    // Step one: find this executable's path.
    size_t size = 256;
    size_t padding = 16;
    char *exe_path = malloc(size);
    while (true) {
        ssize_t written = readlink("/proc/self/exe", exe_path, size-padding);
        if (written < 0) {
            fprintf(stderr, "error finding executable location: %d\n", errno);
            return 1;
        }
        if (written >= (size-padding)) {
            size *= 2;
            if (size >= 64 * 1024) {
                fprintf(stderr, "error finding executable location: max path length exceeded\n");
                return 1;
            }
            exe_path = realloc(exe_path, size);
        } else {
            // success; nul-terminate the string before continuing
            exe_path[written] = '\0';
            break;
        }
    }

    printf("Executable path: %s\n", exe_path);

    // Find the AppImage base directory
    // exe_path will be something like "/tmp/.mount_sonic-1erdOd/bundles/bundle/var/build/linker-2d196bc8632e500316fa0e0c3e8f40d0e7da853ae940805080b3492ce03b7b51"
    // The base directory needs to remove 5 slashes
    char *basedir = strdup(exe_path);
    for (int i = 0; i < 5; i++) {
        char *last_slash = strrchr(basedir, '/');
        printf("Last slash: %s\n", last_slash);
        if (last_slash != NULL) {
            *last_slash = '\0';
        }
    }

    // Set up PATH
    char *path = NULL;
    asprintf(&path, "%s/usr/bin:%s", basedir, getenv("PATH"));
    setenv("PATH", path, 1);
    printf("PATH=%s\n", path);

    // Set up RUBYLIB
    char *rubylib = NULL;
    asprintf(&rubylib,
        "%s/bundles/bundle/usr/lib/ruby/vendor_ruby/2.5.0:"
        "%s/bundles/bundle/usr/lib/x86_64-linux-gnu/ruby/vendor_ruby/2.5.0:"
        "%s/bundles/bundle/usr/lib/ruby/vendor_ruby:"
        "%s/bundles/bundle/usr/lib/ruby/2.5.0:"
        "%s/bundles/bundle/usr/lib/x86_64-linux-gnu/ruby/2.5.0",
        basedir, basedir, basedir, basedir, basedir
    );
    setenv("RUBYLIB", rubylib, 1);

    // Exec sonic-pi
    execlp("sonic-pi", exe_path, NULL);

    return 0;
}