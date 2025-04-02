%include "header.asm"

global _start

section .text

_start:
  mov rbp, rsp
  call init

  mov rax, 1
  mov rdi, STDOUT_FILENO
  mov rsi, [file_addr]
  mov rdx, [file_len]
  syscall

  _read_loop:
    call getchar

    cmp byte [chartype], 1
    jne _read_loop_1
    mov bl, [char]
    mov rax, [file_addr]
    add rax, [file_len]
    mov byte [rax], bl
    inc qword [file_len]
    _read_loop_1:

    cmp byte [chartype], 2
    jne _read_loop_2
    mov rax, [file_addr]
    add rax, [file_len]
    mov byte [rax], NULL
    dec qword [file_len]
    
    _read_loop_2:
    mov rax, [char]
    cmp byte [char], 13
    jne _read_loop_3
    mov rax, 1
    mov rdi, STDOUT_FILENO
    mov rsi, cr
    mov rdx, cr_len
    syscall

    _read_loop_3:
    mov rax, 1
    mov rdi, STDOUT_FILENO
    mov rsi, char
    mov rdx, 1
    syscall

    _read_loop_4:
    jmp _read_loop
  
  _exit:
  mov rax, 9 ; mmap
  mov rdi, NULL ; let kernel decide address
  mov rsi, 144 ; enough size for stat (144)
  mov rdx, PROT_READ | PROT_WRITE ; allow us to read and write to this memory
  mov r10, MAP_ANONYMOUS | MAP_PRIVATE ; don't map a file to memory, keep changes to (nonexistant) file private
  mov r8, -1 ; -1 as fd because of MAP_ANONYMOUS
  mov r9, 0 ; 0 offset
  syscall

  mov r8, rax

  ; get file size (stat)
  mov rax, 5
  mov rdi, [fd]
  mov rsi, r8
  syscall

  ; delete file
  mov rax, 87
  mov rdi, [rbp+16]
  syscall

  ; create file
  mov rax, 2
  mov rdi, [rbp+16]
  mov rsi, O_CREAT | O_RDWR
  mov rdx, S_IRGRP | S_IROTH | S_IRUSR | S_IWUSR
  syscall

  mov rdi, rax
  mov rax, 1
  mov rsi, [file_addr]
  mov rdx, [file_len]
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

  mov rax, 11 ; munmap
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

  mov rax, 9 ; mmap
  mov rdi, NULL ; let kernel decide address
  mov rsi, 144 ; enough size for stat (144)
  mov rdx, PROT_READ | PROT_WRITE ; allow us to read and write to this memory
  mov r10, MAP_ANONYMOUS | MAP_PRIVATE ; don't map a file to memory, keep changes to (nonexistant) file private
  mov r8, -1 ; -1 as fd because of MAP_ANONYMOUS
  mov r9, 0 ; 0 offset
  syscall

  mov r8, rax

  ; get file size (stat)
  mov rsi, rax
  mov rax, 5
  mov rdi, [fd]
  syscall

  mov rax, [r8+48]
  mov [file_len], rax
  cmp rax, 17
  jge _init_1
  mov rax, 16
  jmp _init_2
  _init_1:
  mov [file_len], rax
  _init_2:
  mov rdi, 3
  mul rdi
  mov rdi, 2
  div rdi
  mov [reserved_space], rax
  mov r9, rax

  mov rax, 9 ; mmap
  mov rdi, NULL ; let kernel decide address
  mov rsi, r9 ; enough size for our file (1.5x file size)
  mov rdx, PROT_READ | PROT_WRITE ; allow us to read and write to this memory
  mov r10, MAP_PRIVATE | MAP_ANONYMOUS ; keep changes to file private (lets us resize file and we save manually anyway)
  mov r8, -1
  mov r9, 0 ; 0 offset
  syscall

  mov [file_addr], rax

  cmp qword [file_len], 0
  je _init_3

  mov rax, 9 ; mmap
  mov rdi, NULL ; let kernel decide address
  mov rsi, [file_len] ; enough size for our file
  mov rdx, PROT_READ | PROT_WRITE ; allow us to read and write to this memory
  mov r10, MAP_PRIVATE ; keep changes to file private (lets us resize file and we save manually anyway)
  mov r8, [fd]
  mov r9, 0 ; 0 offset
  syscall

  push qword [file_addr]
  push qword rax
  push qword [file_len]
  call memcpy

  mov rax, 11 ; munmap
  pop rsi
  pop rdi
  add rsp, 8
  syscall

  _init_3:
  mov rax, 11 ; munmap
  mov rdi, r8
  mov rsi, 144

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

getchar:
  push rbp
  mov rbp, rsp

  mov byte [chartype], 1
  
  mov rax, 0
  mov rdi, STDIN_FILENO
  mov rsi, char
  mov rdx, 1
  syscall

  cmp byte [char], 127
  jne _getchar_1
  mov byte [chartype], 2
  mov rax, 1
  mov rdi, STDOUT_FILENO
  mov rsi, backspace
  mov rdx, backspacelen
  syscall
  jmp _getchar_ret
  _getchar_1:
  cmp byte [char], 27
  jne _getchar_ret
  mov rax, 0
  mov rdi, STDIN_FILENO
  mov rsi, char
  mov rdx, 1
  syscall
  cmp byte [char], '['
  jne _getchar_ret
  mov rax, 0
  mov rdi, STDIN_FILENO
  mov rsi, char
  mov rdx, 1
  syscall
  cmp byte [char], '1'
  jne _getchar_ret
  mov rax, 0
  mov rdi, STDIN_FILENO
  mov rsi, char
  mov rdx, 1
  syscall
  cmp byte [char], 'C'
  jne _getchar_forward_check

  mov rax, 1
  mov rdi, STDOUT_FILENO
  mov rsi, forward
  mov rdx, forward_len
  syscall
  mov byte [chartype], 0
  jmp _getchar_ret

  _getchar_forward_check:
  cmp byte [char], 'D'
  jne _getchar_ret

  mov rax, 1
  mov rdi, STDOUT_FILENO
  mov rsi, backward
  mov rdx, backward_len
  syscall
  mov byte [chartype], 0

  _getchar_ret:
  pop rbp
  ret

section .rodata
  backspace: db 8, ' ', 8
  backspacelen: equ $ - backspace
  clear_screen: db 27, "[3J", 27, "[2J", 27, "[H"
  clear_screen_len: equ $ - clear_screen
  enter_alt_screen_mode: db 27, "[?1049h"
  enter_alt_screen_mode_len: equ $ - enter_alt_screen_mode
  exit_alt_screen_mode: db 27, "[?1049l"
  exit_alt_screen_mode_len: equ $ - exit_alt_screen_mode
  forward: db 27, "[C"
  forward_len: equ $ - forward
  backward: db 27, "[D"
  backward_len: equ $ - backward
  cr: db 13, 10
  cr_len: equ $ - cr

section .bss
  termio: resb 60
  char: resb 1
  fd: resq 1
  file_addr: resq 1
  file_len: resq 1
  chartype: resb 1
  reserved_space: resq 1