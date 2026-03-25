################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Name, Student Number
# Student 2: Name, Student Number (if applicable)
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000
# Luxury Colors
# label 名字先不改，这样 generate_column 不用改结构
RED:     .word 0x6e0f1f     # Burgundy 酒红
GREEN:   .word 0x0f5c4a     # Emerald 墨绿
BLUE:    .word 0x1c2f5a     # Midnight Navy 深海军蓝
YELLOW:  .word 0xd4af37     # Gold 金色
CYAN:    .word 0xf5f0e6     # Ivory 象牙白
MAGENTA: .word 0xb76e79     # Rose Gold 玫瑰金
LUXURY_BLUE: .word 0x001A2EFF   # 深蓝（很高级）
PURE_WHITE:  .word 0xFFFFFF     # 数字用纯白
##############################################################################
# Hard 2 gem palette
# 3 visual style families x 6 colours = 18 gem appearances
#
# Family 1: deep jewel
# Family 2: bright cut
# Family 3: dark metallic
##############################################################################
gem_palette_count: .word 18

gem_palette:
    # Family 1: deep jewel
    .word 0x6e0f1f   # ruby
    .word 0x0f5c4a   # emerald
    .word 0x1c2f5a   # sapphire
    .word 0xd4af37   # gold
    .word 0xf5f0e6   # ivory
    .word 0xb76e79   # rose gold

    # Family 2: bright cut
    .word 0x8c2434   # bright ruby
    .word 0x1a7a65   # bright emerald
    .word 0x304f8f   # bright sapphire
    .word 0xf0cf65   # bright gold
    .word 0xffffff   # bright ivory
    .word 0xd997a1   # bright rose

    # Family 3: dark metallic
    .word 0x4f0814   # dark ruby
    .word 0x083f34   # dark emerald
    .word 0x101d3a   # dark sapphire
    .word 0x9e7d12   # dark gold
    .word 0xd8d0c2   # dark ivory
    .word 0x8d4f5d   # dark rose
##############################################################################
GREY: .word 0xe5c76b
PAUSE_RED: .word 0xb11226    # luxury deep red
##############################################################################
# Mutable Data
##############################################################################
# Column state
column_colors: .word 0, 0, 0
column_row:    .word 1
column_col:    .word 4

# Counts how many game loop ticks have passed since the last auto-drop.
# Incremented every tick; reset to 0 whenever the column drops one row.
drop_counter:  .word 0
 
# How many ticks must pass before the column auto-drops one row.
# At 60 FPS, a value of 30 means the column falls once every ~0.5 seconds.
drop_delay:    .word 30

# Scratch space used to flag cells that are part of a match before clearing.
# Layout: one word per board cell, row-major, rows 0-31 x cols 0-9.
# Stride is 40 bytes per row (10 words) to keep indexing simple.
# Total space needed: 32 rows * 40 bytes = 1280 bytes.
match_flags:   .space 1280

##############################################################################
# Background music state
##############################################################################
music_enabled:    .word 1      # 1 = play music, 0 = mute
music_index:      .word 0      # current note index
music_wait:       .word 0      # how many frames left before next note
music_length:     .word 16     # number of notes in the loop

# Instrument / volume for luxury style
# 0  = Acoustic Grand Piano
# 48 = String Ensemble 1
music_instrument: .word 0
music_volume:     .word 48

# Luxury-inspired elegant loop
# pitch = MIDI note number; -1 means rest
music_pitches:
    .word 69, 72, 76, 79, 76, 72, -1, 67
    .word 69, 72, 76, 81, 79, 76, 74, 72

# how long the note sounds (milliseconds)
music_durations:
    .word 192, 192, 192, 256, 192, 192, 128, 256
    .word 192, 192, 192, 256, 192, 192, 192, 320

# how many game-loop frames to wait before advancing to the next note
# your loop sleeps 16 ms each frame, so:
# 12 frames ≈ 192 ms, 16 frames ≈ 256 ms, 20 frames ≈ 320 ms
music_wait_frames:
    .word 12, 12, 12, 16, 12, 12,  8, 16
    .word 12, 12, 12, 16, 12, 12, 12, 20
##############################################################################
# Sound effects (luxury style)
##############################################################################
land_sfx_instrument:      .word 0     # piano
land_sfx_volume:          .word 42    # soft and restrained

clear_sfx_instrument:     .word 48    # strings
clear_sfx_volume:         .word 56    # brighter than landing sound

rotate_sfx_instrument:    .word 0     # piano
rotate_sfx_volume:        .word 34    # light, crisp shuffle sound

gameover_sfx_instrument:  .word 48    # strings
gameover_sfx_volume:      .word 62    # stronger dramatic finish
##############################################################################
# Pause state / pause message glyphs
##############################################################################
paused_flag: .word 0

# 3x5 glyphs, each word is one row, using 3 bits:
# bit pattern 111 = full row, 101 = left+right, etc.
GLYPH_P: .word 7, 5, 7, 4, 4
GLYPH_A: .word 7, 5, 7, 5, 5
GLYPH_U: .word 5, 5, 5, 5, 7
GLYPH_S: .word 7, 4, 7, 1, 7
GLYPH_E: .word 7, 4, 7, 4, 7
GLYPH_D: .word 6, 5, 5, 5, 6

GLYPH_G: .word 7, 4, 5, 5, 7
GLYPH_M: .word 7, 7, 5, 5, 5
GLYPH_O: .word 7, 5, 5, 5, 7
GLYPH_V: .word 5, 5, 5, 5, 2
GLYPH_R: .word 7, 5, 7, 6, 5
GLYPH_Q: .word 7, 5, 5, 7, 1
GLYPH_C: .word 7, 4, 4, 4, 7

# 3x5 digit glyphs
GLYPH_0: .word 7, 5, 5, 5, 7
GLYPH_1: .word 2, 6, 2, 2, 7
GLYPH_2: .word 7, 1, 7, 4, 7
GLYPH_3: .word 7, 1, 7, 1, 7
GLYPH_4: .word 5, 5, 7, 1, 1
GLYPH_5: .word 7, 4, 7, 1, 7
GLYPH_6: .word 7, 4, 7, 5, 7
GLYPH_7: .word 7, 1, 1, 1, 1
GLYPH_8: .word 7, 5, 7, 5, 7
GLYPH_9: .word 7, 5, 7, 1, 7

digit_glyph_table:
    .word GLYPH_0, GLYPH_1, GLYPH_2, GLYPH_3, GLYPH_4
    .word GLYPH_5, GLYPH_6, GLYPH_7, GLYPH_8, GLYPH_9

##############################################################################
# Score state
##############################################################################
score_value:            .word 0
difficulty_multiplier:  .word 1      # for now default difficulty = 1
score_base_per_gem:     .word 10     # each cleared gem gives 10 base points
##############################################################################
# Code
##############################################################################
 .text
 .globl main

main:
    jal fill_black_background
    jal draw_borders
    jal init_music
    jal init_score_state
    jal spawn_new_column
game_loop:
    li $v0, 32
    li $a0, 16
    syscall  
    
    jal music_tick
    jal auto_drop_tick

    lw $t0, ADDR_KBRD           # $t0 = keyboard base address (0xffff0000)
    lw $t1, 0($t0)              # $t1 = first word (1 if key pressed, 0 otherwise)

    beq $t1, 1, key_pressed     # if key pressed → handle input

    j game_loop                 # otherwise just redraw screen

key_pressed:
    lw $t2, 4($t0)             # $t2 = ASCII value of pressed key

    beq $t2, 0x61, move_left   # if 'a' → move left
    beq $t2, 0x64, move_right  # if 'd' → move right
    beq $t2, 0x77, rotate      # if 'w' → rotate colors
    beq $t2, 0x73, move_down   # if 's' → move down
    beq $t2, 0x70, toggle_pause # if 'p' → pause / resume
    beq $t2, 0x71, quit_game   # if 'q' → quit program

    j game_loop

move_left:
    la $t0, column_col         # load address of column_col
    lw $t1, 0($t0)             # $t1 = current column position
    beq $t1, 1, left_bump      # if at left boundary (col=1), stop
    
    jal can_move_left           # $v0 = 1 if space is free, 0 if occupied
    beq $v0, $zero, left_bump   # occupied -> block

    jal erase_column           # erase gems at current position
    lw $t1, column_col         # reload col (erase_column uses $t1)
    addi $t1, $t1, -1          # column = column - 1 (move left)
    sw $t1, column_col         # save new col to memory
    jal draw_column            # draw gems at new position
    j game_loop
left_bump:
    jal play_bump_sfx
    j game_loop
move_right:
    la $t0, column_col         # load address of column_col
    lw $t1, 0($t0)             # $t1 = current column position
    beq $t1, 8, right_bump     # if at right boundary (col=8), stop
    
    jal can_move_right
    beq $v0, $zero, right_bump

    jal erase_column
    lw $t1, column_col
    addi $t1, $t1, 1           # column = column + 1 (move right)
    sw $t1, column_col         
    jal draw_column            
    j game_loop
right_bump:
    jal play_bump_sfx
    j game_loop
move_down:
    sw $zero, drop_counter      # reset gravity timer
    jal try_move_down           # attempt to move down one row (or land)
    j game_loop

rotate:
    la  $t0, column_colors      # $t0 = base address of column_colors array

    lw  $t1, 0($t0)             # top color
    lw  $t2, 4($t0)             # middle color
    lw  $t3, 8($t0)             # bottom color

    sw  $t3, 0($t0)             # rotate downward by one
    sw  $t1, 4($t0)
    sw  $t2, 8($t0)

    jal play_rotate_sfx
    jal erase_column
    jal draw_column
    j   game_loop

quit_game:
    li $v0, 10              
    syscall 
toggle_pause:
    li   $t0, 1
    sw   $t0, paused_flag

    jal  draw_paused_message
    jal  wait_key_release      # avoid same keypress instantly unpausing

pause_loop:
    li   $v0, 32
    li   $a0, 16
    syscall

    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    beq  $t1, $zero, pause_loop

    lw   $t2, 4($t0)
    bne  $t2, 0x70, pause_loop   # only another 'p' resumes

    sw   $zero, paused_flag
    jal  clear_paused_message
    jal  wait_key_release
    j    game_loop
wait_key_release:
    lw   $t0, ADDR_KBRD

wait_key_release_loop:
    lw   $t1, 0($t0)
    beq  $t1, $zero, wait_key_release_done

    li   $v0, 32
    li   $a0, 16
    syscall
    j    wait_key_release_loop

wait_key_release_done:
    jr   $ra


game_over_screen:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    sw   $zero, paused_flag
    sw   $zero, music_enabled

    jal  play_game_over_sfx
    jal  fill_black_background
    jal  draw_borders
    jal  draw_game_over_message
    jal  wait_key_release

game_over_loop:
    li   $v0, 32
    li   $a0, 16
    syscall

    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    beq  $t1, $zero, game_over_loop

    lw   $t2, 4($t0)
    beq  $t2, 0x72, retry_game      # lowercase 'r'
    beq  $t2, 0x52, retry_game      # uppercase 'R'
    j    game_over_loop

retry_game:
    li   $t0, 1
    sw   $t0, music_enabled
    sw   $zero, paused_flag
    sw   $zero, drop_counter

    jal  fill_black_background
    jal  draw_borders
    jal  clear_match_flags
    jal  init_music
    jal  init_score_state
    jal  wait_key_release

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

init_music:
    sw   $zero, music_index
    sw   $zero, music_wait
    jr   $ra


music_tick:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # if music is disabled, do nothing
    lw   $t0, music_enabled
    beq  $t0, $zero, music_tick_done

    # if still waiting, decrement wait counter and return
    lw   $t0, music_wait
    beq  $t0, $zero, music_play_next
    addi $t0, $t0, -1
    sw   $t0, music_wait
    j    music_tick_done

music_play_next:
    # t0 = music_index
    lw   $t0, music_index
    sll  $t1, $t0, 2

    # load pitch
    la   $t2, music_pitches
    add  $t2, $t2, $t1
    lw   $t3, 0($t2)

    # load duration
    la   $t2, music_durations
    add  $t2, $t2, $t1
    lw   $t4, 0($t2)

    # load wait_frames
    la   $t2, music_wait_frames
    add  $t2, $t2, $t1
    lw   $t5, 0($t2)

    # set wait counter for upcoming frames
    sw   $t5, music_wait

    # if pitch == -1, this is a rest, so don't actually play a note
    bltz $t3, music_advance_index

    # play note asynchronously using syscall 31
    li   $v0, 31
    move $a0, $t3              # pitch
    move $a1, $t4              # duration in ms
    lw   $a2, music_instrument # instrument
    lw   $a3, music_volume     # volume
    syscall

music_advance_index:
    # index++
    lw   $t0, music_index
    addi $t0, $t0, 1

    # if index == music_length, wrap back to 0
    lw   $t6, music_length
    bne  $t0, $t6, music_store_index
    move $t0, $zero

music_store_index:
    sw   $t0, music_index

music_tick_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
play_land_sfx:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # brighter, elegant landing chime
    li   $v0, 31
    li   $a0, 69              # A4
    li   $a1, 110
    lw   $a2, land_sfx_instrument
    lw   $a3, land_sfx_volume
    syscall

    li   $v0, 31
    li   $a0, 76              # E5
    li   $a1, 110
    lw   $a2, land_sfx_instrument
    lw   $a3, land_sfx_volume
    syscall

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
play_bump_sfx:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    li   $v0, 31
    li   $a0, 74              # D5
    li   $a1, 70
    lw   $a2, land_sfx_instrument
    li   $a3, 28
    syscall

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
play_clear_sfx:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # bright elegant chord: luxury / jewelry sparkle feel
    li   $v0, 31
    li   $a0, 72              # C5
    li   $a1, 220
    lw   $a2, clear_sfx_instrument
    lw   $a3, clear_sfx_volume
    syscall

    li   $v0, 31
    li   $a0, 76              # E5
    li   $a1, 220
    lw   $a2, clear_sfx_instrument
    lw   $a3, clear_sfx_volume
    syscall

    li   $v0, 31
    li   $a0, 79              # G5
    li   $a1, 220
    lw   $a2, clear_sfx_instrument
    lw   $a3, clear_sfx_volume
    syscall

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
play_rotate_sfx:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # short elegant shuffle / rotation sound
    li   $v0, 31
    li   $a0, 83              # B5
    li   $a1, 55
    lw   $a2, rotate_sfx_instrument
    lw   $a3, rotate_sfx_volume
    syscall

    li   $v0, 31
    li   $a0, 88              # E6
    li   $a1, 55
    lw   $a2, rotate_sfx_instrument
    lw   $a3, rotate_sfx_volume
    syscall

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

play_game_over_sfx:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # darker descending game-over cue
    li   $v0, 31
    li   $a0, 64              # E4
    li   $a1, 180
    lw   $a2, gameover_sfx_instrument
    lw   $a3, gameover_sfx_volume
    syscall

    li   $v0, 31
    li   $a0, 60              # C4
    li   $a1, 220
    lw   $a2, gameover_sfx_instrument
    lw   $a3, gameover_sfx_volume
    syscall

    li   $v0, 31
    li   $a0, 57              # A3
    li   $a1, 320
    lw   $a2, gameover_sfx_instrument
    lw   $a3, gameover_sfx_volume
    syscall

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
auto_drop_tick:
    addi $sp, $sp, -4
    sw $ra, 0($sp)              # save return address
 
    lw $t0, drop_counter
    addi $t0, $t0, 1            # drop_counter++
    sw $t0, drop_counter
 
    lw $t1, drop_delay
    slt $t2, $t0, $t1           # $t2 = 1 if counter < delay (not yet time to drop)
    bne $t2, $zero, auto_drop_done  # not time yet -> return early
 
    sw $zero, drop_counter      # reset counter for next drop cycle
    jal try_move_down           # time to drop one row
 
auto_drop_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

try_move_down:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
 
    jal can_move_down           # $v0 = 1 if cell below is empty, 0 if blocked
    beq $v0, $zero, land_column # blocked -> land the column
 
    jal erase_column
    lw $t0, column_row
    addi $t0, $t0, 1            # column_row += 1 (move down one row)
    sw $t0, column_row
    jal draw_column
 
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

land_column:
    jal play_land_sfx
    jal resolve_matches
    jal spawn_new_column

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
spawn_new_column:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

spawn_setup:
    li   $t0, 1
    sw   $t0, column_row          # top row = 1
    li   $t0, 4
    sw   $t0, column_col          # middle playable column
    sw   $zero, drop_counter      # reset gravity timer

    jal  can_spawn_column         # $v0 = 1 if spawn area is empty
    bne  $v0, $zero, spawn_draw_new

    # spawn area blocked -> enter game over screen
    jal  game_over_screen

    # after player presses R/r and game is reset,
    # try spawning again from a clean board
    j    spawn_setup

spawn_draw_new:
    jal  generate_column
    jal  draw_column

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
can_spawn_column:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
 
    lw $s0, column_row          # $s0 = starting row (1)
    lw $s1, column_col          # $s1 = spawn column (4)
    li $s2, 0                   # $s2 = i = 0 (gem index)
 
spawn_check_loop:
    beq $s2, 3, spawn_clear     # checked all 3 cells and all empty -> safe
 
    add $a0, $s0, $s2           # $a0 = row of gem i
    move $a1, $s1               # $a1 = column
    jal is_cell_empty           # $v0 = 1 if empty
    beq $v0, $zero, spawn_blocked  # occupied -> game over
 
    addi $s2, $s2, 1
    j spawn_check_loop
 
spawn_clear:
    li $v0, 1
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra
 
spawn_blocked:
    move $v0, $zero
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra

can_move_left:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
 
    lw $s0, column_row
    lw $s1, column_col
    addi $s1, $s1, -1           # candidate column = col - 1
    li $s2, 0                   # i = 0
 
left_check_loop:
    beq $s2, 3, left_clear      # all 3 cells empty -> allow move
 
    add $a0, $s0, $s2           # row of gem i
    move $a1, $s1               # candidate column
    jal is_cell_empty
    beq $v0, $zero, left_blocked
 
    addi $s2, $s2, 1
    j left_check_loop
 
left_clear:
    li $v0, 1
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra
 
left_blocked:
    move $v0, $zero
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra
    
can_move_right:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
 
    lw $s0, column_row
    lw $s1, column_col
    addi $s1, $s1, 1            # candidate column = col + 1
    li $s2, 0
 
right_check_loop:
    beq $s2, 3, right_clear
 
    add $a0, $s0, $s2
    move $a1, $s1
    jal is_cell_empty
    beq $v0, $zero, right_blocked
 
    addi $s2, $s2, 1
    j right_check_loop
 
right_clear:
    li $v0, 1
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra
 
right_blocked:
    move $v0, $zero
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra

can_move_down:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
 
    lw $t0, column_row
    lw $t1, column_col
    addi $a0, $t0, 3            # row just below the bottom gem = top_row + 3
    move $a1, $t1               # same column
    jal is_cell_empty           # $v0 = 1 if empty, 0 if blocked
 
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
is_cell_empty:
    lw $t0, ADDR_DSPL
    sll $t1, $a0, 7             # row * 128 (byte offset for this row)
    add $t0, $t0, $t1
    sll $t2, $a1, 2             # col * 4   (byte offset for this column)
    add $t0, $t0, $t2           # $t0 = address of the target pixel
    lw $t3, 0($t0)              # $t3 = color currently at this pixel
    sltiu $v0, $t3, 1           # $v0 = 1 if color < 1 (i.e. == 0, black/empty)
    jr $ra

resolve_matches:
    addi $sp, $sp, -8
    sw   $ra, 4($sp)
    sw   $s0, 0($sp)

    li   $s0, 1                # chain level starts at 1

resolve_loop:
    jal  clear_match_flags
    jal  scan_for_matches
    beq  $v0, $zero, resolve_done

    # Count how many gems are about to be cleared in this pass
    jal  count_marked_cells
    move $a0, $v0              # a0 = gems cleared this pass
    move $a1, $s0              # a1 = chain level
    jal  add_score_for_clear

    jal  play_clear_sfx
    jal  clear_marked_cells
    jal  apply_gravity

    addi $s0, $s0, 1           # next successful pass is a higher chain
    j    resolve_loop

resolve_done:
    lw   $s0, 0($sp)
    lw   $ra, 4($sp)
    addi $sp, $sp, 8
    jr   $ra

clear_match_flags:
    la $t0, match_flags         # $t0 = pointer walking through the flag array
    li $t1, 320                 # 320 words = 1280 bytes to clear
 
clear_flags_loop:
    beq $t1, $zero, clear_flags_done
    sw $zero, 0($t0)            # write 0 (no match) to this word
    addi $t0, $t0, 4            # advance to next word
    addi $t1, $t1, -1           # decrement remaining count
    j clear_flags_loop
 
clear_flags_done:
    jr $ra

scan_for_matches:
    addi $sp, $sp, -20
    sw $ra, 16($sp)
    sw $s0, 12($sp)             # $s0 = current row
    sw $s1, 8($sp)              # $s1 = current col
    sw $s2, 4($sp)              # $s2 = color of current cell (unused after call)
    sw $s3, 0($sp)              # $s3 = found_match flag (accumulated OR)
 
    li $s0, 1                   # start at row 1 (row 0 is the top wall)
    li $s3, 0                   # no match found yet
 
scan_row_loop:
    slti $t0, $s0, 31           # continue while row < 31 (row 31 is the bottom wall)
    beq $t0, $zero, scan_done
 
    li $s1, 1                   # start at col 1 (col 0 is the left wall)
 
scan_col_loop:
    slti $t0, $s1, 9            # continue while col < 9 (col 9 is the right wall)
    beq $t0, $zero, next_scan_row
 
    # Read the color of this cell; skip it if it is empty (black).
    move $a0, $s0
    move $a1, $s1
    jal get_cell_color          # $v0 = color, or 0 if empty/grey/out-of-bounds
    move $s2, $v0
    beq $s2, $zero, next_scan_col  # empty cell -> nothing to match here
 
    # Test all four directions starting from this cell.
    # direction (d_row=0, d_col=1)  → horizontal right
    move $a0, $s0
    move $a1, $s1
    li $a2, 0
    li $a3, 1
    jal check_match_direction
    or $s3, $s3, $v0            # accumulate into found_match flag
 
    # direction (d_row=1, d_col=0)  → vertical down
    move $a0, $s0
    move $a1, $s1
    li $a2, 1
    li $a3, 0
    jal check_match_direction
    or $s3, $s3, $v0
 
    # direction (d_row=1, d_col=1)  → diagonal down-right
    move $a0, $s0
    move $a1, $s1
    li $a2, 1
    li $a3, 1
    jal check_match_direction
    or $s3, $s3, $v0
 
    # direction (d_row=1, d_col=-1) → diagonal down-left
    move $a0, $s0
    move $a1, $s1
    li $a2, 1
    li $a3, -1
    jal check_match_direction
    or $s3, $s3, $v0
 
next_scan_col:
    addi $s1, $s1, 1
    j scan_col_loop
 
next_scan_row:
    addi $s0, $s0, 1
    j scan_row_loop
 
scan_done:
    move $v0, $s3               # return 1 if any match was found, 0 otherwise
    lw $s3, 0($sp)
    lw $s2, 4($sp)
    lw $s1, 8($sp)
    lw $s0, 12($sp)
    lw $ra, 16($sp)
    addi $sp, $sp, 20
    jr $ra

check_match_direction:
    addi $sp, $sp, -32
    sw $ra, 28($sp)
    sw $s0, 24($sp)             # $s0 = start row
    sw $s1, 20($sp)             # $s1 = start col
    sw $s2, 16($sp)             # $s2 = base color to match against
    sw $s3, 12($sp)             # $s3 = current row being tested
    sw $s4, 8($sp)              # $s4 = d_row
    sw $s5, 4($sp)              # $s5 = d_col
    sw $s6, 0($sp)              # $s6 = current col being tested (saved to survive jal)
 
    move $s0, $a0               # save start row
    move $s1, $a1               # save start col
    move $s4, $a2               # save d_row
    move $s5, $a3               # save d_col
 
    # Read the color of the 1st cell (the starting cell).
    move $a0, $s0
    move $a1, $s1
    jal get_cell_color          # $v0 = color of 1st cell
    move $s2, $v0               # $s2 = base color
    beq $s2, $zero, direction_no_match  # empty/grey -> no match possible
 
    # Read the color of the 2nd cell: (start + d_row, start + d_col).
    # Store the column in $s6 (a saved register) so get_cell_color cannot
    # clobber it through its use of $t0 for bounds-check scratch work.
    add $s3, $s0, $s4           # $s3 = row of 2nd cell
    add $s6, $s1, $s5           # $s6 = col of 2nd cell (safe across jal)
    move $a0, $s3
    move $a1, $s6
    jal get_cell_color          # $v0 = color of 2nd cell
    bne $v0, $s2, direction_no_match  # different color -> no match
 
    # Read the color of the 3rd cell: (start + 2*d_row, start + 2*d_col).
    add $s3, $s3, $s4           # $s3 = row of 3rd cell
    add $s6, $s6, $s5           # $s6 = col of 3rd cell (still valid in saved reg)
    move $a0, $s3
    move $a1, $s6
    jal get_cell_color          # $v0 = color of 3rd cell
    bne $v0, $s2, direction_no_match  # different color -> no match
 
    # All three cells match: flag them all in match_flags.
    move $a0, $s0               # flag 1st cell
    move $a1, $s1
    jal mark_match_cell
 
    add $a0, $s0, $s4           # flag 2nd cell: start + (d_row, d_col)
    add $a1, $s1, $s5
    jal mark_match_cell
 
    sll $t1, $s4, 1             # 2 * d_row
    sll $t2, $s5, 1             # 2 * d_col
    add $a0, $s0, $t1           # flag 3rd cell: start + 2*(d_row, d_col)
    add $a1, $s1, $t2
    jal mark_match_cell
 
    li $v0, 1                   # report that a match was found
    j direction_done
 
direction_no_match:
    move $v0, $zero             # report no match
 
direction_done:
    lw $s6, 0($sp)
    lw $s5, 4($sp)
    lw $s4, 8($sp)
    lw $s3, 12($sp)
    lw $s2, 16($sp)
    lw $s1, 20($sp)
    lw $s0, 24($sp)
    lw $ra, 28($sp)
    addi $sp, $sp, 32
    jr $ra

get_cell_color:
    addi $sp, $sp, -4
    sw $ra, 0($sp)              # save $ra because we call display_cell_address below
 
    # Bounds-check: reject anything outside the playable area rows 1-30, cols 1-8.
    slti $t0, $a0, 1
    bne $t0, $zero, get_cell_invalid    # row < 1 -> out of bounds
    slti $t0, $a0, 31
    beq $t0, $zero, get_cell_invalid    # row >= 31 -> out of bounds
    slti $t0, $a1, 1
    bne $t0, $zero, get_cell_invalid    # col < 1 -> out of bounds
    slti $t0, $a1, 9
    beq $t0, $zero, get_cell_invalid    # col >= 9 -> out of bounds
 
    jal display_cell_address    # $v0 = bitmap address of (row, col)
    lw $v0, 0($v0)              # $v0 = color currently painted at this cell
    lw $t0, GREY
    beq $v0, $t0, get_cell_invalid  # grey border cell -> treat as empty
 
    lw $ra, 0($sp)              # restore $ra and return the color
    addi $sp, $sp, 4
    jr $ra
 
get_cell_invalid:
    move $v0, $zero             # return 0 to signal empty / out-of-bounds
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

mark_match_cell:
    addi $sp, $sp, -4
    sw $ra, 0($sp)              # save $ra because we call match_flag_address
    jal match_flag_address      # $v0 = address of flag for (row, col)
    li $t0, 1
    sw $t0, 0($v0)              # set the flag to 1 (matched)
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

clear_marked_cells:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)              # $s0 = current row
    sw $s1, 4($sp)              # $s1 = current col
    sw $s2, 0($sp)              # $s2 = flag value for this cell
 
    li $s0, 1                   # start at row 1
 
clear_marked_row_loop:
    slti $t0, $s0, 31           # continue while row < 31
    beq $t0, $zero, clear_marked_done
 
    li $s1, 1                   # start at col 1
 
clear_marked_col_loop:
    slti $t0, $s1, 9            # continue while col < 9
    beq $t0, $zero, clear_marked_next_row
 
    # Check whether this cell was flagged as part of a match.
    move $a0, $s0
    move $a1, $s1
    jal match_flag_address      # $v0 = address of flag for (row, col)
    lw $s2, 0($v0)              # $s2 = flag value (0 or 1)
    beq $s2, $zero, clear_marked_next_col  # not flagged -> skip
 
    # Flagged: erase this cell from the bitmap by writing black.
    move $a0, $s0
    move $a1, $s1
    jal display_cell_address    # $v0 = bitmap address of (row, col)
    sw $zero, 0($v0)            # write 0 (black) to erase the gem
 
clear_marked_next_col:
    addi $s1, $s1, 1
    j clear_marked_col_loop
 
clear_marked_next_row:
    addi $s0, $s0, 1
    j clear_marked_row_loop
 
clear_marked_done:
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra

apply_gravity:
    addi $sp, $sp, -20
    sw $ra, 16($sp)
    sw $s0, 12($sp)             # $s0 = current column being compacted
    sw $s1, 8($sp)              # $s1 = write_row (next empty slot from the bottom)
    sw $s2, 4($sp)              # $s2 = read_row  (scanner moving upward)
    sw $s3, 0($sp)              # $s3 = color of gem at read_row
 
    li $s0, 1                   # process columns 1 through 8
 
gravity_col_loop:
    slti $t0, $s0, 9            # continue while col < 9
    beq $t0, $zero, gravity_done
 
    li $s1, 30                  # write_row starts at bottom of playable area (row 30)
    li $s2, 30                  # read_row also starts at row 30
 
gravity_read_loop:
    beq $s2, $zero, gravity_fill_loop  # finished reading -> fill remaining cells black
 
    # Read the color at the current read position.
    move $a0, $s2
    move $a1, $s0
    jal display_cell_address    # $v0 = bitmap address of (read_row, col)
    lw $s3, 0($v0)              # $s3 = color at this cell
    beq $s3, $zero, gravity_next_read  # empty (black) -> skip, keep scanning upward
 
    # Found a gem.  If it is already at the write position, leave it in place.
    beq $s1, $s2, gravity_keep_cell
 
    # Otherwise move it down to write_row and clear the old location.
    move $a0, $s1
    move $a1, $s0
    jal display_cell_address    # address of write position
    sw $s3, 0($v0)              # paint gem at new (lower) position
 
    move $a0, $s2
    move $a1, $s0
    jal display_cell_address    # address of old (read) position
    sw $zero, 0($v0)            # clear old position
 
gravity_keep_cell:
    addi $s1, $s1, -1           # write_row moves up by one
 
gravity_next_read:
    addi $s2, $s2, -1           # read_row moves up by one
    j gravity_read_loop
 
gravity_fill_loop:
    # Clear any cells above write_row that were not filled (top of column).
    beq $s1, $zero, gravity_next_col  # nothing left to clear
 
    move $a0, $s1
    move $a1, $s0
    jal display_cell_address    # address of this leftover cell
    sw $zero, 0($v0)            # clear it
    addi $s1, $s1, -1           # move write_row upward
    j gravity_fill_loop
 
gravity_next_col:
    addi $s0, $s0, 1            # advance to next column
    j gravity_col_loop
 
gravity_done:
    lw $s3, 0($sp)
    lw $s2, 4($sp)
    lw $s1, 8($sp)
    lw $s0, 12($sp)
    lw $ra, 16($sp)
    addi $sp, $sp, 20
    jr $ra

display_cell_address:
    lw $t0, ADDR_DSPL           # $t0 = base address of bitmap display
    sll $t1, $a0, 7             # $t1 = row * 128  (each row is 32 words = 128 bytes)
    add $t0, $t0, $t1
    sll $t2, $a1, 2             # $t2 = col * 4    (each cell is one word = 4 bytes)
    add $v0, $t0, $t2           # $v0 = final address
    jr $ra
paint_cell_color:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    jal  display_cell_address
    sw   $a2, 0($v0)

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
draw_glyph_3x5:
    addi $sp, $sp, -32
    sw   $ra, 28($sp)
    sw   $s0, 24($sp)
    sw   $s1, 20($sp)
    sw   $s2, 16($sp)
    sw   $s3, 12($sp)
    sw   $s4, 8($sp)
    sw   $s5, 4($sp)
    sw   $s6, 0($sp)

    move $s0, $a0      # start row
    move $s1, $a1      # start col
    move $s2, $a2      # glyph address
    move $s3, $a3      # color

    li   $s4, 0        # row index = 0

glyph_row_loop:
    beq  $s4, 5, glyph_done

    sll  $t0, $s4, 2
    add  $t0, $s2, $t0
    lw   $s5, 0($t0)   # row bit pattern

    li   $s6, 0        # col index = 0

glyph_col_loop:
    beq  $s6, 3, glyph_next_row

    li   $t1, 2
    sub  $t1, $t1, $s6
    li   $t2, 1
    sllv $t2, $t2, $t1
    and  $t3, $s5, $t2
    beq  $t3, $zero, glyph_skip_cell

    add  $a0, $s0, $s4
    add  $a1, $s1, $s6
    move $a2, $s3
    jal  paint_cell_color

glyph_skip_cell:
    addi $s6, $s6, 1
    j    glyph_col_loop

glyph_next_row:
    addi $s4, $s4, 1
    j    glyph_row_loop

glyph_done:
    lw   $s6, 0($sp)
    lw   $s5, 4($sp)
    lw   $s4, 8($sp)
    lw   $s3, 12($sp)
    lw   $s2, 16($sp)
    lw   $s1, 20($sp)
    lw   $s0, 24($sp)
    lw   $ra, 28($sp)
    addi $sp, $sp, 32
    jr   $ra
draw_wide_M_5x5:
    addi $sp, $sp, -16
    sw   $ra, 12($sp)
    sw   $s0, 8($sp)
    sw   $s1, 4($sp)
    sw   $s2, 0($sp)

    move $s0, $a0      # start row
    move $s1, $a1      # start col
    move $s2, $a2      # color

    # Row 0: 10001
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal  paint_cell_color

    move $a0, $s0
    addi $a1, $s1, 4
    move $a2, $s2
    jal  paint_cell_color

    # Row 1: 11011
    addi $a0, $s0, 1
    move $a1, $s1
    move $a2, $s2
    jal  paint_cell_color

    addi $a0, $s0, 1
    addi $a1, $s1, 1
    move $a2, $s2
    jal  paint_cell_color

    addi $a0, $s0, 1
    addi $a1, $s1, 3
    move $a2, $s2
    jal  paint_cell_color

    addi $a0, $s0, 1
    addi $a1, $s1, 4
    move $a2, $s2
    jal  paint_cell_color

    # Row 2: 10101
    addi $a0, $s0, 2
    move $a1, $s1
    move $a2, $s2
    jal  paint_cell_color

    addi $a0, $s0, 2
    addi $a1, $s1, 2
    move $a2, $s2
    jal  paint_cell_color

    addi $a0, $s0, 2
    addi $a1, $s1, 4
    move $a2, $s2
    jal  paint_cell_color

    # Row 3: 10001
    addi $a0, $s0, 3
    move $a1, $s1
    move $a2, $s2
    jal  paint_cell_color

    addi $a0, $s0, 3
    addi $a1, $s1, 4
    move $a2, $s2
    jal  paint_cell_color

    # Row 4: 10001
    addi $a0, $s0, 4
    move $a1, $s1
    move $a2, $s2
    jal  paint_cell_color

    addi $a0, $s0, 4
    addi $a1, $s1, 4
    move $a2, $s2
    jal  paint_cell_color

    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addi $sp, $sp, 16
    jr   $ra
draw_paused_message:
    addi $sp, $sp, -8
    sw   $ra, 4($sp)
    sw   $s0, 0($sp)

    jal  clear_paused_message
    lw   $s0, PAUSE_RED

    # Draw "PAUSE" in the right black area, away from the gold border
    li   $a0, 8
    li   $a1, 12
    la   $a2, GLYPH_P
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 8
    li   $a1, 16
    la   $a2, GLYPH_A
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 8
    li   $a1, 20
    la   $a2, GLYPH_U
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 8
    li   $a1, 24
    la   $a2, GLYPH_S
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 8
    li   $a1, 28
    la   $a2, GLYPH_E
    move $a3, $s0
    jal  draw_glyph_3x5

    lw   $s0, 0($sp)
    lw   $ra, 4($sp)
    addi $sp, $sp, 8
    jr   $ra
clear_paused_message:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)

    li   $s0, 7               # start row

clear_pause_row_loop:
    li   $t0, 15              # end row (exclusive)
    beq  $s0, $t0, clear_pause_done

    li   $s1, 12              # start col

clear_pause_col_loop:
    li   $t0, 31              # end col (exclusive)
    beq  $s1, $t0, clear_pause_next_row

    move $a0, $s0
    move $a1, $s1
    jal  display_cell_address
    sw   $zero, 0($v0)

    addi $s1, $s1, 1
    j    clear_pause_col_loop

clear_pause_next_row:
    addi $s0, $s0, 1
    j    clear_pause_row_loop

clear_pause_done:
    lw   $s1, 0($sp)
    lw   $s0, 4($sp)
    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra
init_score_state:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    sw   $zero, score_value
    jal  draw_score_panel

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


count_marked_cells:
    addi $sp, $sp, -12
    sw   $s0, 8($sp)
    sw   $s1, 4($sp)
    sw   $ra, 0($sp)

    la   $s0, match_flags
    li   $s1, 320          # full 32x10 flag array
    move $v0, $zero        # count = 0

count_marked_loop:
    beq  $s1, $zero, count_marked_done

    lw   $t0, 0($s0)
    beq  $t0, $zero, count_marked_next
    addi $v0, $v0, 1

count_marked_next:
    addi $s0, $s0, 4
    addi $s1, $s1, -1
    j    count_marked_loop

count_marked_done:
    lw   $ra, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    addi $sp, $sp, 12
    jr   $ra


add_score_for_clear:
    # a0 = number of gems cleared in this pass
    # a1 = chain level (1 for first clear, 2+ for chain reactions)
    addi $sp, $sp, -8
    sw   $s0, 4($sp)
    sw   $ra, 0($sp)

    # t1 = gems_cleared * score_base_per_gem
    lw   $t0, score_base_per_gem
    mult $a0, $t0
    mflo $t1

    # t1 *= difficulty_multiplier
    lw   $t2, difficulty_multiplier
    mult $t1, $t2
    mflo $t1

    # t1 *= chain_level
    mult $t1, $a1
    mflo $t1

    # score_value += t1
    lw   $s0, score_value
    addu $s0, $s0, $t1
    sw   $s0, score_value

    jal  draw_score_panel

    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    addi $sp, $sp, 8
    jr   $ra


clear_score_panel:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)

    # 只清右侧 score 区域，合法列只能到 31
    li   $s0, 19              # start row

clear_score_row_loop:
    li   $t0, 31              # end row (exclusive)
    beq  $s0, $t0, clear_score_done

    li   $s1, 10              # start col，避开游戏墙(col 9)

clear_score_col_loop:
    li   $t0, 32              # end col (exclusive), 最大只能到 31
    beq  $s1, $t0, clear_score_next_row

    move $a0, $s0
    move $a1, $s1
    jal  display_cell_address
    sw   $zero, 0($v0)

    addi $s1, $s1, 1
    j    clear_score_col_loop

clear_score_next_row:
    addi $s0, $s0, 1
    j    clear_score_row_loop

clear_score_done:
    lw   $s1, 0($sp)
    lw   $s0, 4($sp)
    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_digit_at:
    # a0 = row, a1 = col, a2 = digit(0..9), a3 = color
    addi $sp, $sp, -20
    sw   $ra, 16($sp)
    sw   $s0, 12($sp)
    sw   $s1, 8($sp)
    sw   $s2, 4($sp)
    sw   $s3, 0($sp)

    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    move $s3, $a3

    la   $t0, digit_glyph_table
    sll  $t1, $s2, 2
    add  $t0, $t0, $t1
    lw   $t2, 0($t0)          # address of the digit glyph

    move $a0, $s0
    move $a1, $s1
    move $a2, $t2
    move $a3, $s3
    jal  draw_glyph_3x5

    lw   $s3, 0($sp)
    lw   $s2, 4($sp)
    lw   $s1, 8($sp)
    lw   $s0, 12($sp)
    lw   $ra, 16($sp)
    addi $sp, $sp, 20
    jr   $ra


draw_score_panel:
    addi $sp, $sp, -36
    sw   $ra, 32($sp)
    sw   $s0, 28($sp)
    sw   $s1, 24($sp)
    sw   $s2, 20($sp)
    sw   $s3, 16($sp)
    sw   $s4, 12($sp)
    sw   $s5, 8($sp)
    sw   $s6, 4($sp)
    sw   $s7, 0($sp)

    jal  clear_score_panel

    # SCORE 字母颜色 = 高级蓝
    lw   $s0, LUXURY_BLUE

    # Draw "SCORE"
    li   $a0, 20
    li   $a1, 12
    la   $a2, GLYPH_S
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 20
    li   $a1, 16
    la   $a2, GLYPH_C
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 20
    li   $a1, 20
    la   $a2, GLYPH_O
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 20
    li   $a1, 24
    la   $a2, GLYPH_R
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 20
    li   $a1, 28
    la   $a2, GLYPH_E
    move $a3, $s0
    jal  draw_glyph_3x5

    # 数字颜色 = 纯白
    lw   $s1, PURE_WHITE

    # break score_value into 5 decimal digits
    lw   $t0, score_value

    li   $t1, 10000
    divu $t0, $t1
    mflo $s2
    mfhi $t0

    li   $t1, 1000
    divu $t0, $t1
    mflo $s3
    mfhi $t0

    li   $t1, 100
    divu $t0, $t1
    mflo $s4
    mfhi $t0

    li   $t1, 10
    divu $t0, $t1
    mflo $s5
    mfhi $s6

    # Draw 5 digits
    # 注意：最后一个数字起点最多只能是 28，
    # 因为 28,29,30 这三列才不会越界。
    li   $a0, 26
    li   $a1, 12
    move $a2, $s2
    move $a3, $s1
    jal  draw_digit_at

    li   $a0, 26
    li   $a1, 16
    move $a2, $s3
    move $a3, $s1
    jal  draw_digit_at

    li   $a0, 26
    li   $a1, 20
    move $a2, $s4
    move $a3, $s1
    jal  draw_digit_at

    li   $a0, 26
    li   $a1, 24
    move $a2, $s5
    move $a3, $s1
    jal  draw_digit_at

    li   $a0, 26
    li   $a1, 28
    move $a2, $s6
    move $a3, $s1
    jal  draw_digit_at

    lw   $s7, 0($sp)
    lw   $s6, 4($sp)
    lw   $s5, 8($sp)
    lw   $s4, 12($sp)
    lw   $s3, 16($sp)
    lw   $s2, 20($sp)
    lw   $s1, 24($sp)
    lw   $s0, 28($sp)
    lw   $ra, 32($sp)
    addi $sp, $sp, 36
    jr   $ra
draw_game_over_message:
    addi $sp, $sp, -8
    sw   $ra, 4($sp)
    sw   $s0, 0($sp)

    # GAME OVER in deep red
    lw   $s0, PAUSE_RED

    # G
    li   $a0, 8
    li   $a1, 12
    la   $a2, GLYPH_G
    move $a3, $s0
    jal  draw_glyph_3x5

    # A
    li   $a0, 8
    li   $a1, 16
    la   $a2, GLYPH_A
    move $a3, $s0
    jal  draw_glyph_3x5

    # wide M
    li   $a0, 8
    li   $a1, 20
    move $a2, $s0
    jal  draw_wide_M_5x5

    # E
    li   $a0, 8
    li   $a1, 27
    la   $a2, GLYPH_E
    move $a3, $s0
    jal  draw_glyph_3x5

    # O
    li   $a0, 15
    li   $a1, 14
    la   $a2, GLYPH_O
    move $a3, $s0
    jal  draw_glyph_3x5

    # V
    li   $a0, 15
    li   $a1, 18
    la   $a2, GLYPH_V
    move $a3, $s0
    jal  draw_glyph_3x5

    # E
    li   $a0, 15
    li   $a1, 22
    la   $a2, GLYPH_E
    move $a3, $s0
    jal  draw_glyph_3x5

    # R
    li   $a0, 15
    li   $a1, 26
    la   $a2, GLYPH_R
    move $a3, $s0
    jal  draw_glyph_3x5

    # bottom: only one R
    lw   $s0, GREY

    li   $a0, 24
    li   $a1, 20
    la   $a2, GLYPH_R
    move $a3, $s0
    jal  draw_glyph_3x5

    lw   $s0, 0($sp)
    lw   $ra, 4($sp)
    addi $sp, $sp, 8
    jr   $ra

match_flag_address:
    la $t0, match_flags         # $t0 = base address of the flag array
    sll $t1, $a0, 5             # row * 32
    sll $t2, $a0, 3             # row * 8
    add $t1, $t1, $t2           # row * 32 + row * 8 = row * 40
    add $t0, $t0, $t1           # advance base by row offset
    sll $t2, $a1, 2             # col * 4
    add $v0, $t0, $t2           # $v0 = base + row offset + col offset
    jr $ra

erase_column:
    lw $t0, ADDR_DSPL          # $t0 = base display address
    lw $t1, column_row         # $t1 = current top-gem row
    lw $t2, column_col         # $t2 = current column
    li $t3, 0                  # $t3 = i = 0 (loop counter)
 
erase_loop:
    beq $t3, 3, erase_done     # painted all 3 gems, stop
 
    sll $t4, $t1, 7            # $t4 = row * 128 (byte offset for this row)
    add $t5, $t0, $t4          # $t5 = display base + row offset
    sll $t6, $t2, 2            # $t6 = col * 4 (byte offset for this col)
    add $t5, $t5, $t6          # $t5 = address of this gem cell
 
    sw $zero, 0($t5)           # write black (0) to erase the gem
 
    addi $t1, $t1, 1           # move to next row (gem below)
    addi $t3, $t3, 1           # i++
    j erase_loop
 
erase_done:
    jr $ra

generate_column:
    li   $t0, 0                  # i = 0

gen_loop:
    beq  $t0, 3, gen_done

    # random integer in [0, gem_palette_count)
    li   $v0, 42
    li   $a0, 0
    lw   $a1, gem_palette_count
    syscall
    move $t1, $a0               # random index

    # load gem_palette[random_index]
    la   $t2, gem_palette
    sll  $t3, $t1, 2
    add  $t2, $t2, $t3
    lw   $t4, 0($t2)            # chosen appearance colour

    # store into column_colors[i]
    la   $t5, column_colors
    sll  $t6, $t0, 2
    add  $t5, $t5, $t6
    sw   $t4, 0($t5)

    addi $t0, $t0, 1
    j    gen_loop

gen_done:
    jr   $ra
draw_column:
    lw $t0, ADDR_DSPL       # $t0 = base address of display

    lw $t1, column_row      # $t1 = current row
    lw $t2, column_col      # $t2 = current column
    li $t3, 0               # $t3 = i = 0 (loop counter)

draw_loop:
    beq $t3, 3, done

    sll $t4, $t1, 7         # update $t4 to store vertical offset
    add $t5, $t0, $t4       # add this vertical offset, update the current address in $t5
    sll $t6, $t2, 2         # update $t6 to store vertical offset
    add $t5, $t5, $t6       # add this horizontal offset, update the current address in $t5

    la $t7, column_colors   # $t7 = base address of column_colors array
    sll $t8, $t3, 2         # $t4 = i * 4 (convert index to byte offset)
    add $t7, $t7, $t8       # $t7 = address of column_colors[i]
    lw $t9, 0($t7)          # load color into $t9

    sw $t9, 0($t5)

    addi $t1, $t1, 1        # move down
    addi $t3, $t3, 1        # i++
    j draw_loop

done:
    jr $ra
    

fill_black_background:
    lw   $t0, ADDR_DSPL      # display base
    li   $t1, 1024           # 256x256, one word per 8x8 unit => 32*32 = 1024 cells

fill_black_loop:
    beq  $t1, $zero, fill_black_done
    sw   $zero, 0($t0)       # write black
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    j    fill_black_loop

fill_black_done:
    jr   $ra
draw_borders:
    lw $t0, ADDR_DSPL      # $t0 = base address
    lw $t9, GREY           # gold border color
##################################################
# TOP WALL (row = 0, col 0 → row = 0, col 9)
##################################################
    li $t1, 0              # row = 0
    li $t2, 0              # start col = 0

    sll $t5, $t1, 7        # update $t5 to store vertical offset
    add $t3, $t0, $t5      # add this vertical offset, update the current address in $t3
    sll $t6, $t2, 2        # update $t6 to store horizontal offset
    add $t3, $t3, $t6      # add this horizontal offset, update the current address in $t3

    li $t2, 9              # end col = 9
    sll $t6, $t2, 2
    add $t4, $t0, $t5      # update $t4 to store the final pixel address
    add $t4, $t4, $t6  

top_loop:
    beq $t3, $t4, top_end
    sw $t9, 0($t3)
    addi $t3, $t3, 4       # move right
    j top_loop
top_end:
    sw $t9, 0($t3)

##################################################
# BOTTOM WALL (row = 31, col 0 → row = 31, col = 9)
##################################################
    li $t1, 31             # row = 31

    sll $t5, $t1, 7
    add $t3, $t0, $t5
    li $t2, 0              # start col = 0
    sll $t6, $t2, 2
    add $t3, $t3, $t6

    li $t2, 9              # end col = 9
    sll $t6, $t2, 2
    add $t4, $t0, $t5
    add $t4, $t4, $t6

bottom_loop:
    beq $t3, $t4, bottom_end
    sw $t9, 0($t3)
    addi $t3, $t3, 4
    j bottom_loop
bottom_end:
    sw $t9, 0($t3)

##################################################
# LEFT WALL (row = 0, col = 0 → row = 31, col = 0)
##################################################
    li $t1, 0              # start row = 0
    li $t2, 0              # col = 0

    sll $t5, $t1, 7
    add $t3, $t0, $t5
    sll $t6, $t2, 2
    add $t3, $t3, $t6

    li $t1, 31             # end row = 31
    sll $t5, $t1, 7
    add $t4, $t0, $t5
    sll $t6, $t2, 2
    add $t4, $t4, $t6

left_loop:
    beq $t3, $t4, left_end
    sw $t9, 0($t3)
    addi $t3, $t3, 128     # move down
    j left_loop
left_end:
    sw $t9, 0($t3)

##################################################
# RIGHT WALL (row = 0, col = 9 → row = 31, col = 9)
##################################################
    li $t1, 0              # start row = 0
    li $t2, 9              # col = 9

    sll $t5, $t1, 7
    add $t3, $t0, $t5
    sll $t6, $t2, 2
    add $t3, $t3, $t6

    li $t1, 31            # end row = 31
    sll $t5, $t1, 7
    add $t4, $t0, $t5
    sll $t6, $t2, 2
    add $t4, $t4, $t6

right_loop:
    beq $t3, $t4, right_end
    sw $t9, 0($t3)
    addi $t3, $t3, 128
    j right_loop
right_end:
    sw $t9, 0($t3)

    jr $ra                # return to main