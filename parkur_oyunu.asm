; ============================================================
;    DINOZOR OYUNU v11 
;    Kontroller: SPACE=Zipla | S=Egil | P=Dur/Dev | R=Tekrar | ESC=Cikis
; ============================================================

.model small
.stack 200h

.data
    dino_row    db 20
    jump_state  db 0
    jump_count  db 0
    is_ducking  db 0        ; 1 ise dinozor egiliyor
    dino_frame  db 0        ; 0=sol ayak, 1=sag ayak

    NUM_CACTI   EQU 3
    cact_cols   db 59, 39, 19

    bird_col    db 0        ; Kus sutunu (0 ise pasif)
    bird_timer  db 0
    bird_spawn  db 50       ; Dinamik kus spawn esigi

    cloud1_col  db 40
    cloud2_col  db 10
    cloud_timer db 0

    ; [YENÝ] Yildiz arka plani - 4 yildiz, farkli satirlarda
    star1_col   db 55
    star2_col   db 30
    star3_col   db 15
    star4_col   db 45
    star_timer  db 0        ; 8 karede 1 adim kayar

    score       dw 0
    high_score  dw 0
    over        db 0
    paused      db 0        ; 1 ise oyun duraklatildi

    game_speed  dw 15000
    speed_init  dw 15000    ; Secilen baslangic hizi

    ; Arayuz Mesajlari
    msg_title1  db 'PLATFORM$'
    msg_title2  db 'OYUNU$'
    msg_ctrl1   db 'SPC=Zipla$'
    msg_ctrl2   db 'S=Egil$'
    msg_ctrl3   db 'R=Tekrar$'
    msg_ctrl4   db 'ESC=Cik$'
    msg_ctrl5   db 'P=Dur/Dev$' 
    msg_over    db 'OYUN BITTI!$'
    msg_score   db 'SKOR: $'
    msg_hi      db 'HI  : $'
    msg_blank   db '     $'
    msg_pause   db '** DURAKLATILDI **$'

    ; Zorluk menusu mesajlari
    msg_diff    db '=== ZORLUK SECIN ===   $'
    msg_easy    db '  [1] KOLAY   (yavas)  $'
    msg_normal  db '  [2] NORMAL  (orta)   $'
    msg_hard    db '  [3] ZOR     (hizli)  $'

    DINO_COL    EQU 10
    GND_ROW     EQU 20
    JUMP_MAX    EQU 4

.code
prog_start:
    mov ax, @data
    mov ds, ax

    mov ax, 0003h
    int 10h
    mov ah, 01h
    mov cx, 2020h
    int 10h

    call show_difficulty_menu   ; Bir kez, baslangicta

new_game:
    call stop_sound
    mov byte ptr [dino_row],   GND_ROW
    mov byte ptr [jump_state], 0
    mov byte ptr [jump_count], 0
    mov byte ptr [is_ducking], 0
    mov byte ptr [dino_frame], 0  
    mov byte ptr [bird_col],   0
    mov byte ptr [bird_timer], 0
    mov byte ptr [paused],     0 

    ;Baslangic kus spawn esigini rastgelele
    call get_random
    and al, 0Fh
    add al, 35              ; 35-50 arasi
    mov [bird_spawn], al

    ;Secilen hizi yukle
    mov ax, [speed_init]
    mov [game_speed], ax

    mov byte ptr cact_cols[0], 59
    mov byte ptr cact_cols[1], 39
    mov byte ptr cact_cols[2], 19

    mov word ptr [score], 0
    mov byte ptr [over],  0

    mov ax, 0600h
    mov bh, 07h
    mov cx, 0000h
    mov dx, 184Fh
    int 10h

    call draw_ui_panel
    call draw_ground
    call show_score

; ============================================================
; ANA DONGU
; ============================================================
main_loop:
    ; Duraklama kontrolu
    cmp byte ptr [paused], 1
    je pause_loop

    mov byte ptr [is_ducking], 0

; --- Klavye tamponu oku ---
flush_kbd:
    mov ah, 01h
    int 16h
    jz update_logic

    mov ah, 00h
    int 16h

    cmp al, 1Bh
    je do_exit

    ; P tusu - duraklat / devam et
    cmp al, 'p'
    je toggle_pause
    cmp al, 'P'
    je toggle_pause

    cmp byte ptr [over], 1
    je check_restart

    ; SPACE - Zipla
    cmp al, 20h
    je try_jump

    ; S / Asagi ok - Egil
    cmp al, 's'
    je do_duck
    cmp al, 'S'
    je do_duck
    cmp ah, 50h
    je do_duck

    jmp flush_kbd

;   Duraklat / Devam et toggler
toggle_pause:
    xor byte ptr [paused], 1
    cmp byte ptr [paused], 1
    jne clr_pause_msg
    ; Mesaji goster
    mov dh, 11
    mov dl, 18
    call set_cursor
    mov dx, offset msg_pause
    mov ah, 09h
    int 21h
    jmp flush_kbd
clr_pause_msg:
    ; Mesaji temizle
    mov dh, 11
    mov dl, 18
    call set_cursor
    mov ah, 09h
    mov al, ' '
    mov bl, 07h
    mov cx, 20
    int 10h
    jmp flush_kbd

; Duraklatilmis - sadece P veya ESC bekle
pause_loop:
    mov ah, 01h
    int 16h
    jz pause_loop
    mov ah, 00h
    int 16h
    cmp al, 'p'
    je do_unpause
    cmp al, 'P'
    je do_unpause
    cmp al, 1Bh
    je do_exit
    jmp pause_loop
do_unpause:
    mov byte ptr [paused], 0
    ; Mesaji temizle
    mov dh, 11
    mov dl, 18
    call set_cursor
    mov ah, 09h
    mov al, ' '
    mov bl, 07h
    mov cx, 20
    int 10h
    jmp main_loop

try_jump:
    cmp byte ptr [jump_state], 0
    jne flush_kbd
    mov byte ptr [jump_state], 1
    call play_jump_sound
    jmp flush_kbd

do_duck:
    cmp byte ptr [jump_state], 0
    jne flush_kbd
    mov byte ptr [is_ducking], 1
    jmp flush_kbd

check_restart:
    cmp al, 'r'
    je new_game
    cmp al, 'R'
    je new_game
    jmp main_loop

; --- Oyun mantigi ---
update_logic:
    cmp byte ptr [over], 1
    je main_loop

    call hide_dino
    call hide_cactus
    call hide_bird
    call hide_clouds
    call hide_stars         

    call update_dino
    call update_cactus
    call update_bird
    call update_clouds
    call update_stars       

    call show_dino
    call show_cactus
    call show_bird
    call show_clouds
    call show_stars         

    call check_collision

    cmp byte ptr [over], 1
    jne continue_game
    call handle_game_over
    jmp main_loop

continue_game:
    mov cx, NUM_CACTI
    mov bx, offset cact_cols
check_pass_loop:
    mov al, [bx]
    cmp al, DINO_COL - 1
    jne cpp_next
    call add_score
cpp_next:
    inc bx
    loop check_pass_loop

    mov al, [bird_col]
    cmp al, DINO_COL - 1
    jne finish_logic
    call add_score

finish_logic:
    call game_delay
    jmp main_loop

; ============================================================
; ZORLUK SECIM MENUSU
; ============================================================
show_difficulty_menu proc
    mov ax, 0600h
    mov bh, 07h
    mov cx, 0000h
    mov dx, 184Fh
    int 10h

    mov dh, 9
    mov dl, 29
    call set_cursor
    mov dx, offset msg_diff
    mov ah, 09h
    int 21h

    mov dh, 11
    mov dl, 29
    call set_cursor
    mov dx, offset msg_easy
    mov ah, 09h
    int 21h

    mov dh, 12
    mov dl, 29
    call set_cursor
    mov dx, offset msg_normal
    mov ah, 09h
    int 21h

    mov dh, 13
    mov dl, 29
    call set_cursor
    mov dx, offset msg_hard
    mov ah, 09h
    int 21h

diff_wait:
    mov ah, 00h
    int 16h
    cmp al, '1'
    je set_easy
    cmp al, '2'
    je set_normal
    cmp al, '3'
    je set_hard
    jmp diff_wait

set_easy:
    mov word ptr [speed_init], 22000    ; Yavas
    ret
set_normal:
    mov word ptr [speed_init], 15000    ; Orta
    ret
set_hard:
    mov word ptr [speed_init], 7000     ; Hizli
    ret
show_difficulty_menu endp

; ============================================================
; BIOS SAYACINDAN RASTGELE SAYI (Sonuc AL'de)
; ============================================================
get_random proc
    push cx
    push dx
    mov ah, 00h
    int 1Ah             ; CX:DX = BIOS saat sayaci (18.2 Hz)
    mov al, dl          ; Dusuk byte al
    xor al, dh          ; Yuksek byte ile karistir
    pop dx
    pop cx
    ret
get_random endp

; ============================================================
; ALT RUTINLER
; ============================================================
do_exit:
    call stop_sound
    mov ax, 0003h
    int 10h
    mov ax, 4C00h
    int 21h

handle_game_over proc
    call play_crash_sound
    mov byte ptr [over], 1

    mov ax, [score]
    cmp ax, [high_score]
    jle gov_print
    mov [high_score], ax
    call show_high_score

gov_print:
    mov ah, 02h
    mov bh, 0
    mov dh, 14
    mov dl, 64
    int 10h
    mov dx, offset msg_over
    mov ah, 09h
    int 21h
    ret
handle_game_over endp

add_score proc
    inc word ptr [score]
    call show_score
    mov ax, [game_speed]
    cmp ax, 1000
    jle skip_speedup
    sub ax, 200
    mov [game_speed], ax
skip_speedup:
    ; [YENÝ] Her puanda kus esigini rastgelele
    call get_random
    and al, 0Fh
    add al, 35
    mov [bird_spawn], al
    ret
add_score endp

; ============================================================
; KUS (Rastgele spawn esikli)
; ============================================================
update_bird proc
    cmp byte ptr [bird_col], 0
    je spawn_bird_chk
    dec byte ptr [bird_col]
    ret

spawn_bird_chk:
    inc byte ptr [bird_timer]
    mov al, [bird_timer]
    cmp al, [bird_spawn]    ; Dinamik esik
    jne ubird_done
    mov byte ptr [bird_timer], 0
    ; Yeni spawn esigi
    call get_random
    and al, 0Fh
    add al, 35
    mov [bird_spawn], al
    mov byte ptr [bird_col], 59
ubird_done:
    ret
update_bird endp

show_bird proc
    cmp byte ptr [bird_col], 0
    je sbird_done
    mov dh, GND_ROW - 2
    mov dl, [bird_col]
    call set_cursor
    mov al, 'V'
    mov bl, 0Eh
    mov cx, 1
    mov ah, 09h
    int 10h
sbird_done:
    ret
show_bird endp

hide_bird proc
    cmp byte ptr [bird_col], 0
    je hbird_done
    mov dh, GND_ROW - 2
    mov dl, [bird_col]
    call set_cursor
    mov al, ' '
    mov bl, 07h
    mov cx, 2
    mov ah, 09h
    int 10h
hbird_done:
    ret
hide_bird endp

; ============================================================
; BULUTLAR
; ============================================================
update_clouds proc
    inc byte ptr [cloud_timer]
    cmp byte ptr [cloud_timer], 3
    jl ucloud_done
    mov byte ptr [cloud_timer], 0

    dec byte ptr [cloud1_col]
    cmp byte ptr [cloud1_col], 0
    jg cloud_chk2
    mov byte ptr [cloud1_col], 58
cloud_chk2:
    dec byte ptr [cloud2_col]
    cmp byte ptr [cloud2_col], 0
    jg ucloud_done
    mov byte ptr [cloud2_col], 58
ucloud_done:
    ret
update_clouds endp

show_clouds proc
    mov bl, 0Fh
    mov cx, 3
    mov al, '~'

    mov dh, 4
    mov dl, [cloud1_col]
    call set_cursor
    mov ah, 09h
    int 10h

    mov dh, 6
    mov dl, [cloud2_col]
    call set_cursor
    mov ah, 09h
    int 10h
    ret
show_clouds endp

hide_clouds proc
    mov bl, 07h
    mov cx, 4
    mov al, ' '

    mov dh, 4
    mov dl, [cloud1_col]
    call set_cursor
    mov ah, 09h
    int 10h

    mov dh, 6
    mov dl, [cloud2_col]
    call set_cursor
    mov ah, 09h
    int 10h
    ret
hide_clouds endp

; ============================================================
; YILDIZ ARKA PLANI
;   4 yildiz, farkli satirlarda, 8 karede 1 adim sola kayar
; ============================================================
update_stars proc
    inc byte ptr [star_timer]
    cmp byte ptr [star_timer], 8
    jl ustar_done
    mov byte ptr [star_timer], 0

    dec byte ptr [star1_col]
    cmp byte ptr [star1_col], 0
    jg ustar_s2
    mov byte ptr [star1_col], 57
ustar_s2:
    dec byte ptr [star2_col]
    cmp byte ptr [star2_col], 0
    jg ustar_s3
    mov byte ptr [star2_col], 57
ustar_s3:
    dec byte ptr [star3_col]
    cmp byte ptr [star3_col], 0
    jg ustar_s4
    mov byte ptr [star3_col], 57
ustar_s4:
    dec byte ptr [star4_col]
    cmp byte ptr [star4_col], 0
    jg ustar_done
    mov byte ptr [star4_col], 57
ustar_done:
    ret
update_stars endp

show_stars proc
    mov bl, 08h         ; Koyu gri
    mov al, '*'
    mov cx, 1

    mov dh, 1
    mov dl, [star1_col]
    call set_cursor
    mov ah, 09h
    int 10h

    mov dh, 2
    mov dl, [star2_col]
    call set_cursor
    mov ah, 09h
    int 10h

    mov dh, 3
    mov dl, [star3_col]
    call set_cursor
    mov ah, 09h
    int 10h

    mov dh, 5
    mov dl, [star4_col]
    call set_cursor
    mov ah, 09h
    int 10h
    ret
show_stars endp

hide_stars proc
    mov bl, 07h
    mov al, ' '
    mov cx, 1

    mov dh, 1
    mov dl, [star1_col]
    call set_cursor
    mov ah, 09h
    int 10h

    mov dh, 2
    mov dl, [star2_col]
    call set_cursor
    mov ah, 09h
    int 10h

    mov dh, 3
    mov dl, [star3_col]
    call set_cursor
    mov ah, 09h
    int 10h

    mov dh, 5
    mov dl, [star4_col]
    call set_cursor
    mov ah, 09h
    int 10h
    ret
hide_stars endp

; ============================================================
; ANÝMASYONLU DÝNOZOR
; Ayaktayken alt govde 0DBh / 0DCh arasinda degisir (adim)
; Egilirken sadece alt govde, animasyonsuz cizilir
; ============================================================
show_dino proc
    cmp byte ptr [is_ducking], 1
    je dino_duck_only

    ; Ayakta / Ziplayan: ust govde
    mov dh, [dino_row]
    dec dh
    mov dl, DINO_COL
    call set_cursor
    mov al, 0DFh
    mov bl, 0Ah
    mov cx, 2
    mov ah, 09h
    int 10h

    ; Alt govde - animasyonlu adim
    mov dh, [dino_row]
    mov dl, DINO_COL
    call set_cursor
    cmp byte ptr [dino_frame], 0
    je dino_frame0
    mov al, 0DCh        ; Sag ayak (alt yari blok)
    jmp dino_draw_body
dino_frame0:
    mov al, 0DBh        ; Sol ayak (tam blok)
dino_draw_body:
    mov bl, 0Ah
    mov cx, 2
    mov ah, 09h
    int 10h
    xor byte ptr [dino_frame], 1    ; Sonraki kare icin gec
    ret

dino_duck_only:
    ; Egik: sadece alt govde, animasyonsuz
    mov dh, [dino_row]
    mov dl, DINO_COL
    call set_cursor
    mov al, 0DBh
    mov bl, 0Ah
    mov cx, 2
    mov ah, 09h
    int 10h
    ret
show_dino endp

; ============================================================
; CARPISMA KONTROLU 
; ============================================================
check_collision proc
    mov cx, NUM_CACTI
    mov bx, offset cact_cols
cc_loop:
    mov al, [bx]
    cmp al, DINO_COL
    je hit_cactus_y
    cmp al, DINO_COL + 1
    je hit_cactus_y
    jmp cc_next
hit_cactus_y:
    mov al, [dino_row]
    cmp al, GND_ROW - 1
    jae do_collide
cc_next:
    inc bx
    loop cc_loop

    mov al, [bird_col]
    cmp al, DINO_COL
    je hit_bird_y
    cmp al, DINO_COL + 1
    je hit_bird_y
    ret
hit_bird_y:
    cmp byte ptr [jump_state], 0
    jne cb_jump_check
    cmp byte ptr [is_ducking], 1
    jne do_collide
    ret
cb_jump_check:
    mov al, [dino_row]
    cmp al, GND_ROW - 1
    jbe do_collide
    ret

do_collide:
    mov byte ptr [over], 1
    ret
check_collision endp

; ============================================================
; DÝNOZOR GIZLE / GUNCELLE 
; ============================================================
hide_dino proc
    mov dl, DINO_COL
    mov dh, [dino_row]
    dec dh
    call set_cursor
    mov al, ' '
    mov bl, 07h
    mov cx, 2
    mov ah, 09h
    int 10h
    mov dh, [dino_row]
    call set_cursor
    mov ah, 09h
    int 10h
    mov dh, [dino_row]
    inc dh
    cmp dh, GND_ROW + 1
    jge hd_done
    call set_cursor
    mov ah, 09h
    int 10h
hd_done:
    ret
hide_dino endp

update_dino proc
    cmp byte ptr [jump_state], 0
    je ud_done
    cmp byte ptr [jump_state], 1
    jne ud_falling
    dec byte ptr [dino_row]
    inc byte ptr [jump_count]
    mov al, [jump_count]
    cmp al, JUMP_MAX
    jb ud_done
    mov byte ptr [jump_state], 2
    ret
ud_falling:
    inc byte ptr [dino_row]
    dec byte ptr [jump_count]
    jnz ud_done
    mov byte ptr [dino_row], GND_ROW
    mov byte ptr [jump_state], 0
    call stop_sound
ud_done:
    ret
update_dino endp

; ============================================================
; KAKTUS - Rastgele sifirlama pozisyonu
; ============================================================
show_cactus proc
    mov cx, NUM_CACTI
    mov bx, offset cact_cols
sc_loop:
    push cx
    push bx
    mov dl, [bx]
    mov bl, 02h
    mov dh, GND_ROW - 1
    call set_cursor
    mov ah, 09h
    mov al, 0DBh
    mov cx, 1
    int 10h
    mov dh, GND_ROW
    call set_cursor
    int 10h
    pop bx
    pop cx
    inc bx
    loop sc_loop
    ret
show_cactus endp

hide_cactus proc
    mov cx, NUM_CACTI
    mov bx, offset cact_cols
hc_loop:
    push cx
    push bx
    mov dl, [bx]
    mov bl, 07h
    mov dh, GND_ROW - 1
    call set_cursor
    mov ah, 09h
    mov al, ' '
    mov cx, 2
    int 10h
    mov dh, GND_ROW
    call set_cursor
    int 10h
    pop bx
    pop cx
    inc bx
    loop hc_loop
    ret
hide_cactus endp

update_cactus proc
    mov cx, NUM_CACTI
    mov bx, offset cact_cols
uc_loop_k:
    mov al, [bx]
    dec al
    cmp al, 0
    jg uc_save_k
    ;Rastgele sifirlama: 52-59 arasi
    call get_random
    and al, 07h         ; 0-7
    add al, 52          ; 52-59
uc_save_k:
    mov [bx], al
    inc bx
    loop uc_loop_k
    ret
update_cactus endp

; ============================================================
; UI 
; ============================================================
draw_ui_panel proc
    mov cx, 25
    mov dh, 0
draw_border_loop:
    push cx
    mov dl, 60
    call set_cursor
    mov ah, 09h
    mov al, 0B3h
    mov bl, 08h
    mov cx, 1
    int 10h
    inc dh
    pop cx
    loop draw_border_loop

    mov dh, 2
    mov dl, 65
    call set_cursor
    mov dx, offset msg_title1
    mov ah, 09h
    int 21h
    mov dh, 3
    mov dl, 66
    call set_cursor
    mov dx, offset msg_title2
    mov ah, 09h
    int 21h

    mov dh, 17
    mov dl, 64
    call set_cursor
    mov dx, offset msg_ctrl1
    mov ah, 09h
    int 21h
    mov dh, 18
    mov dl, 64
    call set_cursor
    mov dx, offset msg_ctrl2
    mov ah, 09h
    int 21h
    mov dh, 19
    mov dl, 64
    call set_cursor
    mov dx, offset msg_ctrl3
    mov ah, 09h
    int 21h
    mov dh, 20
    mov dl, 64
    call set_cursor
    mov dx, offset msg_ctrl4
    mov ah, 09h
    int 21h
    mov dh, 21
    mov dl, 64
    call set_cursor
    mov dx, offset msg_ctrl5    ; P=Dur/Dev
    mov ah, 09h
    int 21h

    mov dh, 7
    mov dl, 63
    call set_cursor
    mov dx, offset msg_hi
    mov ah, 09h
    int 21h
    call show_high_score

    mov dh, 9
    mov dl, 63
    call set_cursor
    mov dx, offset msg_score
    mov ah, 09h
    int 21h
    ret
draw_ui_panel endp

draw_ground proc
    mov ah, 02h
    mov dh, GND_ROW + 1
    mov dl, 0
    int 10h
    mov cx, 60
    mov ah, 09h
    mov al, 0DFh
    mov bl, 06h
    int 10h
    ret
draw_ground endp

show_score proc
    mov dh, 9
    mov dl, 70
    call set_cursor
    mov dx, offset msg_blank
    mov ah, 09h
    int 21h
    mov dh, 9
    mov dl, 70
    call set_cursor
    mov ax, [score]
    call print_decimal
    ret
show_score endp

show_high_score proc
    mov dh, 7
    mov dl, 70
    call set_cursor
    mov dx, offset msg_blank
    mov ah, 09h
    int 21h
    mov dh, 7
    mov dl, 70
    call set_cursor
    mov ax, [high_score]
    call print_decimal
    ret
show_high_score endp

set_cursor proc
    mov ah, 02h
    mov bh, 0
    int 10h
    ret
set_cursor endp

print_decimal proc
    push ax
    push bx
    push cx
    push dx
    mov cx, 0
    mov bx, 10
pd_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz pd_loop
pd_print:
    pop dx
    add dl, '0'
    mov ah, 02h
    int 21h
    loop pd_print
    pop dx
    pop cx
    pop bx
    pop ax
    ret
print_decimal endp

; ============================================================
; SES FONKSIYONLARI 
; ============================================================
play_jump_sound proc
    mov ax, 1000
    call start_sound
    ret
play_jump_sound endp

play_crash_sound proc
    mov ax, 4000
    call start_sound
    mov ah, 86h
    mov cx, 0002h
    mov dx, 0000h
    int 15h
    call stop_sound
    ret
play_crash_sound endp

start_sound proc
    mov al, 0B6h
    out 43h, al
    out 42h, al
    mov al, ah
    out 42h, al
    in al, 61h
    or al, 3
    out 61h, al
    ret
start_sound endp

stop_sound proc
    in al, 61h
    and al, 0FCh
    out 61h, al
    ret
stop_sound endp

game_delay proc
    mov ah, 86h
    mov cx, 0
    mov dx, [game_speed]    ; Dinamik hiz
    int 15h
    ret
game_delay endp

end prog_start