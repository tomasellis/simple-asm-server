.intel_syntax noprefix
.global _start

_start:

#socket call, rdi:domain, rsi:type, rdx:protocol
mov rdi, 2
mov rsi, 1
mov rdx, 0
mov rax, 41
syscall

#assign the socket a network identity, bind to connect to ip
#rax has fd for init socket
#rdi:sockfd rsi:sockaddr * rdx:socklen_t
mov rdi, rax

#prepare stack
mov rbp, rsp
sub rsp, 16

#fill stack
mov WORD PTR [rsp], 2 #sa_family
mov WORD PTR [rsp + 2], 0x5000 #port
mov DWORD PTR [rsp + 4], 0x00000000 #address

#bind to address and port
mov rsi, rsp
mov rdx, 16
mov rax, 49
syscall

#clean address stack
mov rsp, rbp

#listen to connections rdi, rsi
mov rsi, 0
mov rax, 50
syscall

#accept conn
mov rsi, 0
mov rdx, 0
mov rax, 43
syscall


#save single connection fd
xor r15, r15
mov r15, rax

#read request
mov rdi, rax

#prepare 2KB of arbitrary space for request
sub rsp, 2048

mov rsi, rsp
mov rdx, 2048
mov rax, 0
syscall

mov rdi, rsp #pointer to text
mov rsi, rax #length
mov rdx, 0x20 #char to search
call get_bytes_between_char
#rax has pointer to strings
#rdx has count

add rsp, 2048

#open file that is asked for in http req
mov rdi, rax
mov rsi, 0
mov rax, 2
syscall

xor r14, r14
mov r14, rax

#rax has fd

#2048 mem for read
mov rdi, 0
mov rsi, 2048
mov rdx, 3
mov r10, 34
mov r8, -1
mov r9, 0
mov rax, 9
syscall

mov r8, rax

# actual read
mov rdi, r14
mov rsi, rax
mov rdx, 2048
mov rax, 0
syscall

mov r9, rax

mov rdi, r14
mov rax, 3
syscall



sub rsp, 19

#save "HTTP\1.0 200 OK\r\n\r\n" to stack
mov rax, 0x302e312f50545448
mov [rsp], rax
mov rax, 0x0d4b4f2030303220
mov [rsp+8], rax
mov eax, 0x0a0d0a
mov [rsp+16], eax

#rdi has initial fd
mov rdi, r15
mov rsi, rsp
mov rdx, 19
mov rax, 1
syscall

add rsp, 19


# send to fd 
mov rsi, r8
mov rdi, r15
mov rdx, r9
mov rax, 1
syscall


add rsp, 2048

#cleanup of http ok
mov rsp, rbp








#close fd
mov rax, 3
syscall

#exit
mov rdi, 0
mov rax, 60
syscall

get_bytes_between_char:
    push rbp
    mov rbp, rsp

    push rdi
    push rsi
    push r10
    push r8
    push r9
    push rbx
    push rcx

    xor r10, r10  # index
    mov r9, -1    # store first occurrence index (-1 means not found)

FIRST_CHAR_LOOP:
    cmp r10, rsi
    jge END       # index >= length, quit
    mov al, [rdi + r10]
    cmp al, dl
    jne CONTINUE_FIRST
    mov r9, r10   # store first occurrence index
    jmp SECOND_CHAR_LOOP

CONTINUE_FIRST:
    add r10, 1
    jmp FIRST_CHAR_LOOP

SECOND_CHAR_LOOP:
    add r10, 1
    cmp r10, rsi
    jge END       # index >= length, quit
    mov al, [rdi + r10]
    cmp al, dl
    jne SECOND_CHAR_LOOP

    sub r10, r9  # length between chars
    jle END      # invalid length, exit

    # align stack for syscall
    push r9
    push r10
    push rdi
    sub rsp, 8   # align

    # mmap allocation
    mov rdi, 0
    mov rsi, r10  # size in bytes
    mov rdx, 3    
    mov r10, 34   
    mov r8, -1    
    mov r9, 0     
    mov rax, 9    
    syscall

    add rsp, 8   # align
    pop rdi       # poitner to og string
    pop r10       # length of cut strin
    pop r9        # start of se4rach strin

    test rax, rax
    js END        # mmap failed, exit

    mov rsi, rax  # allocated memory
    mov rdx, 0    # index in allocated mem

    add r9, 1     # ignore first char
    sub r10, 1    # ignore last char
    lea rbx, [rdi + r9]
WRITE_TO_MEMORY:
    cmp rdx, r10
    jge END_COPY
    mov al, [rbx + rdx]
    mov [rsi + rdx], al

    add rdx, 1
    jmp WRITE_TO_MEMORY

END_COPY:
    mov rax, rsi  # return pointer
    mov rdx, r10

END:
    pop rcx
    pop rbx
    pop r9
    pop r8
    pop r10
    pop rsi
    pop rdi
    pop rbp
    ret
