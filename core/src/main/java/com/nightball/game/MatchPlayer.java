package com.nightball.game;

import com.nightball.physics.Disc;

public final class MatchPlayer {
    public final int id;
    public final Team team;
    public final Disc disc;

    float moveX, moveY;
    private boolean kickHeld;
    /** True from a kick press until the kick lands or the button is released (Haxball's behaviour). */
    boolean kicking;

    MatchPlayer(int id, Team team, Disc disc) {
        this.id = id;
        this.team = team;
        this.disc = disc;
    }

    /** Movement is a direction with length up to 1; longer vectors are normalised. */
    public void setInput(float moveX, float moveY, boolean kick) {
        float lengthSq = moveX * moveX + moveY * moveY;
        if (lengthSq > 1f) {
            float length = (float) Math.sqrt(lengthSq);
            moveX /= length;
            moveY /= length;
        }
        this.moveX = moveX;
        this.moveY = moveY;
        if (kick && !kickHeld) {
            kicking = true;
        } else if (!kick) {
            kicking = false;
        }
        kickHeld = kick;
    }

    public boolean isKicking() {
        return kicking;
    }
}
