;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; castle door entrance 	  ;;
;; by elusive				  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; BETA version

;; conflicts:
;;	bonus stars will erase parts of door
;; resolved conflicts (with oam searching):
;;	point will erase parts of door
;;	other stuff in OAM200 slots 44-55, indices $B0-$DC range


; settings
!trigger_size 					= $0060 	; size of range (-5 + 6 = +1 tiles)
!trigger_start					= $FFB0		; start of range (-5 tiles)
!door_tile 						= $A5 		;

; RAM
!SPR_WithinRange				= !1504 	; 0 = false, 1 = true
!SPR_AnimTimer 					= !1510  	; closed: 00 (closed) -> 56 (open) <- B0 (closed)
!SPR_AnimOffset 				= !1594 	; height of door depending on anim timer


!RAM_Timer 						= $18D9 	; default timer, we wont use this
!RAM_CurrentSpriteX 			= $15E9


XOffset:									; x position offsets for each tile
	db $F8,$08,$18
	db $F8,$08,$18
	db $F8,$08,$18
	db $F8,$08,$18

YOffset:									; y position offsets for each tile
	db $00,$00,$00
	db $10,$10,$10
	db $20,$20,$20
	db $30,$30,$30


print "INIT ",pc

	STZ !SPR_WithinRange,x 					;\ change to extra property possibly						
	STZ !SPR_AnimTimer,x					;/ set animation to 0 phase (initial door state closed) 

print "MAIN ",pc

	PHB : PHK : PLB
		JSR Main
	PLB
	RTL

Main:							
	JSR Graphics 							;> graphics routine

	LDA $9D 								;\ if sprites locked, return			
	BNE .return 								;/

	LDA #$00
	%SubOffScreen()							;> kill if offscreen	

	.return
	RTS


Graphics:
	%SubHorzPos() 							;\ get distance to mario
	TYA 									;| 0 - mario on right, 1+ - mario on left
	STA !157C,x 							;/ set face direction, probably not needed 

	REP #$20 								;\ 
	LDA $0E 								;| 
	SEC : SBC #!trigger_start 				;| check if mario is within trigger range to open door
	CMP #!trigger_size 						;| 
	SEP #$20 								;| 
	BCS .outOfRange 						;/ 

	.withinRange							 
	LDA !SPR_AnimTimer,x 					;\ make sure animation timer is done, ie at $00
	BNE .noChange 							;/

	LDA #$00 								;\
	EOR !SPR_WithinRange,x 					;| compare to previous state
	BNE .noChange 							;| if changed,
											;| 
	LDA #$01 								;| 
	STA !SPR_WithinRange,x 					;| save within range state
											;| 
	LDA #$B0 								;| 
	STA !SPR_AnimTimer,x 					;| and set animation timer start
											;| 
	BRA .noChange 							;/ 

	.outOfRange								
	LDA !SPR_AnimTimer,x 					;\ 
	CMP #$56	 							;| make sure animation timer is done. ie at $56
	BNE .noChange 							;/ 

	LDA #$01 								;\
	EOR !SPR_WithinRange,x 					;| compare to previous state
	BNE .noChange 							;| if changed,		
											;|
	LDA #$00 								;|
	STA !SPR_WithinRange,x 					;| save out of range
											;|
	LDA #$55								;|
	STA !SPR_AnimTimer,x					;/ and set animation timer start

	.noChange
	LDA !SPR_AnimTimer,x 					;\ 
	BNE + 									;| if timer is not $00 
	BRA DrawGFX 							;| 
	+ 										;| 
	CMP #$56 								;| or $56,
	BEQ DrawGFX 							;| 
	DEC !SPR_AnimTimer,x					;/ dec timer 

	.openDoor 
	CMP #$B0								;\ if timer value is $B0,
	BNE .closeDoor							;| 
	LDY #$0F								;| play door open sound effect
	STY $1DFC								;/

	.closeDoor 
	CMP #$01								;\ if timer value is $01,
	BNE DrawGFX 							;|
	LDY #$10								;| play door shut sound effect
	STY $1DFC								;/

DrawGFX:
	;%GetDrawInfo() 						; do it ourselves \o/
	;JSR GetOffScreen 						; dont think this is necessary but might save time
	;BNE Return 							;

	LDA !SPR_AnimTimer,x 					;\ 
	CMP #$30								;| if animation timer is less than $30,
	BCC .storeYPos							;| store offset
											;|
	CMP #$81								;| else, if animation timer above $80
	BCC .setMaxDoorPos						;| set max door position
											;|
	CLC	: ADC #$4F							;| else, get the y position offset by
	EOR #$FF : INC							;| adding difference between $81 and $D0
	BRA .storeYPos							;| and two's complement to get value between $00-$30
											;|
	.setMaxDoorPos							;| 
	LDA #$30								;| max y position offset for the door when fully open
	.storeYPos								;| 
	STA !SPR_AnimOffset,x  					;/ store the offset

	LDX #$0B								; tile count (12)
	;LDY #$B0								; OAM index from $0200
	LDY #$30

TileLoop:

	.findOAMSlot
	LDA $0201|!addr,y 						;\ 
	CMP #$F0 								;| if tile is vertically offscreen,
	BEQ .findOAMSlotEnd 					;| slot found
	INY #4 									;| else, keep searching
	BNE .findOAMSlot 						;|
	RTS										;/ return if no slots found
	.findOAMSlotEnd

; Input:
; 	X: tile index
; Output:
;	$0C-$0D: tile x pos relative to screen border
; 	A: tile x pos relative to screen border
	.getTileXPos:
	LDA XOffset,x 							;\ store 16-bit tile x offset into $08-$09
	JSR SignExtension 						;/

	PHX										; preserve X
	LDX !RAM_CurrentSpriteX					;\ 
	LDA !14E0,x 							;| load 16-bit sprite x location
	XBA 									;| 
	LDA !E4,x 								;/ 

	REP #$20 								;\
	CLC	: ADC $08							;| add tile x offset
	SEC : SBC $1A 							;| subtract layer 1 x pos 
	STA $0C 								;| store to $0C-$0D
	SEP #$20 								;/
	PLX 									; restore X

	STA $0200|!addr,y						;> set tile x pos	

; Input:
; 	X: tile index
; Output:
; 	$0E-$0F: tile y pos relative to screen border
; 	A: tile y pos relative to screen border
	.getTileYPos
	LDA YOffset,x 							;\ store 16-bit tile y offset into $08-$09
	JSR SignExtension 						;/

	PHX										; preserve X
	LDX !RAM_CurrentSpriteX					;\ 
	LDA !14D4,x 							;| load 16-bit sprite y location
	XBA 									;| 
	LDA !D8,x 								;/ 

	REP #$20 								;\ 
	CLC	: ADC $08							;| add tile y offset
	SEC : SBC !SPR_AnimOffset,x				;| subtract animation frame offset
	SEC : SBC $1C 							;| subtract layer 1 y pos 
	STA $0E 								;| store to $0E-$0F
	CMP #$00F0 								;| #$0100 - #$0010
	BCC .onScreen 							;| 
	LDA #$00F0 								;| hide on bottom of screen
	.onScreen 								;| 
	SEP #$20 								;/ 
	PLX 									; restore X

	STA $0201|!addr,y						; set tile y pos

; Input: 
;	$0D: x position high byte
	.setTileSize
    PHY 									;\ preserve Y (OAM index)
    TYA 									;| 
    LSR #2 									;| oamindex/4 to get oam extra bits index
    TAY 									;| 
    LDA $0D 								;| high byte of tile x pos relative to screen border
    AND #$01 								;| set 9th bit?
    ORA #$02 								;| 16x16 tile
    STA $0420|!addr,y  						;|
    PLY 									;/ restore Y (OAM index)	

	LDA #!door_tile							;\ set door tile number
	STA $0202|!addr,y						;/ 

	PHX 									;\ preserve X (tile index)
	LDX $15E9|!addr							;| restore sprite slot
	LDA !15F6,x								;| get palette/page from config
	ORA $64									;| mixed with in-level priority
	STA $0203|!addr,y						;| 
	PLX 									;/ restore X (tile index)

	INY #4 									;\ increment OAM index by 4
	DEX										;| next tile
	BPL .tileLoop							;/ 
	BRA .return
	
	.tileLoop
	JMP TileLoop
	
	.return 								;\
	LDX $15E9|!addr							;| restore X (sprite slot)
	RTS										;/ and return


; Input:
;	A: the 8-bit number to extend
; Output:
;	$08-$09: the 16-bit equivalent of the input
SignExtension:
	STA $08 								; store the low byte
	BMI + 									; 
	LDA #$00 								; 
	BRA ++  								; 
+	LDA #$FF  								; 
++	STA $09 								; store the high byte
	RTS



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; not using below atm 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; Input:
; 	X: sprite index
; Output:
; 	15A0,x: 0 if onscreen, 1 if onscreen
; 	15C4,x: 0 if onscreen, 1 if 4+ tiles offscreen
GetOffScreen:

	LDA !14E0,x
	XBA
	LDA !E4,x
	REP #$20
	SEC : SBC $1A
	STA $00
	CLC
	ADC #$0040
	CMP #$0180
	SEP #$20
	LDA $01
	BEQ +
	LDA #$01
	+
	STA !15A0,x
	TDC
	ROL A
	STA !15C4,x

	RTS


