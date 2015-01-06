;; Purpose: decrypt item.dat
;; code starts at 0x020714D8

getBlockPointer:
	LDR     R1, [SP]                        ; R1=offset of the file in the memory
	MLA     R1, R7, R5, R1                  ; get the pointer of the next block, R1= blockindex * blocklength + fileoffset
	MOV     R2, R5                          ; R2 = R5 = block size
	BL      storeEncryptedData              ; Decode Block (R1=offset of the block to decode, R2 = R5 = block size)
	ADD     R7, R7, #1                      ; increment the counter
	CMP     R7, #0x400                      ; in item.dat there are 0x400 blocks of 44 bytes, so 45056 bytes total
	BLT     getBlockPointer                 ; repeat with next block	


storeEncryptedData:
	STMFD   SP!, {R3-R7,LR}
	LDR     R0, =dword_20B9DD4              ; load the offset of block index
	MOV     R6, #0
	LDR     R3, =dword_20B9DD8              ; load the offset where data starts
	LDR     R0, [R0]                        ; get the block index (0,1,2,3)
	MOV     R5, R2
	ADD     R4, R3, R0,LSL#7                ; get the offset where the data will be stored (due to the block index)
	                                        ; there are 4 slots (128 bytes each)
	                                        ; when all the slots are full, it overrides them from the first
	MOV     R0, R1
	MOV     R1, R4                          ; R1 is the offset where the data block will be stored
	MOV     R7, R6
	BL      getEncryptedData                ; get the data to decrypt and stores it at R1 offset
	CMP     R5, #0
	MOV     R1, R6
	BLS     loc_2074918                     ; exit if block size(R5) isn't valid
	B       calculateXor

	
calculateXor:
	LDRB    R0, [R4,R1]                     ; load each single byte of the block
	EOR     R0, R0, #0xAD                   ; Xor it with 0xAD
	STRB    R0, [R4,R1]                     ; store it
	ADD     R1, R1, #1                      ; R1++ (R1 is the counter of the cycle)
	CMP     R1, #0x2C                       ; if R1 is less than 0x2C, decrypt more
	BCC     calculateXor                    ; encrypt next byte
	CMP     R5, #0
	MOV     R1, #0                          ; reset the counter
	BLS     loc_2074954                     ; if block size in not valid, exit
	B       shifting
	
	
shifing:
	LDRB    R2, [R4,R1]                     ; load the value to modify with logical operations and shifting bits
	MOV     R3, R7                          ; ... R1 counter
	B       doOperations                    ; do the shifting operations
	STRB    R2, [R4,R1]                     ; store the modified value
	ADD     R1, R1, #1                      ; R1 is the counter
	CMP     R1, R5                          ; when the cycle is finished, exit from the cycle
	BCC     shifing
	B       doFirstSwap                     ; once shifted all the block, go on

	
doOperations:
	MOV     R0, R2,LSL#7                    ; R0 = R2 << 7
	ORR     R0, R0, R2,ASR#1                ; R0 |= R2 >> 1
	ADD     R3, R3, #1                      ; R3 = R3 + 1
	CMP     R3, #2                          ; repeats the cycle two times
	AND     R2, R0, #0xFF                   ; R2 = R0 & 0xFF
	BLT     doOperations

	
doFirstSwap:
	SUBS    R3, R5, #2                      ; the counter of the cycle will arrive to blocklength - 2
	MOV     R7, #0                          ; R7 counter
	BEQ     doSecondSwap                    ; exit
	ADD     R2, R4, R7                      ; first swap cycle
	LDRB    R1, [R4,R7]                     ; read the data and recalculate the pointer AGAIN
	LDRB    R0, [R2,#2]                     ; skip 2 bytes (including the one just read)
	STRB    R0, [R4,R7]
	ADD     R7, R7, #3                      ; increment the counter R7 of 3
	STRB    R1, [R2,#2]                     ; swap the 2 bytes    ABC --> CBA don't change B
	CMP     R7, R3
	BCC     doFirstSwap                     ; swap again
	B       doSecondSwap

	
doSecondSwap:
	SUBS    R3, R5, #4                      ; the counter of the cycle will arrive to blocklength - 4
	MOV     R7, #0                          ; R7 counter
	BEQ     doThirdSwap                     ; exit
	ADD     R2, R4, R7                      ; second swap cycle
	LDRB    R1, [R4,R7]
	LDRB    R0, [R2,#4]                     ; ABCDE --> EBCDA
	STRB    R0, [R4,R7]
	ADD     R7, R7, #5
	STRB    R1, [R2,#4]
	CMP     R7, R3
	BCC     doSecondSwap                    ; second swap cycle
	B       doThirdSwap
	
doThirdSwap:
	SUBS    R3, R5, #6                      ; the counter of the cycle will arrive to blocklength - 6
	MOV     R7, #0                          ; R7 counter
	BEQ     doFourthSwap                    ; initialize the fourth cycle
	ADD     R2, R4, R7                      ; third swap cycle
	LDRB    R1, [R4,R7]
	LDRB    R0, [R2,#6]                     ; ABCDEFG --> GBCDEFA
	STRB    R0, [R4,R7]
	ADD     R7, R7, #7
	STRB    R1, [R2,#6]
	CMP     R7, R3
	BCC     doThirdSwap                     ; third swap cycle
	B       doFourthSwap

	
doFourthSwap:
	SUBS    R3, R5, #1                      ; initialize the fourth cycle
	MOV     R5, #0
	BEQ     modifyBlockIndex                ; get the actual block index
	ADD     R2, R4, R5                      ; fourth swap cycle
	LDRB    R1, [R4,R5]
	LDRB    R0, [R2,#1]
	STRB    R0, [R4,R5]
	ADD     R5, R5, #2
	STRB    R1, [R2,#1]                     ; ABCDEF --> BADCFE
	CMP     R5, R3
	BCC     doFourthSwap                    ; fourth swap cycle


modifyBlockIndex:
	LDR     R0, =dword_20B9DD4              ; get the actual block index
	LDR     R1, [R0]                        ; ...
	ADD     R1, R1, #1                      ; increment the index
	STR     R1, [R0]                        ; store the new value
	CMP     R1, #4                          ; if it's out of range (0-3) reset it to zero
	STREQ   R6, [R0]                        ; ... if it's zero, store it
	MOV     R0, R4
	LDMFD   SP!, {R3-R7,PC}                 ; getBlockPointer