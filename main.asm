%include "header.asm"

global _start

section .text

_start:
  call init

  mov rax, 1
  mov rdi, STDOUT_FILENO
  mov rsi, msg
  mov rdx, msglen
  syscall

  _read_loop:
    mov rax, 0
    mov rdi, STDIN_FILENO
    mov rsi, char
    mov rdx, 1
    syscall

    mov rax, 1
    mov rdi, STDOUT_FILENO
    mov rsi, backspace
    mov rdx, backspacelen
    syscall

    mov rax, 1
    mov rdi, STDOUT_FILENO
    mov rsi, char
    mov rdx, 1
    syscall

    cmp byte [char], 'q'
    jne _read_loop

  mov rax, 1
  mov rdi, STDOUT_FILENO
  mov rsi, backspace
  mov rdx, backspacelen
  syscall
  
  call exit

init: ; save term settings and enter raw mode
  push rbp 
  mov rbp, rsp

  mov rax, 16
  mov rdi, STDIN_FILENO
  mov rsi, TCGETS
  mov rdx, termio
  syscall ; save termio


  mov rax, 9 ; mmap
  mov rdi, NULL ; let kernel decide address
  mov rsi, 60 ; enough size for termios (60)
  mov rdx, PROT_READ | PROT_WRITE ; allow us to read and write to this memory
  mov r10, MAP_ANONYMOUS | MAP_PRIVATE ; don't map a file to memory, keep changes to (nonexistant) file private
  mov r8, -1 ; -1 as fd because of MAP_ANONYMOUS
  mov r9, 0 ; 0 offset
  syscall

  push rax
  push termio
  push 60
  call memcpy
  add rsp, 16
  pop rax

  ; enter raw mode
  and word [rax], ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON) ; termios.c_iflag
  and word [rax+4], ~OPOST ; termios.c_oflag
  and word [rax+12], ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN) ; termios.c_lflag
  and word [rax+8], ~(CSIZE | PARENB) ; termios.c_cflag
  or word [rax+8], CS8 ; termios.c_cflag

  mov rdx, rax
  mov rax, 16
  mov rdi, STDIN_FILENO
  mov rsi, TCSETS
  syscall ; new termio

  mov rax, 11
  mov rdi, rdx
  mov rsi, 60
  syscall

  mov rax, 1
  mov rdi, STDOUT_FILENO
  mov rsi, enter_alt_screen_mode
  mov rdx, enter_alt_screen_mode_len
  syscall

  mov rax, 1
  mov rdi, STDOUT_FILENO
  mov rsi, clear_screen
  mov rdx, clear_screen_len
  syscall

  ; create/open file
  cmp byte [rbp+32], NULL
  je exit
  mov rax, 2
  mov rdi, [rbp+32] ; [rbp+32] = first argument
  mov rsi, O_CREAT | O_RDWR
  mov rdx, S_IRGRP | S_IROTH | S_IRUSR | S_IWUSR
  syscall

  mov [fd], rax

  pop rbp
  ret
  
exit: ; restore term settings and exit
  mov rax, 1
  mov rdi, STDOUT_FILENO
  mov rsi, exit_alt_screen_mode
  mov rdx, exit_alt_screen_mode_len
  syscall

  mov rax, 16
  mov rdi, STDIN_FILENO
  mov rsi, TCSETS
  mov rdx, termio
  syscall
  
  mov rax, 60       ; exit(
  mov rdi, 0        ;   EXIT_SUCCESS
  syscall           ; );

memcpy:
  push rbp 
  mov rbp, rsp
  mov rax, [rbp+16] ; length
  mov rdi, [rbp+24] ; source
  mov rsi, [rbp+32] ; dest
  _memcpy_loop:
    mov rdx, [rdi+rax]
    mov [rsi+rax], rdx
    dec rax
    cmp rax, -1
    jne _memcpy_loop
  mov rsp, rbp
  pop rbp
  ret

section .rodata
  msg: db "Press q to exit", 13, 10
  msglen: equ $ - msg
  backspace: db 8, ' ', 8
  backspacelen: equ $ - backspace
  clear_screen: db 27, "[3J", 27, "[2J", 27, "[H"
  clear_screen_len: equ $ - clear_screen
  enter_alt_screen_mode: db 27, "[?1049h"
  enter_alt_screen_mode_len: equ $ - enter_alt_screen_mode
  exit_alt_screen_mode: db 27, "[?1049l"
  exit_alt_screen_mode_len: equ $ - exit_alt_screen_mode

section .bss
  termio: resb 60
  char: resb 1
  fd: resq 1
  file_addr: resq 1