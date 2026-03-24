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
# Colors
RED:     .word 0xff0000
GREEN:   .word 0x00ff00
BLUE:    .word 0x0000ff
YELLOW:  .word 0xffff00
CYAN:    .word 0x00ffff
MAGENTA: .word 0xff00ff
GREY:    .word 0x888888

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
# Code
##############################################################################
 .text
 .globl main

    # Run the game.
main:
    jal draw_borders       # draw grey borders
    jal spawn_new_column   # generate the first falling column and draw it

game_loop:
    li $v0, 32                  # sleep for 16 ms (~60 FPS)
    li $a0, 16             
    syscall  
    
    jal auto_drop_tick          # advance the gravity timer; may drop the column

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
    beq $t2, 0x71, quit_game   # if 'q' → quit program

    j game_loop                # if other key → ignore and redraw

move_left:
    la $t0, column_col         # load address of column_col
    lw $t1, 0($t0)             # $t1 = current column position
    beq $t1, 1, game_loop      # if at left boundary (col=1), stop
    
    jal can_move_left           # $v0 = 1 if space is free, 0 if occupied
    beq $v0, $zero, game_loop   # occupied -> block

    jal erase_column           # erase gems at current position
    lw $t1, column_col         # reload col (erase_column uses $t1)
    addi $t1, $t1, -1          # column = column - 1 (move left)
    sw $t1, column_col         # save new col to memory
    jal draw_column            # draw gems at new position
    j game_loop

move_right:
    la $t0, column_col         # load address of column_col
    lw $t1, 0($t0)             # $t1 = current column position
    beq $t1, 8, game_loop      # if at right boundary (col=8), stop
    
    jal can_move_right
    beq $v0, $zero, game_loop

    jal erase_column
    lw $t1, column_col
    addi $t1, $t1, 1           # column = column + 1 (move right)
    sw $t1, column_col         
    jal draw_column            
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

    jal erase_column           # erase gems at current position
    jal draw_column            # redraw with rotated colors
    j game_loop

quit_game:
    li $v0, 10              
    syscall 

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
    jal resolve_matches         # clear any 3-in-a-row matches and apply gravity
    jal spawn_new_column        # start a new falling column at the top
 
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
spawn_new_column:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
 
    li $t0, 1
    sw $t0, column_row          # reset to top of playing field (row 1)
    li $t0, 4
    sw $t0, column_col          # reset to centre column (col 4)
    sw $zero, drop_counter      # restart the gravity timer from 0
 
    jal can_spawn_column        # $v0 = 1 if spawn area is clear, 0 if blocked
    beq $v0, $zero, quit_game   # spawn blocked -> board is full -> game over
 
    jal generate_column         # pick 3 new random colors into column_colors
    jal draw_column             # paint the new column on the display
 
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
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
    addi $sp, $sp, -4
    sw $ra, 0($sp)              # save return address
 
resolve_loop:
    jal clear_match_flags       # zero out the match_flags scratch array
    jal scan_for_matches        # scan board; mark matching cells; $v0 = 1 if any found
    beq $v0, $zero, resolve_done  # no matches -> board is stable, stop
 
    jal clear_marked_cells      # erase every cell whose flag was set
    jal apply_gravity           # compact each column downward to fill gaps
    j resolve_loop              # rescan to catch chain reactions
 
resolve_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

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
    li $t0, 0              # $t0 = i = 0 (loop counter)

gen_loop:
    beq $t0, 3, gen_done

    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall
    move $t1, $a0          # $t1 = random index (0-5)

    lw $t2, RED            # default color = RED
    beq $t1, 0, store      # if index == 0 → keep RED
    lw $t2, GREEN          # otherwise load GREEN
    beq $t1, 1, store
    lw $t2, BLUE
    beq $t1, 2, store
    lw $t2, YELLOW
    beq $t1, 3, store
    lw $t2, CYAN
    beq $t1, 4, store
    lw $t2, MAGENTA

store:
    la $t3, column_colors   # $t3 = base address of column_colors array
    sll $t4, $t0, 2         # $t4 = i * 4 (convert index to byte offset)
    add $t3, $t3, $t4       # $t3 = address of column_colors[i]
    sw $t2, 0($t3)          # store selected color into column_colors[i]

    addi $t0, $t0, 1        # i++
    j gen_loop

gen_done:
    jr $ra

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
    
draw_borders:
    lw $t0, ADDR_DSPL      # $t0 = base address
    li $t9, 0x888888       # grey color

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