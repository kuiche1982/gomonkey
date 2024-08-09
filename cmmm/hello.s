.data

/* Data segment: define our message string and calculate its length. */
msg:
    .ascii        "Hello, ARM64!\n"
len = . - msg

.text

/* Our application's entry point. */
.globl _main
_main:
    /* syscall write(int fd, const void *buf, size_t count) */
    mov     x0, #1      /* fd := STDOUT_FILENO */
    ldr     x1, =msg    /* buf := msg */
    ldr     x2, =len    /* count := len */
    mov     w8, #64     /* write is syscall #64 */
    svc     #0          /* invoke syscall */
    LDR X0, [X3]
    DMB nshld 
    LDNP X2, X1, [X0] 
    /* syscall exit(int status) */
    mov     x0, #0      /* status := 0 */
    mov     w8, #93     /* exit is syscall #93 */
    svc     #0          /* invoke syscall */
    