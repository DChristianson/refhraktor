  

PF1_CHUTE_0 = PF1_GOAL_TOP

PF1_CHUTE_1 = PFX_WALLS_BLANK

PF1_CHUTE_2
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011

PF1_CHUTE_3 = PF1_CHUTE_2
PF1_CHUTE_4 = PF1_CHUTE_2
PF1_CHUTE_5 = PF1_CHUTE_2
PF1_CHUTE_6 = PF1_CHUTE_1
PF1_CHUTE_7 = PF1_GOAL_BOTTOM


PF2_CHUTE_0 = PF1_CHUTE_1
PF2_CHUTE_1
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000

PF2_CHUTE_2 = PF1_CHUTE_1
PF2_CHUTE_3 = PF1_CHUTE_1
PF2_CHUTE_4 = PF1_CHUTE_1
PF2_CHUTE_5 = PF1_CHUTE_1
PF2_CHUTE_6 = PF2_CHUTE_1
PF2_CHUTE_7 = PF1_CHUTE_1

PF3_CHUTE_0 = PF1_CHUTE_1
PF3_CHUTE_1 = PF1_CHUTE_1
PF3_CHUTE_2 = PF1_CHUTE_1
PF3_CHUTE_3 = PF1_CHUTE_1
PF3_CHUTE_4 = PF1_CHUTE_1
PF3_CHUTE_5 = PF1_CHUTE_1
PF3_CHUTE_6 = PF1_CHUTE_1
PF3_CHUTE_7 = PF1_CHUTE_1

PF4_CHUTE_0 = PF1_CHUTE_0
PF4_CHUTE_1 = PF1_CHUTE_1
PF4_CHUTE_2
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000

PF4_CHUTE_3 = PF4_CHUTE_2
PF4_CHUTE_4 = PF4_CHUTE_2
PF4_CHUTE_5 = PF4_CHUTE_2
PF4_CHUTE_6 = PF1_CHUTE_1
PF4_CHUTE_7 = PF1_CHUTE_7