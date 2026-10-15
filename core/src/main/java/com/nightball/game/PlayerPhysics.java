package com.nightball.game;

/** Player tuning. Defaults are Haxball's playerPhysics defaults. */
public final class PlayerPhysics {
    public float radius = 15f;
    public float invMass = 0.5f;
    public float damping = 0.96f;
    public float bCoef = 0.5f;
    public float acceleration = 0.1f;
    public float kickingAcceleration = 0.07f;
    public float kickingDamping = 0.96f;
    public float kickStrength = 5f;
    public float kickback = 0f;
    /** A kick reaches the ball when the gap between the two edges is below this. */
    public float kickReach = 4f;
}
