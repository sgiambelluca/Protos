/*
 * copy.c - Guía 1, E2
 *
 * Copia <origen> en <destino> usando un buffer de <tam> bytes:
 *   tam  > 0 : bucle read(2)/write(2) en espacio de usuario
 *   tam == 0 : sendfile(2), la copia la hace el kernel sin pasar por el usuario
 *
 * Compilar:  make            (o: gcc -O2 -Wall -o copy copy.c)
 * Uso:       ./copy archivo-in archivo-out 4096
 * Medir:     ./medir.sh      (corre todos los tamaños del enunciado con time)
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/sendfile.h>
#include <sys/stat.h>
#include <unistd.h>

static void die(const char *msg) {
    perror(msg);
    exit(EXIT_FAILURE);
}

/* write(2) puede escribir MENOS bytes de los pedidos: hay que reintentar. */
static void write_all(int fd, const char *buf, size_t n) {
    while (n > 0) {
        ssize_t w = write(fd, buf, n);
        if (w < 0) {
            if (errno == EINTR) continue;
            die("write");
        }
        buf += w;
        n -= (size_t) w;
    }
}

static void copy_rw(int in, int out, size_t tam) {
    char *buf = malloc(tam);
    if (buf == NULL) die("malloc");
    ssize_t r;
    /* Cada vuelta = 2 syscalls (read + write). Con tam = 1 y 100 MB son
     * ~200 millones de syscalls: por eso es tan lento (tiempo de "sys"). */
    while ((r = read(in, buf, tam)) != 0) {
        if (r < 0) {
            if (errno == EINTR) continue;
            die("read");
        }
        write_all(out, buf, (size_t) r);
    }
    free(buf);
}

static void copy_sendfile(int in, int out) {
    struct stat st;
    if (fstat(in, &st) < 0) die("fstat");
    off_t off = 0;
    /* sendfile copia de un fd a otro DENTRO del kernel (zero-copy):
     * no hay copias kernel -> usuario -> kernel ni cambios de contexto por bloque. */
    while (off < st.st_size) {
        ssize_t s = sendfile(out, in, &off, (size_t) (st.st_size - off));
        if (s < 0) {
            if (errno == EINTR) continue;
            die("sendfile");
        }
        if (s == 0) break;
    }
}

int main(int argc, char *argv[]) {
    if (argc != 4) {
        fprintf(stderr, "uso: %s <origen> <destino> <tam_buffer (0 = sendfile)>\n", argv[0]);
        return EXIT_FAILURE;
    }
    char *end;
    long tam = strtol(argv[3], &end, 10);
    if (*end != '\0' || tam < 0) {
        fprintf(stderr, "tam_buffer inválido: %s\n", argv[3]);
        return EXIT_FAILURE;
    }

    int in = open(argv[1], O_RDONLY);
    if (in < 0) die(argv[1]);
    int out = open(argv[2], O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (out < 0) die(argv[2]);

    if (tam == 0)
        copy_sendfile(in, out);
    else
        copy_rw(in, out, (size_t) tam);

    close(in);
    close(out);
    return EXIT_SUCCESS;
}
