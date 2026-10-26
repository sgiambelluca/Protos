/*
 * logwrite.c - Guía 1 E11: genera registros en el formato de FORMATO-LOG.md
 *   record = when SP level SP length ":" message LF
 * Uso: ./logwrite mensajes.log
 */
#define _POSIX_C_SOURCE 200809L   /* clock_gettime, localtime con -std=c11 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MAX_MSG 65535

static long long now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (long long) ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static int log_record(FILE *f, const char *level, const char *msg) {
    size_t len = strlen(msg);               /* longitud en BYTES (UTF-8), no en caracteres */
    if (len > MAX_MSG) return -1;
    fprintf(f, "%lld %s %zu:", now_ms(), level, len);
    fwrite(msg, 1, len, f);                 /* los bytes tal cual: sin escapar nada */
    fputc('\n', f);
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "uso: %s <archivo>\n", argv[0]);
        return EXIT_FAILURE;
    }
    FILE *f = fopen(argv[1], "ab");          /* "b": que no traduzca \n en ningún sistema */
    if (f == NULL) {
        perror(argv[1]);
        return EXIT_FAILURE;
    }
    log_record(f, "INFO", "servidor iniciado");
    log_record(f, "WARNING", "disco al 90%");
    log_record(f, "INFO", "mensaje con\nsalto de línea, eñe y acentos: ñáé");
    log_record(f, "INFO", "");
    fclose(f);
    return EXIT_SUCCESS;
}
