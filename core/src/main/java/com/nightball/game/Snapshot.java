package com.nightball.game;

/** Everything needed to draw one tick. Sent from the host to clients and interpolated for rendering. */
public final class Snapshot {
    public static final int MAX_PLAYERS = 16;

    public int tick;
    public MatchState state = MatchState.KICKOFF;
    public int redScore, blueScore;
    /** Elapsed playing time in ticks. */
    public int timeTicks;
    public int timeLimitSeconds;
    public Team kickoffTeam = Team.RED;
    /** Team that scored last; set during {@link MatchState#GOAL} and {@link MatchState#OVER}. */
    public Team lastScorer = Team.SPECTATOR;
    public float ballX, ballY;

    public int playerCount;
    public final int[] playerIds = new int[MAX_PLAYERS];
    public final Team[] playerTeams = new Team[MAX_PLAYERS];
    public final float[] playerX = new float[MAX_PLAYERS];
    public final float[] playerY = new float[MAX_PLAYERS];
    public final boolean[] playerKicking = new boolean[MAX_PLAYERS];

    public void set(Snapshot o) {
        tick = o.tick;
        state = o.state;
        redScore = o.redScore;
        blueScore = o.blueScore;
        timeTicks = o.timeTicks;
        timeLimitSeconds = o.timeLimitSeconds;
        kickoffTeam = o.kickoffTeam;
        lastScorer = o.lastScorer;
        ballX = o.ballX;
        ballY = o.ballY;
        playerCount = o.playerCount;
        System.arraycopy(o.playerIds, 0, playerIds, 0, playerCount);
        System.arraycopy(o.playerTeams, 0, playerTeams, 0, playerCount);
        System.arraycopy(o.playerX, 0, playerX, 0, playerCount);
        System.arraycopy(o.playerY, 0, playerY, 0, playerCount);
        System.arraycopy(o.playerKicking, 0, playerKicking, 0, playerCount);
    }

    /** Positions blended between a and b; everything else comes from b. */
    public void interpolate(Snapshot a, Snapshot b, float alpha) {
        set(b);
        // A kickoff reset teleports everything; blending across it would show discs sliding.
        if (a.state != MatchState.KICKOFF && b.state == MatchState.KICKOFF) {
            return;
        }
        ballX = lerp(a.ballX, b.ballX, alpha);
        ballY = lerp(a.ballY, b.ballY, alpha);
        for (int i = 0; i < playerCount; i++) {
            int index = a.indexOf(playerIds[i]);
            if (index >= 0) {
                playerX[i] = lerp(a.playerX[index], b.playerX[i], alpha);
                playerY[i] = lerp(a.playerY[index], b.playerY[i], alpha);
            }
        }
    }

    public int indexOf(int playerId) {
        for (int i = 0; i < playerCount; i++) {
            if (playerIds[i] == playerId) {
                return i;
            }
        }
        return -1;
    }

    private static float lerp(float from, float to, float alpha) {
        return from + (to - from) * alpha;
    }
}
