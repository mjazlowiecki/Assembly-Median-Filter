.code

; ==================================================================================
; Makro: SORT_MIN_MAX
; bierze dwa rejestry (np. A i B). W A zostawia mniejsze wartoœci, w B wiêksze.
; Dzia³a na 16 bajtach jednoczeœnie (SIMD).
; ==================================================================================
SORT_MIN_MAX macro RegMin, RegMax
    movdqa xmm15, RegMin     ; zrób kopiê pierwszego rejestru do pomocniczego XMM15
    pminub RegMin, RegMax    ; w RegMin zostaw tylko mniejsze wartoœci z pary (min)
    pmaxub RegMax, xmm15     ; w RegMax zostaw tylko wiêksze wartoœci z pary (max)
endm

; ==================================================================================
; Procedura: ProcessChunkAsm
; Argumenty z C++ (w Rejestrach i na Stosie):
; RCX = imgData (Wyjœcie - gdzie piszemy)
; RDX = imgCopy (Wejœcie - sk¹d czytamy)
; R8  = width   (w pikselach)
; R9  = height  (tu nieu¿ywana, bo mamy yStart/yEnd)
;
; Argumenty 5, 6, 7, 8  na STOSIE, bo zabrak³o rejestrów:
; [RSP+104] = dstStride (szerokoœæ wiersza w pamiêci do zapisu)
; [RSP+112] = srcStride (szerokoœæ wiersza w pamiêci do odczytu)
; [RSP+120] = yStart    (od którego wiersza zacz¹æ)
; [RSP+128] = yEnd      (na którym wierszu skoñczyæ)
; ==================================================================================

ProcessChunkAsm proc
    ; 
    push rbp                 ; zapamiêtaj stary wskaŸnik bazowy
    push rbx                 
    push rsi                 
    push rdi                
    push r12                 
    push r13                
    push r14                 
    push r15                 
    mov rbp, rsp             

    
    movsxd r10, dword ptr [rsp + 104] ; pobierz dstStride; movsxd naprawia znak (32->64 bity)
    movsxd r11, dword ptr [rsp + 112] ; pobierz srcStride; to bezpieczna szerokoœæ wiersza
    
    movsxd r12, dword ptr [rsp + 120] ; pobierz yStart; tu zaczynamy pêtlê pionow¹
    movsxd r14, dword ptr [rsp + 128] ; pobierz yEnd; tu koñczymy pêtlê pionow¹

    movsxd rax, r8d          ; weŸ width z rejestru R8 (tylko dolne 32 bity inta)
    imul rax, 3              ; pomnó¿ razy 3, bo ka¿dy piksel to 3 bajty (B, G, R)
    mov r13, rax             ; zapisz wynik (szerokoœæ w bajtach) w R13
    sub r13, 19              ; odejmij 19 bajtów marginesu (3 na prawego s¹siada + 16 na wektor SSE)

    ; --- PÊTLA PO WIERSZACH (Y) ---
LoopY:
    cmp r12, r14             ; sprawdŸ czy obecny wiersz (R12) < koniec (R14)
    jge EndProc              ; jak ju¿ zrobiliœmy wszystko, to skacz do wyjœcia

    ; Obliczamy adres startowy wiersza w KOPII (Ÿród³o)
    mov rax, r12             ; weŸ numer wiersza Y
    imul rax, r11            ; pomnó¿ przez srcStride (Y * szerokoœæ wiersza)
    mov rsi, rdx             ; weŸ adres pocz¹tku obrazka (imgCopy)
    add rsi, rax             ; dodaj przesuniêcie -> RSI pokazuje na pocz¹tek naszego wiersza

    ; Obliczamy adres startowy wiersza w ORYGINALE (cel)
    mov rax, r12             ; weŸ numer wiersza Y
    imul rax, r10            ; pomnó¿ przez dstStride (tu stride mo¿e byæ ujemny!)
    mov rdi, rcx             ; weŸ adres pocz¹tku wyjœcia (imgData)
    add rdi, rax             ; dodaj przesuniêcie -> RDI pokazuje gdzie zapisaæ wynik

    ; --- PÊTLA PO KOLUMNACH (X) ---
    mov rbx, 3               ; zacznij od 3. bajtu (pomijamy pierwszy piksel z lewej jako margines)

LoopX:
    cmp rbx, r13             ; sprawdŸ czy nie doje¿d¿amy do prawej krawêdzi
    jg NextRow               ; jak tak, to idŸ do nastêpnego wiersza

    ; ==========================================================
    ; £ADOWANIE DANYCH DO REJESTRÓW WEKTOROWYCH (XMM)
    ; instrukcja 'movdqu' pobiera 16 bajtów naraz
    ; ==========================================================
    
    ; --- Wiersz GÓRNY (y-1) ---
    mov rax, rsi             ; weŸ adres bie¿¹cego wiersza
    sub rax, r11             ; cofnij siê o jeden stride (idŸ wiersz wy¿ej)
    add rax, rbx             ; przesuñ siê w prawo o X
    
    movdqu xmm0, [rax - 3]   ; pobierz lewego-górnego s¹siada   
    movdqu xmm1, [rax]       ; pobierz œrodkowego-górnego
    movdqu xmm2, [rax + 3]   ; pobierz prawego-górnego
    
    ; --- Wiersz ŒRODKOWY (y) ---
    mov rax, rsi             ; weŸ adres bie¿¹cego wiersza
    add rax, rbx             ; przesuñ siê w prawo o X
    
    movdqu xmm3, [rax - 3]   ; pobierz lewego s¹siada
    movdqu xmm4, [rax]       ; pobierz sam œrodek (piksel centralny)
    movdqu xmm5, [rax + 3]   ; pobierz prawego s¹siada

    ; --- Wiersz DOLNY (y+1) ---
    mov rax, rsi             ; weŸ adres bie¿¹cego wiersza
    add rax, r11             ; dodaj stride (idŸ wiersz ni¿ej)
    add rax, rbx             ; przesuñ siê w prawo o X
    
    movdqu xmm6, [rax - 3]   ; pobierz lewego-dolnego
    movdqu xmm7, [rax]       ; pobierz œrodkowego-dolnego
    movdqu xmm8, [rax + 3]   ; pobierz prawego-dolnego

    ; ==========================================================
    ; SORTOWANIE
    ; u¿ywamy min/max.
    ; Celem jest, aby mediana (œrodkowa wartoœæ) trafi³a do XMM4.
    ; ==========================================================
    
    ; Faza 1: Wstêpne sortowanie kolumnami
    SORT_MIN_MAX xmm0, xmm1  ; porównaj parê 0-1
    SORT_MIN_MAX xmm1, xmm2  ; porównaj parê 1-2
    SORT_MIN_MAX xmm2, xmm3  ; porównaj parê 2-3
    SORT_MIN_MAX xmm3, xmm4  ; porównaj parê 3-4
    SORT_MIN_MAX xmm4, xmm5  ; porównaj parê 4-5
    SORT_MIN_MAX xmm5, xmm6  ; porównaj parê 5-6
    SORT_MIN_MAX xmm6, xmm7  ; porównaj parê 6-7
    SORT_MIN_MAX xmm7, xmm8  ; porównaj parê 7-8 (najwiêksze wartoœci do xmm8)

    ; Faza 2: Kolejny przebieg b¹belkowy
    SORT_MIN_MAX xmm0, xmm1
    SORT_MIN_MAX xmm1, xmm2
    SORT_MIN_MAX xmm2, xmm3
    SORT_MIN_MAX xmm3, xmm4
    SORT_MIN_MAX xmm4, xmm5
    SORT_MIN_MAX xmm5, xmm6
    SORT_MIN_MAX xmm6, xmm7 

    ; Faza 3
    SORT_MIN_MAX xmm0, xmm1
    SORT_MIN_MAX xmm1, xmm2
    SORT_MIN_MAX xmm2, xmm3
    SORT_MIN_MAX xmm3, xmm4
    SORT_MIN_MAX xmm4, xmm5
    SORT_MIN_MAX xmm5, xmm6

    ; Faza 4
    SORT_MIN_MAX xmm0, xmm1
    SORT_MIN_MAX xmm1, xmm2
    SORT_MIN_MAX xmm2, xmm3
    SORT_MIN_MAX xmm3, xmm4
    SORT_MIN_MAX xmm4, xmm5 
    
    ; 
    SORT_MIN_MAX xmm1, xmm2
    SORT_MIN_MAX xmm2, xmm3
    SORT_MIN_MAX xmm3, xmm4  ; teraz w XMM4 na pewno siedzi mediana!

    ; ==========================================================
    ; ZAPIS WYNIKU
    ; ==========================================================
    
    mov rax, rdi             ; weŸ adres wiersza wyjœciowego
    add rax, rbx             ; przesuñ siê do aktualnego X
    movdqu [rax], xmm4       ; zapisz 16 bajtów wyniku (mediany) do pamiêci

    add rbx, 16              ; przesuñ siê o 16 bajtów w prawo (bo zrobiliœmy 16 pikseli naraz)
    jmp LoopX                ; powtórz dla kolejnych pikseli w wierszu

NextRow:
    inc r12                  ; zwiêksz licznik wierszy (Y++)
    jmp LoopY                ; wróæ na pocz¹tek pêtli pionowej

EndProc:
    ; --- SPRZ¥TANIE ---
    pop r15                  ; przywróæ R15
    pop r14                  ; przywróæ R14
    pop r13                  ; przywróæ R13
    pop r12                  ; przywróæ R12
    pop rdi                  ; przywróæ RDI
    pop rsi                  ; przywróæ RSI
    pop rbx                  ; przywróæ RBX
    pop rbp                  ; przywróæ RBP (wskaŸnik stosu)
    ret                      ; wróæ do C++

ProcessChunkAsm endp
end