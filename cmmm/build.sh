as -o hell.o hello.s

gcc main.c
gcc -S main.c
objdump -S --disassemble a.out > a.dump