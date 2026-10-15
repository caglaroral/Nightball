package com.nightball.physics;

/**
 * A moving circle. Units are pixels and ticks (60 ticks per second), as in Haxball.
 * Two objects collide when (a.cMask & b.cGroup) != 0 and (a.cGroup & b.cMask) != 0.
 */
public final class Disc {
    public float x, y;
    public float vx, vy;
    public float gravityX, gravityY;
    public float radius = 10f;
    /** 0 means immovable (goal posts). */
    public float invMass = 1f;
    /** Velocity multiplier applied every tick. */
    public float damping = 0.99f;
    /** Bounciness; the bounce of a contact is the product of both objects' bCoef. */
    public float bCoef = 0.5f;
    public int cGroup = CollisionGroups.ALL;
    public int cMask = CollisionGroups.ALL;

    public Disc() {
    }

    public Disc(float x, float y, float radius, float invMass, float damping, float bCoef, int cGroup, int cMask) {
        this.x = x;
        this.y = y;
        this.radius = radius;
        this.invMass = invMass;
        this.damping = damping;
        this.bCoef = bCoef;
        this.cGroup = cGroup;
        this.cMask = cMask;
    }

    public void setPosition(float x, float y) {
        this.x = x;
        this.y = y;
    }

    public void stop() {
        vx = 0f;
        vy = 0f;
    }

    public float speedSquared() {
        return vx * vx + vy * vy;
    }

    boolean collidesWith(int otherGroup, int otherMask) {
        return (cMask & otherGroup) != 0 && (cGroup & otherMask) != 0;
    }
}
