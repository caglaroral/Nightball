package com.nightball.physics;

/** Infinite wall. Discs are kept on the side where normal·p >= distance + radius. */
public final class Plane {
    public final float normalX, normalY;
    public final float distance;
    public final float bCoef;
    public final int cGroup;
    public final int cMask;

    public Plane(float normalX, float normalY, float distance, float bCoef, int cGroup, int cMask) {
        float length = (float) Math.sqrt(normalX * normalX + normalY * normalY);
        this.normalX = normalX / length;
        this.normalY = normalY / length;
        this.distance = distance;
        this.bCoef = bCoef;
        this.cGroup = cGroup;
        this.cMask = cMask;
    }
}
