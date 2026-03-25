################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Chuning Li, 1010880290
# Student 2: Wenzhao Li  1011425290
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
######################## Playing Area Configuration ##########################
# - The game board is surrounded by grey border walls.
# - Playable rows range from 1 to 30.
# - Playable columns range from 1 to 8.
# - Row 0 is the top wall.
# - Row 31 is the bottom wall.
# - Column 0 is the left wall.
# - Column 9 is the right wall.
# - Each new falling column begins at row 1, column 4
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
RED:           .word 0x6e0f1f
GREEN:         .word 0x0f5c4a
BLUE:          .word 0x1c2f5a
YELLOW:        .word 0xd4af37
CYAN:          .word 0xf5f0e6
MAGENTA:       .word 0xb76e79
LUXURY_BLUE:   .word 0x001a2e
PURE_WHITE:    .word 0xffffff
GREY:          .word 0xe5c76b
PAUSE_RED:     .word 0xb11226

##############################################################################
# Luxury 6-color gem palette
##############################################################################
gem_palette_count: .word 6
gem_palette:
    .word 0x6e0f1f
    .word 0x0f5c4a
    .word 0x1c2f5a
    .word 0xd4af37
    .word 0xf5f0e6
    .word 0xb76e79

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

# Number of ticks must pass before the column auto-drops one row.
drop_delay:    .word 30

# Space used to record pixels that are part of a match before clearing.
# Total space needed: 32 rows * 10 cols * 4 bytes/pixel = 1280 bytes.
match_flags:   .space 1280

##############################################################################
# Background music state
##############################################################################
music_enabled:    .word 1
music_index:      .word 0
music_wait:       .word 0
music_length:     .word 16
music_instrument: .word 0
music_volume:     .word 48

music_pitches:
    .word 69, 72, 76, 79, 76, 72, -1, 67
    .word 69, 72, 76, 81, 79, 76, 74, 72

music_durations:
    .word 192, 192, 192, 256, 192, 192, 128, 256
    .word 192, 192, 192, 256, 192, 192, 192, 320

music_wait_frames:
    .word 12, 12, 12, 16, 12, 12, 8, 16
    .word 12, 12, 12, 16, 12, 12, 12, 20

##############################################################################
# Sound effects
##############################################################################
land_sfx_instrument:      .word 0
land_sfx_volume:          .word 42
clear_sfx_instrument:     .word 48
clear_sfx_volume:         .word 56
rotate_sfx_instrument:    .word 0
rotate_sfx_volume:        .word 34
gameover_sfx_instrument:  .word 48
gameover_sfx_volume:      .word 62

##############################################################################
# Pause state / glyphs
##############################################################################
paused_flag: .word 0

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
difficulty_multiplier:  .word 1
score_base_per_gem:     .word 10

##############################################################################
# Code
##############################################################################
 .text
 .globl main

    # Run the game.
main:
    jal fill_black_background
    jal draw_borders          # draw grey borders
    jal init_music
    jal init_score_state
    jal generate_new_column   # generate the first falling column and draw it

game_loop:
    li $v0, 32                # sleep for 16 ms (~60 FPS)
    li $a0, 16
    syscall

    jal music_tick
    jal auto_drop_tick        # advance the gravity timer; may drop the column

    lw $t0, ADDR_KBRD         # $t0 = keyboard base address
    lw $t1, 0($t0)            # $t1 = first word (1 if key pressed, 0 otherwise)

    beq $t1, 1, key_pressed   # if key pressed, handle input

    j game_loop

key_pressed:
    lw $t2, 4($t0)            # $t2 = ASCII value of pressed key

    beq $t2, 0x61, move_left    # if 'a', move left
    beq $t2, 0x64, move_right   # if 'd', move right
    beq $t2, 0x77, rotate       # if 'w', rotate colors
    beq $t2, 0x73, move_down    # if 's', move down
    beq $t2, 0x70, toggle_pause # if 'p', pause / resume
    beq $t2, 0x71, quit_game    # if 'q', quit program

    j game_loop

move_left:
    la $t0, column_col         # load address of column_col
    lw $t1, 0($t0)             # $t1 = current column position
    beq $t1, 1, left_bump      # if at left boundary (col=1), stop

    jal can_move_left           # $v0 = 1 if space is free, 0 if occupied
    beq $v0, $zero, left_bump

    jal erase_column           # erase pixels at current position
    lw $t1, column_col         # reload col
    addi $t1, $t1, -1          # column = column - 1 (move left)
    sw $t1, column_col         # save new col to memory
    jal draw_column            # draw pixels at new position
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
    la $t0, column_colors      # $t0 = base address of column_colors array

    lw $t1, 0($t0)             # $t1 = top color
    lw $t2, 4($t0)             # $t2 = middle color
    lw $t3, 8($t0)             # $t3 = bottom color

    sw $t3, 0($t0)             # shift down by one
    sw $t1, 4($t0)
    sw $t2, 8($t0)

    jal play_rotate_sfx
    jal erase_column           # erase gems at current position
    jal draw_column            # redraw with rotated colors
    j game_loop

quit_game:
    li $v0, 10
    syscall

toggle_pause:
    li   $t0, 1
    sw   $t0, paused_flag
    jal  draw_paused_message
    jal  wait_key_release

pause_loop:
    li   $v0, 32
    li   $a0, 16
    syscall
    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    beq  $t1, $zero, pause_loop
    lw   $t2, 4($t0)
    bne  $t2, 0x70, pause_loop
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
    beq  $t2, 0x72, retry_game
    beq  $t2, 0x52, retry_game
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
    lw   $t0, music_enabled
    beq  $t0, $zero, music_tick_done
    lw   $t0, music_wait
    beq  $t0, $zero, music_play_next
    addi $t0, $t0, -1
    sw   $t0, music_wait
    j    music_tick_done

music_play_next:
    lw   $t0, music_index
    sll  $t1, $t0, 2
    la   $t2, music_pitches
    add  $t2, $t2, $t1
    lw   $t3, 0($t2)
    la   $t2, music_durations
    add  $t2, $t2, $t1
    lw   $t4, 0($t2)
    la   $t2, music_wait_frames
    add  $t2, $t2, $t1
    lw   $t5, 0($t2)
    sw   $t5, music_wait
    bltz $t3, music_advance_index
    li   $v0, 31
    move $a0, $t3
    move $a1, $t4
    lw   $a2, music_instrument
    lw   $a3, music_volume
    syscall

music_advance_index:
    lw   $t0, music_index
    addi $t0, $t0, 1
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
    li   $v0, 31
    li   $a0, 69
    li   $a1, 110
    lw   $a2, land_sfx_instrument
    lw   $a3, land_sfx_volume
    syscall
    li   $v0, 31
    li   $a0, 76
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
    li   $a0, 74
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
    li   $v0, 31
    li   $a0, 72
    li   $a1, 220
    lw   $a2, clear_sfx_instrument
    lw   $a3, clear_sfx_volume
    syscall
    li   $v0, 31
    li   $a0, 76
    li   $a1, 220
    lw   $a2, clear_sfx_instrument
    lw   $a3, clear_sfx_volume
    syscall
    li   $v0, 31
    li   $a0, 79
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
    li   $v0, 31
    li   $a0, 83
    li   $a1, 55
    lw   $a2, rotate_sfx_instrument
    lw   $a3, rotate_sfx_volume
    syscall
    li   $v0, 31
    li   $a0, 88
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
    li   $v0, 31
    li   $a0, 64
    li   $a1, 180
    lw   $a2, gameover_sfx_instrument
    lw   $a3, gameover_sfx_volume
    syscall
    li   $v0, 31
    li   $a0, 60
    li   $a1, 220
    lw   $a2, gameover_sfx_instrument
    lw   $a3, gameover_sfx_volume
    syscall
    li   $v0, 31
    li   $a0, 57
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
    slt $t2, $t0, $t1
    bne $t2, $zero, auto_drop_done

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
    beq $v0, $zero, land_column # if blocked, land the column

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
    jal resolve_matches            # clear any 3-in-a-row matches and apply gravity
    jal generate_new_column        # start a new falling column at the top

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

generate_new_column:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

generate_setup:
    li $t0, 1
    sw $t0, column_row          # reset to top of playing field (row 1)
    li $t0, 4
    sw $t0, column_col          # reset to center column (col 4)
    sw $zero, drop_counter      # restart the gravity timer from 0

    jal can_generate_column     # $v0 = 1 if the area to generate column is clear, 0 if blocked
    bne $v0, $zero, generate_draw_new

    jal game_over_screen
    j generate_setup

generate_draw_new:
    jal generate_column         # pick 3 new random colors into column_colors
    jal draw_column             # draw the new column on the display

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

can_generate_column:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)

    lw $s0, column_row          # $s0 = starting row (1)
    lw $s1, column_col          # $s1 = column (4)
    li $s2, 0                   # $s2 = i = 0 (pixel index)

generate_check_loop:
    beq $s2, 3, clear           # checked all 3 cells and if all empty, safe

    add $a0, $s0, $s2           # $a0 = row of pixel i
    move $a1, $s1               # $a1 = column
    jal is_cell_empty           # $v0 = 1 if empty
    beq $v0, $zero, blocked     # if occupied, game over

    addi $s2, $s2, 1
    j generate_check_loop

clear:
    li $v0, 1
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra

blocked:
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

left_check_LOOP:
    beq $s2, 3, left_clear      # if all 3 cells empty, allow move

    add $a0, $s0, $s2           # row of pixel i
    move $a1, $s1               # candidate column
    jal is_cell_empty
    beq $v0, $zero, left_blocked

    addi $s2, $s2, 1
    j left_check_LOOP

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
    addi $a0, $t0, 3            # row just below the bottom pixel = top row + 3
    move $a1, $t1               # same column
    jal is_cell_empty           # $v0 = 1 if empty, 0 if blocked

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

is_cell_empty:
    lw $t0, ADDR_DSPL
    sll $t1, $a0, 7             # vertical offset
    add $t0, $t0, $t1
    sll $t2, $a1, 2             # horizontal offset
    add $t0, $t0, $t2           # $t0 = address of the target pixel
    lw $t3, 0($t0)              # $t3 = color currently at this pixel
    sltiu $v0, $t3, 1           # $v0 = 1 if color < 1 (black/empty)
    jr $ra

resolve_matches:
    addi $sp, $sp, -8
    sw   $ra, 4($sp)
    sw   $s0, 0($sp)

    li   $s0, 1

resolve_loop:
    jal  clear_match_flags
    jal  scan_for_matches
    beq  $v0, $zero, resolve_done
    jal  count_marked_cells
    move $a0, $v0
    move $a1, $s0
    jal  add_score_for_clear
    jal  play_clear_sfx
    jal  clear_marked_cells
    jal  apply_gravity
    addi $s0, $s0, 1
    j    resolve_loop

resolve_done:
    lw   $s0, 0($sp)
    lw   $ra, 4($sp)
    addi $sp, $sp, 8
    jr   $ra

clear_match_flags:
    la $t0, match_flags         # $t0 = pointer to the flag array
    li $t1, 320                 # 320 words = 1280 bytes to clear

clear_flags_loop:
    beq $t1, $zero, clear_flags_done
    sw $zero, 0($t0)            # write 0 to this word
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
    sw $s2, 4($sp)              # $s2 = color of current cell
    sw $s3, 0($sp)              # $s3 = found_match flag

    li $s0, 1                   # start at row 1
    li $s3, 0                   # no match found yet

scan_row_loop:
    slti $t0, $s0, 31           # continue while row < 31
    beq $t0, $zero, scan_done

    li $s1, 1                   # start at col 1

scan_col_loop:
    slti $t0, $s1, 9            # continue while col < 9
    beq $t0, $zero, next_scan_row

    move $a0, $s0
    move $a1, $s1
    jal get_cell_color          # $v0 = color, or 0 if empty/grey/out-of-bounds
    move $s2, $v0
    beq $s2, $zero, next_scan_col

    move $a0, $s0
    move $a1, $s1
    li $a2, 0
    li $a3, 1
    jal check_match_direction
    or $s3, $s3, $v0

    move $a0, $s0
    move $a1, $s1
    li $a2, 1
    li $a3, 0
    jal check_match_direction
    or $s3, $s3, $v0

    move $a0, $s0
    move $a1, $s1
    li $a2, 1
    li $a3, 1
    jal check_match_direction
    or $s3, $s3, $v0

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
    sw $s4, 8($sp)              # $s4 = row change
    sw $s5, 4($sp)              # $s5 = col change
    sw $s6, 0($sp)              # $s6 = current col being tested

    move $s0, $a0               # save start row
    move $s1, $a1               # save start col
    move $s4, $a2               # save row change
    move $s5, $a3               # save col change

    move $a0, $s0
    move $a1, $s1
    jal get_cell_color          # $v0 = color of 1st cell
    move $s2, $v0               # $s2 = base color
    beq $s2, $zero, direction_no_match

    add $s3, $s0, $s4
    add $s6, $s1, $s5
    move $a0, $s3
    move $a1, $s6
    jal get_cell_color
    bne $v0, $s2, direction_no_match

    add $s3, $s3, $s4
    add $s6, $s6, $s5
    move $a0, $s3
    move $a1, $s6
    jal get_cell_color
    bne $v0, $s2, direction_no_match

    move $a0, $s0
    move $a1, $s1
    jal mark_match_cell

    add $a0, $s0, $s4
    add $a1, $s1, $s5
    jal mark_match_cell

    sll $t1, $s4, 1
    sll $t2, $s5, 1
    add $a0, $s0, $t1
    add $a1, $s1, $t2
    jal mark_match_cell

    li $v0, 1
    j direction_done

direction_no_match:
    move $v0, $zero

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
    sw $ra, 0($sp)

    slti $t0, $a0, 1
    bne $t0, $zero, get_cell_invalid
    slti $t0, $a0, 31
    beq $t0, $zero, get_cell_invalid
    slti $t0, $a1, 1
    bne $t0, $zero, get_cell_invalid
    slti $t0, $a1, 9
    beq $t0, $zero, get_cell_invalid

    jal display_cell_address
    lw $v0, 0($v0)
    lw $t0, GREY
    beq $v0, $t0, get_cell_invalid

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

get_cell_invalid:
    move $v0, $zero
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

mark_match_cell:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
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

    move $a0, $s0
    move $a1, $s1
    jal match_flag_address
    lw $s2, 0($v0)
    beq $s2, $zero, clear_marked_next_col

    move $a0, $s0
    move $a1, $s1
    jal display_cell_address
    sw $zero, 0($v0)

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
    sw $s3, 0($sp)              # $s3 = color of pixel at read_row

    li $s0, 1                   # start at col 1

gravity_col_loop:
    slti $t0, $s0, 9            # continue while col < 9
    beq $t0, $zero, gravity_done

    li $s1, 30                  # write_row starts at bottom of playable area (row 30)
    li $s2, 30                  # read_row also starts at row 30

gravity_read_loop:
    beq $s2, $zero, gravity_fill_loop

    move $a0, $s2
    move $a1, $s0
    jal display_cell_address
    lw $s3, 0($v0)
    beq $s3, $zero, gravity_next_read

    beq $s1, $s2, gravity_keep_cell

    move $a0, $s1
    move $a1, $s0
    jal display_cell_address
    sw $s3, 0($v0)

    move $a0, $s2
    move $a1, $s0
    jal display_cell_address
    sw $zero, 0($v0)

gravity_keep_cell:
    addi $s1, $s1, -1

gravity_next_read:
    addi $s2, $s2, -1
    j gravity_read_loop

gravity_fill_loop:
    beq $s1, $zero, gravity_next_col

    move $a0, $s1
    move $a1, $s0
    jal display_cell_address
    sw $zero, 0($v0)
    addi $s1, $s1, -1
    j gravity_fill_loop

gravity_next_col:
    addi $s0, $s0, 1
    j gravity_col_loop

gravity_done:
    lw $s3, 0($sp)
    lw $s2, 4($sp)
    lw $s1, 8($sp)
    lw $s0, 12($sp)
    lw $ra, 16($sp)
    addi $sp, $sp, 20
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
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    move $s3, $a3
    li   $s4, 0
glyph_row_loop:
    beq  $s4, 5, glyph_done
    sll  $t0, $s4, 2
    add  $t0, $s2, $t0
    lw   $s5, 0($t0)
    li   $s6, 0
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
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2

    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal  paint_cell_color
    move $a0, $s0
    addi $a1, $s1, 4
    move $a2, $s2
    jal  paint_cell_color

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

    addi $a0, $s0, 3
    move $a1, $s1
    move $a2, $s2
    jal  paint_cell_color
    addi $a0, $s0, 3
    addi $a1, $s1, 4
    move $a2, $s2
    jal  paint_cell_color

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
    li   $s0, 7
clear_pause_row_loop:
    li   $t0, 15
    beq  $s0, $t0, clear_pause_done
    li   $s1, 12
clear_pause_col_loop:
    li   $t0, 31
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
    li   $s1, 320
    move $v0, $zero
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
    addi $sp, $sp, -8
    sw   $s0, 4($sp)
    sw   $ra, 0($sp)
    lw   $t0, score_base_per_gem
    mult $a0, $t0
    mflo $t1
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
    li   $s0, 19
clear_score_row_loop:
    li   $t0, 31
    beq  $s0, $t0, clear_score_done
    li   $s1, 10
clear_score_col_loop:
    li   $t0, 32
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
    lw   $t2, 0($t0)
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
    lw   $s0, LUXURY_BLUE
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
    lw   $s1, PURE_WHITE
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
    lw   $s0, PAUSE_RED
    li   $a0, 8
    li   $a1, 12
    la   $a2, GLYPH_G
    move $a3, $s0
    jal  draw_glyph_3x5
    li   $a0, 8
    li   $a1, 16
    la   $a2, GLYPH_A
    move $a3, $s0
    jal  draw_glyph_3x5
    li   $a0, 8
    li   $a1, 20
    move $a2, $s0
    jal  draw_wide_M_5x5
    li   $a0, 8
    li   $a1, 27
    la   $a2, GLYPH_E
    move $a3, $s0
    jal  draw_glyph_3x5
    li   $a0, 15
    li   $a1, 14
    la   $a2, GLYPH_O
    move $a3, $s0
    jal  draw_glyph_3x5
    li   $a0, 15
    li   $a1, 18
    la   $a2, GLYPH_V
    move $a3, $s0
    jal  draw_glyph_3x5
    li   $a0, 15
    li   $a1, 22
    la   $a2, GLYPH_E
    move $a3, $s0
    jal  draw_glyph_3x5
    li   $a0, 15
    li   $a1, 26
    la   $a2, GLYPH_R
    move $a3, $s0
    jal  draw_glyph_3x5
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

display_cell_address:
    lw $t0, ADDR_DSPL           # $t0 = base address of bitmap display
    sll $t1, $a0, 7             # vertical offset
    add $t0, $t0, $t1
    sll $t2, $a1, 2             # horizontal offset
    add $v0, $t0, $t2           # $v0 = final address
    jr $ra

match_flag_address:
    la $t0, match_flags         # $t0 = base address of the flag array
    sll $t1, $a0, 5             # row * 32
    sll $t2, $a0, 3             # row * 8
    add $t1, $t1, $t2           # row * 40
    add $t0, $t0, $t1
    sll $t2, $a1, 2             # col * 4
    add $v0, $t0, $t2           # $v0 = base + row offset + col offset
    jr $ra

erase_column:
    lw $t0, ADDR_DSPL          # $t0 = base display address
    lw $t1, column_row         # $t1 = current top pixel row
    lw $t2, column_col         # $t2 = current column
    li $t3, 0                  # $t3 = i = 0

erase_loop:
    beq $t3, 3, erase_done
    sll $t4, $t1, 7            # vertical offset
    add $t5, $t0, $t4
    sll $t6, $t2, 2            # horizontal offset
    add $t5, $t5, $t6
    sw $zero, 0($t5)           # write black (0) to erase the pixel
    addi $t1, $t1, 1           # move to next row
    addi $t3, $t3, 1           # i++
    j erase_loop

erase_done:
    jr $ra

generate_column:
    li $t0, 0
gen_loop:
    beq $t0, 3, gen_done
    li $v0, 42
    li $a0, 0
    lw $a1, gem_palette_count
    syscall
    move $t1, $a0
    la $t2, gem_palette
    sll $t3, $t1, 2
    add $t2, $t2, $t3
    lw $t4, 0($t2)
    la $t5, column_colors
    sll $t6, $t0, 2
    add $t5, $t5, $t6
    sw $t4, 0($t5)
    addi $t0, $t0, 1
    j gen_loop
gen_done:
    jr $ra

draw_column:
    lw $t0, ADDR_DSPL       # $t0 = base address of display
    lw $t1, column_row      # $t1 = current row
    lw $t2, column_col      # $t2 = current column
    li $t3, 0               # $t3 = i = 0

draw_loop:
    beq $t3, 3, done
    sll $t4, $t1, 7
    add $t5, $t0, $t4
    sll $t6, $t2, 2
    add $t5, $t5, $t6
    la $t7, column_colors
    sll $t8, $t3, 2
    add $t7, $t7, $t8
    lw $t9, 0($t7)
    sw $t9, 0($t5)
    addi $t1, $t1, 1
    addi $t3, $t3, 1
    j draw_loop

done:
    jr $ra

fill_black_background:
    lw   $t0, ADDR_DSPL
    li   $t1, 1024
fill_black_loop:
    beq  $t1, $zero, fill_black_done
    sw   $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    j    fill_black_loop
fill_black_done:
    jr   $ra

draw_borders:
    lw $t0, ADDR_DSPL      # $t0 = base address
    lw $t9, GREY           # grey color

##################################################
# TOP WALL (row = 0, col 0 -> row = 0, col 9)
##################################################
    li $t1, 0
    li $t2, 0
    sll $t5, $t1, 7
    add $t3, $t0, $t5
    sll $t6, $t2, 2
    add $t3, $t3, $t6
    li $t2, 9
    sll $t6, $t2, 2
    add $t4, $t0, $t5
    add $t4, $t4, $t6
top_loop:
    beq $t3, $t4, top_end
    sw $t9, 0($t3)
    addi $t3, $t3, 4
    j top_loop
top_end:
    sw $t9, 0($t3)

##################################################
# BOTTOM WALL (row = 31, col 0 -> row = 31, col = 9)
##################################################
    li $t1, 31
    sll $t5, $t1, 7
    add $t3, $t0, $t5
    li $t2, 0
    sll $t6, $t2, 2
    add $t3, $t3, $t6
    li $t2, 9
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
# LEFT WALL (row = 0, col = 0 -> row = 31, col = 0)
##################################################
    li $t1, 0
    li $t2, 0
    sll $t5, $t1, 7
    add $t3, $t0, $t5
    sll $t6, $t2, 2
    add $t3, $t3, $t6
    li $t1, 31
    sll $t5, $t1, 7
    add $t4, $t0, $t5
    sll $t6, $t2, 2
    add $t4, $t4, $t6
left_loop:
    beq $t3, $t4, left_end
    sw $t9, 0($t3)
    addi $t3, $t3, 128
    j left_loop
left_end:
    sw $t9, 0($t3)

##################################################
# RIGHT WALL (row = 0, col = 9 -> row = 31, col = 9)
##################################################
    li $t1, 0
    li $t2, 9
    sll $t5, $t1, 7
    add $t3, $t0, $t5
    sll $t6, $t2, 2
    add $t3, $t3, $t6
    li $t1, 31
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
