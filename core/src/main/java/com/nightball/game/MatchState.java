package com.nightball.game;

public enum MatchState {
    /** Waiting for the kickoff; teams are held in their own halves. */
    KICKOFF,
    PLAYING,
    /** Short pause after a goal before the next kickoff. */
    GOAL,
    OVER;

    public static MatchState byOrdinal(int ordinal) {
        MatchState[] all = values();
        return ordinal >= 0 && ordinal < all.length ? all[ordinal] : KICKOFF;
    }
}
