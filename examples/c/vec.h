#ifndef VEC_H
#define VEC_H

#include <stddef.h>

/* A growable array of ints.  Zero-initialize it before first use:
 *     struct vec v = {0};
 */
struct vec {
	int *data;
	size_t len;
	size_t cap;
};

/* Appends value, growing the array as needed.  Returns 0 on success and -1
 * if memory could not be allocated (v is unchanged in that case). */
int vec_push(struct vec *v, int value);

/* Returns the sum of all elements. */
long vec_sum(const struct vec *v);

/* Releases the array and resets v to empty. */
void vec_free(struct vec *v);

#endif
