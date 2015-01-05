;; Purpose: decrypt item.dat

getBlockPointer:
	LDR     R1, [SP]           				; R1=offset of the file in the memory
	MLA     R1, R7, R5, R1                  ; get the pointer of the next block, R1= blockindex * blocklength + fileoffset
	MOV     R2, R5							; R2 = R5 = block size
	BL      decodeBlock                     ; Decode Block (R1=offset of the block to decode, R2 = R5 = block size)
	ADD     R7, R7, #1
	CMP     R7, #0x400                      ; in item.dat there are 0x400 blocks of 44 bytes, so 45056 bytes total
	BLT     storeEncryptedData              ; repeat with next block	


storeEncryptedData:
	LDR     R0, =dword_20B9DD4              ; load the offset of block index
	MOV     R6, #0
	LDR     R3, =dword_20B9DD8              ; load the offset where data starts
	LDR     R0, [R0]                        ; get the block index (0,1,2,3)
	MOV     R5, R2
	ADD     R4, R3, R0,LSL#7                ; get the offset where the data will be stored (due to the block index)
											; there are 4 slots (128 bytes each)
											; when all the slots are full, it overrides them from the first
	MOV     R0, R1
	MOV     R1, R4							; R1 is the offset where the data block will be stored
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