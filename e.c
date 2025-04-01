#include<stdio.h>
#include<termios.h>
#include<unistd.h>
#include<sys/stat.h>

int main() {
	printf("%ld\n", sizeof(unsigned int)*4 + sizeof(unsigned long)*4);
	printf("%ld\n", sizeof(long));
}
