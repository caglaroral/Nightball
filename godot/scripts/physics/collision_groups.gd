class_name CollisionGroups
## Collision bits, numbered like Haxball's cGroup/cMask flags.
## Two objects collide when (a.c_mask & b.c_group) != 0 and (a.c_group & b.c_mask) != 0.

const BALL := 1
const RED := 2
const BLUE := 4
const RED_KICKOFF := 8
const BLUE_KICKOFF := 16
const WALL := 32
## Discs with this bit can be kicked by players.
const KICK := 64
## Discs with this bit score when they cross a goal line.
const SCORE := 128
const ALL := 63
