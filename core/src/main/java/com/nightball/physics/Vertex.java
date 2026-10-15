package com.nightball.physics;

/** Fixed point that discs bounce off, normally a segment endpoint. */
public final class Vertex {
    public final float x, y;
    public final float bCoef;
    public final int cGroup;
    public final int cMask;

    public Vertex(float x, float y, float bCoef, int cGroup, int cMask) {
        this.x = x;
        this.y = y;
        this.bCoef = bCoef;
        this.cGroup = cGroup;
        this.cMask = cMask;
    }
}
