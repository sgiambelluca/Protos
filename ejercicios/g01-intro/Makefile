CFLAGS = -O2 -Wall -Wextra -std=c11

all: copy logwrite logread

copy: copy.c
	$(CC) $(CFLAGS) -o $@ $<

logwrite: logwrite.c
	$(CC) $(CFLAGS) -o $@ $<

logread: logread.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f copy logwrite logread mensajes.log

.PHONY: all clean
