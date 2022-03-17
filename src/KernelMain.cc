extern "C" long kernel_main(void* args);

long sum(long a, long b, long c, long d){
	long e = a + b + c;
	return e;
}

long kernel_main(void* args){
	long tmp = (long) args;
	long a = 42;
	long b = 4711;
	long c = a + b;
	return sum(a, b, c, tmp);
}
