#include "vec.h"

#include <stdlib.h>

int vec_push(struct vec *v, int value)
{
	if (v->len == v->cap) {
		size_t new_cap = v->cap ? v->cap * 2 : 4;
		int *new_data = realloc(v->data, new_cap * sizeof *new_data);

		if (new_data == NULL)
			return -1;
		v->data = new_data;
		v->cap = new_cap;
	}
	v->data[v->len++] = value;
	return 0;
}

long vec_sum(const struct vec *v)
{
	long total = 0;

	for (size_t i = 0; i < v->len; i++)
		total += v->data[i];
	return total;
}

void vec_free(struct vec *v)
{
	free(v->data);
	v->data = NULL;
	v->len = 0;
	v->cap = 0;
}
