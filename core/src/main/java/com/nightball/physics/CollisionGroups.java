package com.nightball.physics;

/** Collision bits, numbered the same way as Haxball's cGroup/cMask flags. */
public final class CollisionGroups {
    public static final int BALL = 1;
    public static final int RED = 2;
    public static final int BLUE = 4;
    public static final int RED_KICKOFF = 8;
    public static final int BLUE_KICKOFF = 16;
    public static final int WALL = 32;
    /** Discs with this bit can be kicked by players. */
    public static final int KICK = 64;
    /** Discs with this bit score when they cross a goal line. */
    public static final int SCORE = 128;
    public static final int ALL = 63;

    private CollisionGroups() {
    }
}
