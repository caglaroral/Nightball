package com.nightball.game;

import com.nightball.physics.CollisionGroups;

public enum Team {
    SPECTATOR(0, 0, 0),
    RED(1, CollisionGroups.RED, CollisionGroups.RED_KICKOFF),
    BLUE(2, CollisionGroups.BLUE, CollisionGroups.BLUE_KICKOFF);

    public final int id;
    public final int collisionGroup;
    public final int kickoffGroup;

    Team(int id, int collisionGroup, int kickoffGroup) {
        this.id = id;
        this.collisionGroup = collisionGroup;
        this.kickoffGroup = kickoffGroup;
    }

    /** -1 for the team defending the left goal, +1 for the right, 0 for spectators. */
    public int side() {
        return this == RED ? -1 : this == BLUE ? 1 : 0;
    }

    public Team opponent() {
        return this == RED ? BLUE : this == BLUE ? RED : SPECTATOR;
    }

    public static Team byId(int id) {
        for (Team t : values()) {
            if (t.id == id) {
                return t;
            }
        }
        return SPECTATOR;
    }
}
