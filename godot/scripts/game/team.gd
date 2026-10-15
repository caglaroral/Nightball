class_name Team
## Team ids as sent over the network.

const SPECTATOR := 0
const RED := 1
const BLUE := 2

const COLORS := {
	RED: Color("e5604b"),
	BLUE: Color("4f86e8"),
	SPECTATOR: Color("9aa5ab"),
}


## -1 for the team defending the left goal, +1 for the right, 0 for spectators.
static func side(team: int) -> int:
	return -1 if team == RED else (1 if team == BLUE else 0)


static func opponent(team: int) -> int:
	return BLUE if team == RED else (RED if team == BLUE else SPECTATOR)


static func collision_group(team: int) -> int:
	return CollisionGroups.RED if team == RED else (CollisionGroups.BLUE if team == BLUE else 0)


static func display_name(team: int) -> String:
	return "Red" if team == RED else ("Blue" if team == BLUE else "Spectators")


static func color(team: int) -> Color:
	return COLORS.get(team, COLORS[SPECTATOR])
