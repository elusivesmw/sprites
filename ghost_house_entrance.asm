;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ghost house entrance 	  ;;
;; by elusive				  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; conflicts:
;;	bonus stars will parts of erase door
;; resolved conflicts (with oam searching):
;;	point will erase parts of door
;;	other stuff in OAM200 slots 44-55, indices $B0-$DC range


; settings
!trigger_size 					= $0060 	; size of range (-5 + 6 = +1 tiles)
!trigger_start					= $FFB0		; start of range (-5 tiles)

; RAM
!SPR_WithinRange				= !1504 	; 0 = false, 1 = true
!SPR_Distance 					= !1510 	; dont really need to save
!SPR_AnimTimer 					= !151C  	; closed: 00 -> 56 (open) < - A0 (closed)
!SPR_AnimOffset 				= !1594


!RAM_Timer 						= $18D9 	; default timer, we wont use this
!RAM_CurrentSpriteX 			= $15E9



XOffset:						;$02F6F1	| X position offsets for each tile of the Ghost House entrance, for each animation phase.
	db $F8,$F8,$F8,$F8,$08,$08,$08,$08		; 0 - Closed, $00 - 0 priority, $10 - priority 1
	db $F8,$F8,$F8,$F8,$08,$08,$08,$08		; 1 - Slightly open
	db $F8,$F8,$F8,$F8,$08,$08,$08,$08		; 2 - Mostly open
	db $EA,$EA,$EA,$EA,$16,$16,$16,$16		; 3 - Fully open, $F2 = %1111.0010, $1E = %0001.1110, first 4, left door, second 4, right door

YOffset:						;$02F711	| Y position offsets for each tile of the Ghost House entrance.
	db $00,$08,$18,$20,$00,$08,$18,$20

YXPPCCCT:					;$02F719	| YXPPCCCT for each tile of the ghost house entrance.
	db $7D,$7D,$FD,$FD,$3D,$3D,$BD,$BD		; $7D = %0111.1101, $FD = %1111.1101, $3D = %0011.1101, $BD = %1011.1101
											; $4D = %0101.1101, 				  $0D = %0000.1101

Tilemap:						;$02F721	| Tile numbers for each of the Ghost House entrance's tiles.
	db $A0,$B0,$B0,$A0,$A0,$B0,$B0,$A0		; 0 - Closed
	db $A3,$B3,$B3,$A3,$A3,$B3,$B3,$A3		; 1 - Slightly open
	db $A2,$B2,$B2,$A2,$A2,$B2,$B2,$A2		; 2 - Mostly open
	db $A3,$B3,$B3,$A3,$A3,$B3,$B3,$A3		; 3 - Fully open

OAMTable:						;$02F741	| OAM indices (from $0300) for each tile of the castle door.
	db $70,$74,$78,$7C,$E4,$E8,$EC,$F0

AnimationFrames:
								;$02F749	| Frames for the door's animation.
	db $00,$01,$02,$03,$03,$03,$03,$03		; close door animate
	db $03,$03,$03,$03,$03,$02,$01,$00		; open door animate: 00 - closed, 03 - open


print "INIT ",pc

	STZ !SPR_WithinRange,x 					;\ change to extra property possibly
	STZ !SPR_AnimTimer,x					;/ set animation to 0 phase (initial door state closed)

print "MAIN ",pc

PHB : PHK : PLB
	JSR Main
PLB
RTL


Main:
	JSR Graphics

	LDA $9D 								;\ if sprites locked, return			
	BNE .return 							;/

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
	LDA #$7F 								;| 
	STA !SPR_AnimTimer,x 					;| and set animation timer start
											;| 
	BRA .noChange 							;/ 

	.outOfRange
	LDA !SPR_AnimTimer,x 					;\
	CMP #$40 								;| make sure animation timer is done. ie at $40
	BNE .noChange 							;/

	LDA #$01								;
	EOR !SPR_WithinRange,x 					; compare to previous state
	BNE .noChange 							;\ if changed,
											;|
	LDA #$00 								;|
	STA !SPR_WithinRange,x 					;| save out of range
											;|
	LDA #$3F								;|
	STA !SPR_AnimTimer,x					;/ and set animation timer start

	.noChange
	LDA !SPR_AnimTimer,x 					;\ 
	BNE + 									;| if timer is not $00 
	BRA DrawGFX 							;| 
	+ 										;| 
	CMP #$40 								;| or $40,
	BEQ DrawGFX 							;| 
	DEC !SPR_AnimTimer,x					;/ dec timer 

	.openDoor
	CMP #$76								;\ if timer value is $76,
	BNE .closeDoor							;| 
	LDY #$0F								;| play door open sound effect
	STY $1DFC								;/ 

	.closeDoor
	CMP #$08								;\ if timer value is $01,
	BNE DrawGFX								;| 
	LDY #$10								;| play door shut sound effect
	STY $1DFC								;/ 




DrawGFX:
	%GetDrawInfo()							; for OAM300 stuff
;	LDY !15EA,x 							; REMOVE: get current sprite slot's oam300 index. GetDrawInfo does this for us
	STY $04 								; backup Y (OAM300 index) to scratch

	LDA !SPR_AnimTimer,x 					; get timer for animation
	LSR #3 									; timer/8 into $03 = animation frame for the door
	
	PHY 									; backup Y (OAM300 slot)
	TAY										; 
	LDA.w AnimationFrames,y					; get animation frame
	STA $03									; 
	PLY 									; restore Y (OAM300 slot)

	LDX #$07								; set tile count for loop

;$04 = oam300 index
;$03 = animation frame 
;$02 = tile loop index 

TileLoop: 
	STX $02									;\ backup X (tile loop index)
	CPX #04 								;| if left door, OAM300
	BCS OAM200 								;/ else OAM200

OAM300: 									; OAM300 (left door)

											; y has the oam300 slot from GetDrawInfo and inc's after each tile
											; but this wouldn't work if 300 and 200 tiles flip flopped
											; might be okay, but just kinda sloppy
											; x here needs to be the xoffset index

	LDA $03									;\ get animation frame
	ASL #3 									;| *3 (row)
	CLC										;| add tile index
	ADC $02									;| to get tile for animation
	TAX										;/ and xoffset for animation

	JSR GetTileXPos
	STA $0300|!addr,y						; set tile x pos

	LDA Tilemap,x 
	STA $0302|!addr,y						; set tile number

	LDX $02									; restore X (tile loop index)

	JSR GetTileYPos
	STA $0301|!addr,y 						; set tile y pos

; Input: 
;	$0D: x position high byte
	.setTileSize
    PHY 									;\ preserve Y (OAM300 index)
    TYA 									;| 
    LSR #2 									;| oamindex/4 to get oam extra bits index
    TAY 									;| 
    LDA $0D 								;| high byte of tile x pos relative to screen border
    AND #$01 								;| set 9th bit?
    ORA #$02 								;| 16x16 tile
    STA $0460|!addr,y  						;|
    PLY 									;/ restore Y (OAM300 index)	



	LDA $03									;\ get animation frame
	CMP #$03								;| if door isn't open, 
	LDA YXPPCCCT,x							;| 
	BCC .dontFlip							;| don't x flip
	EOR #$40								;| else, x flip 
	.dontFlip:								;| 
	STA $0303|!addr,y						;/ set YXPPCCCT

	INY #4 									; increment OAM300 slot
	STY $04 								; backup Y (OAM300 slot) to scratch

	BRA TileLoopDec							; setup for loop

OAM200:										; OAM200 (right door)

	LDY #$30 								; have to start searching at the beginning each time because this isnt tracked
	.findOAMSlot
	LDA $0201|!addr,y 						;\ 
	CMP #$F0 								;| if tile is vertically offscreen,
	BEQ .findOAMSlotEnd 					;| slot found
	INY #4 									;| else, keep searching
	BNE .findOAMSlot 						;|
	RTS										;/ return if no slots found
	.findOAMSlotEnd

	LDA $03									;\ get animation frame
	ASL #3 									;| *3 (row)
	CLC										;| add tile index
	ADC $02									;| to get tile for animation
	TAX										;/ and xoffset for animation

	.getTileXPos
	JSR GetTileXPos
	STA $0200|!addr,y						; set tile x pos	

	LDA Tilemap,x 
	STA $0202|!addr,y						; set tile number

	LDX $02									; restore X (tile loop index)

	.getTileYPos
	JSR GetTileYPos
	STA $0201|!addr,y 						; set tile y pos

; Input: 
;	$0D: x position high byte
	.setTileSize
    PHY 									;\ preserve Y (OAM200 index)
    TYA 									;| 
    LSR #2 									;| oamindex/4 to get oam extra bits index
    TAY 									;| 
    LDA $0D 								;| high byte of tile x pos relative to screen border
    AND #$01 								;| set 9th bit?
    ORA #$02 								;| 16x16 tile
    STA $0420|!addr,y  						;|
    PLY 									;/ restore Y (OAM200 index)	


	LDA $03									;\ get animation frame
	CMP #$03								;| if door isn't open, 
	LDA YXPPCCCT,x							;|
	BCC .dontFlip							;| don't x flip
	EOR #$40								;| else, x flip
	.dontFlip:								;| 
	STA $0203|!addr,y						;/ set YXPPCCCT



TileLoopDec:								
	DEX										; next tile
	BMI .return								; if more tiles,
	JMP TileLoop							; loop

	.return
	;JSL $01B7B3 							; finish OAM write
	RTS										; 


; Input:
; 	X: tile index
; Output:
;	$0C-$0D: tile x pos relative to screen border
; 	A: tile x pos relative to screen border
GetTileXPos:
	LDA XOffset,x							;\ store 16-bit tile x offset into $08-$09
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

	RTS



; Input:
; 	X: tile index
; Output:
; 	$0E-$0F: tile y pos relative to screen border
; 	A: tile y pos relative to screen border
GetTileYPos:
	LDA YOffset,x 							;\ store 16-bit tile y offset into $08-$09
	JSR SignExtension 						;/

	PHX										; preserve X
	LDX !RAM_CurrentSpriteX					;\ 
	LDA !14D4,x 							;| load 16-bit sprite y location
	XBA 									;| 
	LDA !D8,x 								;/ 

	REP #$20 								;\ 
	CLC	: ADC $08							;| add tile y offset
	SEC : SBC $1C 							;| subtract layer 1 y pos 
	STA $0E 								;| store to $0E-$0F
	CMP #$00F0 								;| #$0100 - #$0010
	BCC .onScreen 							;| 
	LDA #$00F0 								;| hide on bottom of screen
	.onScreen 								;| 
	SEP #$20 								;/ 
	PLX 									; restore X

	RTS


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