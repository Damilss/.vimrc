#include <stdio.h>

#include "vec.h"

int main(void)
{
	struct vec numbers = {0};

	for (int i = 1; i <= 10; i++) {
		if (vec_push(&numbers, i * i) != 0) {
			fprintf(stderr, "out of memory\n");
			vec_free(&numbers);
			return 1;
		}
	}

	printf("%zu squares, sum %ld\n", numbers.len, vec_sum(&numbers));
	vec_free(&numbers);
	return 0;
}
