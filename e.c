#include<stdio.h>
#include<termios.h>
#include<unistd.h>

int main() {
	printf("%d", sizeof(struct termios));
}
