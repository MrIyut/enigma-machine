%include "../include/io.mac"

; constants
LETTERS_COUNT EQU 26
ROTOR_SIZE EQU 52

section .data
    extern len_plain

section .text
    global rotate_x_positions
    global enigma
    extern printf

shift_rotor:
	push ebp
	mov ebp, esp

	; functions parameters
	; mov eax, [ebp + 8] ; offset
	; mov ebx, [ebp + 12] ; rotor address
	; mov ecx, [ebp + 16] ; direction


	mov eax, [ebp + 12]
	xor ecx, ecx
	sub esp, ROTOR_SIZE

	xor ecx, ecx
	.loop2:
		mov edx, [eax + ecx]
		mov byte [ebp - ROTOR_SIZE + ecx], dl
		inc ecx
		cmp ecx, ROTOR_SIZE
		jl .loop2

	xor ecx, ecx
	.shift:
		mov eax, ecx
		cmp dword [ebp + 16], 1
		je .changeDirection

		add eax, dword [ebp + 8]
	.dirChanged:
		mov ebx, LETTERS_COUNT

		xor edx, edx
		div ebx
		cmp ecx, LETTERS_COUNT
		jge .addOffset
	
	.continue:
		mov bl, byte [ebp - ROTOR_SIZE + edx]
		mov eax, [ebp + 12]
		mov [eax + ecx], bl

		inc ecx
		cmp ecx, ROTOR_SIZE
		jl .shift
	
	jmp .exit
	.addOffset:
		add edx, LETTERS_COUNT
		jmp .continue

	.changeDirection:
		sub eax, dword [ebp + 8]
		add eax, LETTERS_COUNT ; offset to ignore negative numbers
		jmp .dirChanged

	.exit:
		mov esp, ebp
		pop ebp
		ret

get_address_of_component:
	push ebp
	mov ebp, esp

	; functions parameters
	; [ebp + 8]; config matrix
	; [ebp + 12]; component index: 0 - 4
	
	
	mov eax, ROTOR_SIZE
	imul eax, [ebp + 12]

	mov ebx, [ebp + 8]
	lea eax, [ebx + eax]

	mov esp, ebp
	pop ebp
	ret

rotate_x_positions:
    push ebp
    mov ebp, esp
    pusha

    mov eax, [ebp + 8]  ; x
    mov ebx, [ebp + 12] ; rotor
    mov ecx, [ebp + 16] ; config (address of first element in matrix)
    mov edx, [ebp + 20] ; forward
   
	pusha
		push dword [ebp + 12]
		push dword [ebp + 16]
		call get_address_of_component
		add esp, 8
	
		push dword [ebp + 20]
		push eax
		push dword [ebp + 8]
		call shift_rotor
		add esp, 12
	popa
   
    popa
    leave
    ret

match_component:
	push ebp
	mov ebp, esp

	; functions parameters
	; [ebp + 8] - index


	cmp dword [ebp + 8], 0
	je .plugboard
	cmp dword [ebp + 8], 4
	je .reflector
	mov eax, 3
	sub eax, dword [ebp + 8]
	jmp .exit

.plugboard:
	mov eax, 4
	jmp .exit

.reflector:
	mov eax, 3
	jmp .exit

.exit:
	mov esp, ebp
	pop ebp
	ret

match_letter:
	push ebp
	mov ebp, esp

	; functions parameters
	; [ebp + 8]; component address
	; [ebp + 12]; initial letter (index, if not looking in the same row)
	; [ebp + 16]; match on the same row
	; [ebp + 20]; look backwards


	mov ebx, [ebp + 8]
	cmp dword [ebp + 16], 1
	jne .skipRow

	; look in the first row for the index of the letter
	xor edx, edx
	mov dl, [ebp + 12]
	jmp .startIteration

.skipRow:
	cmp dword [ebp + 20], 1
	je .lookBackwards
	mov eax, [ebp + 12]
	xor edx, edx
	mov dl, [ebx + eax]
	add ebx, LETTERS_COUNT ; go onto the next row
	jmp .startIteration

.lookBackwards:
	mov eax, [ebp + 12]
	xor edx, edx
	mov dl, [ebx + LETTERS_COUNT + eax]
	jmp .startIteration

.startIteration:
	xor eax, eax
	.loop:
		mov cl, [ebx + eax]
		cmp cl, dl
		je .exit

		inc eax,
		cmp eax, LETTERS_COUNT
		jl .loop

.exit:
	mov esp, ebp
	pop ebp
	ret

perform_step:
	push ebp
	mov ebp, esp

	; functions parameters
	; [ebp + 8] - config matrix
	; [ebp + 12] - component index
	; [ebp + 16] - current index / letter
	; [ebp + 20] - initial step
	; [ebp + 24] - look backwards

	push dword [ebp + 12] ; match component index
	call match_component
	add esp, 4
	push eax ; get address of component
	push dword [ebp + 8]
	call get_address_of_component
	add esp, 8

	push dword [ebp + 24]
	push dword [ebp + 20] ; get next index
	push dword [ebp + 16] 
	push eax
	call match_letter
	add esp, 12
	mov esp, ebp
	pop ebp
	ret

encrypt:
	push ebp
	mov ebp, esp

	; functions parameters
	; [ebp + 8] - config matrix
	; [ebp + 12] - initial letter


	xor eax, eax
	mov al, [ebp + 12]

	push dword 1 ; initialize the letter
	push eax
	push 0
	push dword [ebp + 8]
	call perform_step
	add esp, 16

	xor edi, edi
	.forward:
		push dword 1
		push dword 0
		push eax
		push edi
		push dword [ebp + 8]
		call perform_step
		add esp, 16

		inc edi
		cmp edi, 5
		jl .forward

	mov edi, 3
	.backwards:
		push dword 0 ; look backwards
		push dword 0 
		push eax
		push edi
		push dword [ebp + 8]
		call perform_step
		add esp, 16

		dec edi
		cmp edi, 0
		jg .backwards

	mov ebx, [ebp + 8]
	mov ecx, LETTERS_COUNT
	imul ecx, 9
	add ecx, eax
	mov eax, [ebx + ecx]

	mov esp, ebp
	pop ebp
	ret

perform_shift:
	push ebp
	mov ebp, esp

	; functions parameters
	; [ebp + 8] - config matrix
	; [ebp + 12] - rotor
	; [ebp + 16] - key
	; [ebp + 20] - rotor

	mov eax, [ebp + 16]
	mov ebx, [ebp + 12]
	xor ecx, ecx
	mov cl, [eax + ebx]

	mov eax, [ebp + 16]
	mov ebx, [ebp + 12]
	xor edx, edx
	mov dl, [eax + ebx]

	inc dl
	cmp edx, 91
	jne .continue
	mov dl, byte 65

.continue:	
	mov ebx, [ebp + 12]
	mov eax, [ebp + 16]
	mov [eax + ebx], dl

	push dword 0 ; left_shift
	push dword [ebp + 8]
	push dword [ebp + 12] 
	push dword 1
	call rotate_x_positions
	add esp, 16

	mov esp, ebp
	pop ebp
	ret

enigma:
    ;; DO NOT MODIFY
    push ebp
    mov ebp, esp
    pusha

    mov eax, [ebp + 8]  ; plain (address of first element in string)
    mov ebx, [ebp + 12] ; key
    mov ecx, [ebp + 16] ; notches
    mov edx, [ebp + 20] ; config (address of first element in matrix)
    mov edi, [ebp + 24] ; enc
	; shift last rotor

	push dword [ebp + 12]
	push dword 2
	push dword [ebp + 20]
	call perform_shift
	add esp, 12

	mov eax, [ebp + 8]
	xor ecx, ecx
	.parse_plain:
		push ecx

		mov edx, [eax + ecx]
		mov ebx, [ebp + 20]
		push dword edx
		push dword ebx
		call encrypt
		add esp, 8
		
		pop ecx
		mov edi, [ebp + 24]
		mov [edi + ecx], al

		; shift rotors
		push ecx
		xor ecx, ecx
		inc ecx
		.parser_rotors:
			xor eax, eax
			mov esi, [ebp + 12]
			mov al, [esi + ecx] ; key
			xor ebx, ebx
			mov esi, [ebp + 16]
			mov bl, [esi + ecx] ; notch
			cmp eax, ebx
			jne .iterate

			mov eax, ecx
			dec eax
			push ecx

			push dword [ebp + 12]
			push eax
			push dword [ebp + 20]
			call perform_shift
			add esp, 12

			pop ecx
			cmp ecx, 1
			jne .iterate
			push ecx
				
			push dword [ebp + 12]
			push ecx
			push dword [ebp + 20]
			call perform_shift
			add esp, 12

			pop ecx
			.iterate:
				inc ecx
				cmp ecx, 3
				jl .parser_rotors

		; shift last rotor
		push dword [ebp + 12]
		push dword 2
		push dword [ebp + 20]
		call perform_shift
		add esp, 12

		pop ecx
		inc ecx
		mov eax, [ebp + 8]
		cmp ecx, dword [len_plain]
		jl .parse_plain

	mov edi, [ebp + 24]
	mov [edi + ecx], byte 0

    popa
    leave
    ret