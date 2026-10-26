/*
 * logread.c - Guía 1 E11: lee y valida el formato de FORMATO-LOG.md
 *   record = when SP level SP length ":" message LF
 * Uso: ./logread mensajes.log
 */
#define _POSIX_C_SOURCE 200809L   /* clock_gettime, localtime con -std=c11 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MAX_MSG 65535

/* Lee dígitos hasta encontrar 'fin'. Devuelve -1 si hay algo que no es dígito,
 * si no hay ningún dígito o si se pasa de 'max_digitos'. */
static long long leer_numero(FILE *f, int fin, int max_digitos) {
    long long n = 0;
    int c, digitos = 0;
    while ((c = fgetc(f)) != fin) {
        if (c < '0' || c > '9' || ++digitos > max_digitos) return -1;
        n = n * 10 + (c - '0');
    }
    return digitos == 0 ? -1 : n;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "uso: %s <archivo>\n", argv[0]);
        return EXIT_FAILURE;
    }
    FILE *f = fopen(argv[1], "rb");
    if (f == NULL) {
        perror(argv[1]);
        return EXIT_FAILURE;
    }
    static char msg[MAX_MSG + 1];
    int nro = 0, c;

    while ((c = fgetc(f)) != EOF) {
        ungetc(c, f);
        nro++;

        long long when = leer_numero(f, ' ', 15);
        char level[8];
        if (when < 0 || fscanf(f, "%7[A-Z]", level) != 1 || fgetc(f) != ' ') goto invalido;
        if (strcmp(level, "INFO") != 0 && strcmp(level, "WARNING") != 0) goto invalido;

        long long len = leer_numero(f, ':', 5);
        if (len < 0 || len > MAX_MSG) goto invalido;
        if (fread(msg, 1, (size_t) len, f) != (size_t) len) goto invalido;   /* truncado */
        if (fgetc(f) != '\n') goto invalido;
        msg[len] = '\0';

        time_t secs = (time_t) (when / 1000);
        char fecha[32];
        strftime(fecha, sizeof fecha, "%Y-%m-%d %H:%M:%S", localtime(&secs));
        printf("[%s.%03lld] %-7s %s\n", fecha, when % 1000, level, msg);
    }
    fclose(f);
    return EXIT_SUCCESS;

invalido:
    fprintf(stderr, "registro %d inválido o truncado (offset %ld)\n", nro, ftell(f));
    fclose(f);
    return EXIT_FAILURE;
}
