package com.nightball.physics;

/** Straight two-sided wall between two points. Its endpoints are handled as separate vertices. */
public final class Segment {
    public final float x0, y0, x1, y1;
    final float normalX, normalY;
    public final float bCoef;
    public final int cGroup;
    public final int cMask;

    public Segment(float x0, float y0, float x1, float y1, float bCoef, int cGroup, int cMask) {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
        float dx = x1 - x0;
        float dy = y1 - y0;
        float length = (float) Math.sqrt(dx * dx + dy * dy);
        this.normalX = -dy / length;
        this.normalY = dx / length;
        this.bCoef = bCoef;
        this.cGroup = cGroup;
        this.cMask = cMask;
    }
}
