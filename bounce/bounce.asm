;
; Bounce Sprite spawner
; by elusive
; Spawns a bounce sprite at the placed position
; and then erases itself.
;


; Extra byte 1: Bounce sprite type
; Valid values (ID):
;    ID     Description
;----------------------------------
;    00    Free slot
;    01    Turn block (not turning)
;    02    Note block
;    03    Question mark block
;    04    Sideways bouncing block
;    05    Translucent block
;    06    On/Off block
;    07    Turn block (turning)


; Extra byte 2: Tile to turn into
; Valid Values (index number):
;    Index     Tile     Description
;----------------------------------
;    01    (025)    Empty, sets memory bit
;    02    (025)    Empty
;    03    (006)    Vine
;    04    (049)    Solid bush
;    05    (048)    Turning turnblock
;    06    (02B)    Coin
;    07    (0A2)    Mushroom stalk
;    08    (0C6)    Mole hole
;    09    (152)    Invisible solid block
;    0A    (11B)    Multiple coin turnblock
;    0B    (123)    Multiple coin ? block
;    0C    (11E)    Turnblock
;    0D    (132)    Used block
;    0E    (113)    Noteblock
;    0F    (115)    Noteblock
;    10    (116)    4-way noteblock
;    11    (12B)    Side-bounce turnblock
;    12    (12C)    Translucent block
;    13    (112)    On/off switch
;    14    (168)    Left side of pipe
;    15    (169)    Right side of pipe
;    16    (132)    Used block, sets memory bit
;    17    (15E)    "Correct" block, sets memory bit
;    18    (025)    Empty, include tile below, sets memory bit (Yoshi coins)
;    19    (---)    4x4 empty net frame (VRAM only)
;    1A    (---)    4x4 net door (VRAM only)
;    1B    (-25)    2x2 invisible block, does not set high bytes (switch palace switch)


; Bounce sprite direction (only up is supported now so no extra byte yet)
;    Direction: L-----DD
;    00 = up, 01 = right, 10 = left, 11 = down.


; Extra byte 3: Direction
; Valid values:
;   00 = horizontal (right), 01 = vertical (down)

; Extra byte 4: Number of adjacent bounce sprites to spawn
; Valid values:
;   01-04


; RTN_GenerateTile routine notes:
; $00BEB0
; RAM setup:
;    $98   - 16-bit Y position of the tile.
;    $9A   - 16-bit X position of the tile.
;    $1933 - Layer to spawn the tile on (00 = layer 1, 01 = layer 2)

; Scratch RAM usage:
;    $06   - Index to VRAM (16-bit)
;    $08   - Layer X position (16-bit), sort of?
;    $0A   - Layer Y position (16-bit), sort of?


; custom bounce block setup
if !SA1 = 0
    !bounce_map16_low = $7FC275
    !bounce_map16_high = $7FC279
    !bounce_sprite_tile = $7FC27D
else
    !bounce_map16_low = $6132
    !bounce_map16_high = $6136
    !bounce_sprite_tile = $613A
endif


; Bounce sprite RAM
!BNC_SpriteType = $1699|!addr
!BNC_AltIndex = $18CD|!addr
!BNC_SpriteXPosLo = $16A5|!addr
!BNC_SpriteXPosHi = $16AD|!addr
!BNC_SpriteYPosLo = $16A1|!addr
!BNC_SpriteYPosHi = $16A9|!addr
!BNC_TurnsIntoTile = $16C1|!addr
!BNC_SpriteInitFlag = $169D|!addr
!BNC_SpriteYSpeed = $16B1|!addr
!BNC_SpriteXSpeed = $16B5|!addr
!BNC_BlockBounce = $16C9|!addr
!BNC_SpriteTimer = $16C5|!addr
!BNC_YXPPCCCT = $1901|!addr
!BNC_TurnblockTimer = $18CE|!addr
!RAM_LayerBeingProcessed = $1933|!addr

; Routines
!RTN_GenerateTile = $00BEB0|!bank






print "MAIN ",pc
    PHB : PHK : PLB
    JSR MainCode
    PLB
RTL


MainCode:

    LDA $9D                         ; return if frozen
    BEQ .cont
    RTS

.cont
    LDA #$00                        ;\ kill sprite first not frozen frame
    STA !14C8,x                     ;/ 


;~@sa1
;Input: A = Bounce sprite number,  X = $9C value, Y = bounce sprite direction,
;       $03-$04 = Map16 number (only if $9C or X is $1C or larger) (Requires Custom Bounce Block Sprites)
;Ouput: Y = Slot used
;Clobbers:
;       A, X, $05, $06, $07, 
; me: $08, $09

    LDA !extra_byte_1,x             ; get bounce sprite number from extra byte 1
    STA $05                         ; put bounce sprite number in $05

    LDA #$00                        ; fixed direction (UP), maybe put in extra byte later
    STA $06                         ; put direction in $06

    LDA !extra_byte_2,x             ; get tile to spawn from extra byte 2
    STA $07                         ; put tile to spawn in $07

    ; LDA !extra_byte_3,x             ; get quantity for multi-spawn from extra byte 3
    ; STA $0A                         ; put direction in $08

    ; LDA !extra_byte_4,x             ; get direction for multi-spawn from extra byte 4
    ; STA $0B                         ; put direction in $09

    LDY #$00
.qty

    LDA #$0F                        ; A = #$0F
    TRB $9A                         ; $9A = clear 4LSBs of $9A? ie #$47 -> #$40, $9A-$9B: 16-bit X position
    TRB $98                         ; $98 = clear 4LSBs of $98? ie #$91 -> #$90, $98-$99: 16-bit Y position
                                    ; this is to get the block positon from the mario's more precise position. basically truncate the pixels to the nearest tile.


    ; LDY 
    ; shifted Y times one tile amount ($10)
    ; and add to current position 
; tya
; asl #4
; sta $0c
; stz $0d

; phx
;     PHY
;     JSR Bounce
;     PLY
;     INY
; plx 
; wdm
;     CPY $0A   ; qty
;     BCC .qty

;     RTS





Bounce:


    LDY #$03                        ; setup index for bounce sprite loop
.find_free
    LDA !BNC_SpriteType,y           ;\ loop until 00 (free slot) is found
    BEQ .slot_found                 ;| 
    DEY                             ;| Y--
    BPL .find_free                  ;| none free, we are gonna have to overwrite
    DEC !BNC_AltIndex               ;| AltIndex--
    BPL .alt_slot                   ;| FF?,
    LDA #$03                        ;| reset to 03
    STA !BNC_AltIndex               ;/ 
.alt_slot
    LDY !BNC_AltIndex               ; Y = AltIndex
    LDA !BNC_SpriteType,y           ; A = SpriteType 
    CMP #$07                        ; is it a turning turnblock? 
    BNE .no_turn_block_reset        ;
    
    PEI ($02)                       ; yes turnblock reset,
    PEI ($04)                       ; push scratch to stack
    PEI ($06)                       ; cuz we need to use 
    PEI ($98)                       ; these RAM for the
    PEI ($9A)                       ; GenerateTile routine
    LDA !BNC_SpriteXPosLo,y         ;\ 
    STA $9A                         ;| 
    LDA !BNC_SpriteXPosHi,y         ;| 
    STA $9B                         ;| 
    LDA !BNC_SpriteYPosLo,y         ;| 
    CLC                             ;| 
    ADC #$0C                        ;| generate tile at bounce sprite position
    AND #$F0                        ;| 
    STA $98                         ;| 
    LDA !BNC_SpriteYPosHi,y         ;| 
    ADC #$00                        ;| 
    STA $99                         ;| 
    LDA !BNC_TurnsIntoTile,y        ;| 
    STA $9C                         ;| 
    JSL !RTN_GenerateTile           ;/ 
    REP #$20                        ;\ 16bit A
    PLA                             ;| 
    STA $9A                         ;| 
    PLA                             ;| 
    STA $98                         ;| 
    PLA                             ;| restore scratch from stack
    STA $06                         ;| 
    PLA                             ;| 
    STA $04                         ;| 
    PLA                             ;| 
    STA $02                         ;| 
    SEP #$20                        ;/ 8bit A
.no_turn_block_reset
    LDY !BNC_AltIndex               ; Y = AltIndex (the bounce index to overwrite)
.slot_found
    LDA $05                         ;\ bounce sprite init
    STA !BNC_SpriteType,y           ;| 

;
    CMP #$07                        ;\ is this a turnblock 
    BNE .b_init                     ;| no, skip
    LDA #$FF                        ;| yes, set turnblock timer,
    STA !BNC_TurnblockTimer,y       ;/ MOVE TO .no_turn_block_reset?
.b_init
;
    LDA #$00                        ;| Bounce sprite initialization flag table. #$00 = bounce sprite in init routine; #$01 = bounce sprite in main routine. Used for several things, such as generating tile 152 (invisible solid) once only.
    STA !BNC_SpriteInitFlag,y       ;| 
    

    LDA !E4,x                       ;\ load sprite x positon lo
    STA $9A                         ;| save to generate tile location 

    LDA !14E0,x                     ;\ 
    STA $9B                         ;| x hi

    LDA !D8,x                       ;\ 
    STA $98                         ;| y lo
 
    LDA !14D4,x                     ;\ 
    STA $99                         ;| y hi



; lda $0B
; beq .hor
; ; add vertically
;     rep #$20

;     lda $98
;     CLC
;     ADC $0C
;     STA $98

;     sep #$20

;     jmp .pos

; .hor
; ; add horizontally
;     rep #$20
    
;     lda $9A
;     CLC
;     ADC $0C
;     STA $9A

;     sep #$20


.pos

    lda $98
        STA !BNC_SpriteYPosLo,y         ;/ 

    lda $99
        STA !BNC_SpriteYPosHi,y         ;/
    
    lda $9a
        STA !BNC_SpriteXPosLo,y         ;/ x lo

    lda $9b
        STA !BNC_SpriteXPosHi,y         ;/ 


    LDA !RAM_LayerBeingProcessed    ;\ Layer being processed. #$00 = Layer 1; #$01 = Layer 2/3 (depending on which is interactive). Used in both level loading routine and processing interactions.
    LSR                             ;| bit 0 to carry 
    ROR                             ;| carry to bit 7
    STA $08                         ;/ $08 bit 7 is now layer flag
    LDX $06                         ;\ X = $06 (direction)
    LDA.l $02873A|!bank,x           ;| bounce sprite Y speed from table
    STA !BNC_SpriteYSpeed,y         ;| 
    LDA.l $02873E|!bank,x           ;| bounce sprite X speed from table
    STA !BNC_SpriteXSpeed,y         ;/ 


;    LDA #$03
;    STA $06                         ; set to down to prevent mario from bouncing (not working)


    TXA                             ;\ Format: L-----DD, L is which layer it is on. Clear means it's on layer 1, set means it's on layer 2 (or layer 3 if applicable)., DD is the direction it is moving in. 00 = up; 01 = right; 10 = left; 11 = down.
    ORA $08                         ;| $08 = layer flag
    STA !BNC_BlockBounce,y          ;/ 
    LDA $07                         ;\ $07 = bounce sprite
    STA !BNC_TurnsIntoTile,y        ;/ set bounce sprite tile
    LDA #$08                        ;\ 8 frame timer
    STA !BNC_SpriteTimer,y          ;/ exist for 8 frames
    LDA #$00                        ;\ set yxppccct
    STA !BNC_YXPPCCCT,y             ;/
    LDA $07                         ;\ is this a custom bounce sprite?
    CMP #$1C                        ;/
    BCC .notCustom                  ;> no, (my case)
    TYX                             ;\ yes, custom (UNTESTED)
    LDA $03                         ;| 
    STA !bounce_map16_low,x         ;| 
    LDA $04                         ;| 
    STA !bounce_map16_high,x        ;| stuff i don't care about since i'm not using custom
    LDA $07                         ;| 
    CMP #$FF                        ;| 
    BNE .notCustom                  ;| 
    LDA $02                         ;| 
    STA !bounce_sprite_tile,x       ;/
.notCustom
    PHY                             ;\ 
    PHK                             ;| 
    PEA.w .sprite_interact-1        ;| 
    PEA.w $B889-1                   ;| $02B889: Not modified, however is used by Lunar Magic as an RTL for calling routines that end in RTS in bank 2 with stack magic. So don't modify it.
    JML $0286ED|!bank               ;/ 
.sprite_interact
    PLY                             ;
    RTS                             ;
