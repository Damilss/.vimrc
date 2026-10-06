# Same flags as compile_flags.txt, so clangd and the compiler agree.
# Override the compiler with: make CC=gcc
CC ?= cc
CFLAGS ?= -Wall -Wextra -Wpedantic -std=c17

OBJS = main.o vec.o

squares: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

main.o: main.c vec.h
vec.o: vec.c vec.h

clean:
	rm -f squares $(OBJS)

.PHONY: clean
