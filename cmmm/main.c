#include <unistd.h>
#include <stdlib.h>

int main() {
  const char msg[] = "Hello, ARM!\n";
  write(0, msg, sizeof(msg));
  asm("DMB nshld");
  write(0, msg, sizeof(msg));
  asm("DMB OSHST");
  asm("DMB OSHLD");
  asm("DMB nshld");
  asm("DMB sy");
  asm("DMB st");
  asm("DMB ld");
  exit(0);
}
