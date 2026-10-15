package com.nightball.game;

import com.nightball.physics.CollisionGroups;
import com.nightball.physics.Disc;
import com.nightball.physics.Plane;
import com.nightball.physics.Segment;
import com.nightball.physics.Vertex;

import java.util.ArrayList;
import java.util.List;

/**
 * Field layout. Coordinates are centred on the kickoff spot; red defends the left goal
 * (negative x), blue the right one.
 */
public final class Stadium {
    /** Half size of the area players can move in. */
    public final float width, height;
    /** Half size of the pitch the ball stays in (the white lines). */
    public final float pitchWidth, pitchHeight;
    public final float goalHalfWidth;
    public final float goalDepth;
    public final float kickoffRadius;
    public final float spawnDistance;
    public final float postRadius;

    public final List<Plane> planes = new ArrayList<Plane>();
    public final List<Segment> segments = new ArrayList<Segment>();
    public final List<Vertex> vertices = new ArrayList<Vertex>();
    public final List<Disc> posts = new ArrayList<Disc>();

    private Stadium(float width, float height, float pitchWidth, float pitchHeight, float goalHalfWidth,
                    float goalDepth, float kickoffRadius, float spawnDistance, float postRadius) {
        this.width = width;
        this.height = height;
        this.pitchWidth = pitchWidth;
        this.pitchHeight = pitchHeight;
        this.goalHalfWidth = goalHalfWidth;
        this.goalDepth = goalDepth;
        this.kickoffRadius = kickoffRadius;
        this.spawnDistance = spawnDistance;
        this.postRadius = postRadius;
    }

    /** Layout modelled on Haxball's Classic stadium. */
    public static Stadium classic() {
        Stadium s = new Stadium(420f, 200f, 370f, 170f, 64f, 30f, 75f, 170f, 8f);
        float w = s.pitchWidth;
        float h = s.pitchHeight;
        float g = s.goalHalfWidth;
        float depth = w + s.goalDepth;
        int ballOnly = CollisionGroups.BALL;
        int wall = CollisionGroups.WALL;

        // Pitch lines: the ball bounces off them, players walk through.
        s.wall(-w, -h, w, -h, 1f, wall, ballOnly);
        s.wall(-w, h, w, h, 1f, wall, ballOnly);
        s.wall(-w, -h, -w, -g, 1f, wall, ballOnly);
        s.wall(-w, g, -w, h, 1f, wall, ballOnly);
        s.wall(w, -h, w, -g, 1f, wall, ballOnly);
        s.wall(w, g, w, h, 1f, wall, ballOnly);

        // Goal nets: soft, ball only.
        for (int side = -1; side <= 1; side += 2) {
            s.wall(side * w, -g, side * depth, -g, 0.1f, wall, ballOnly);
            s.wall(side * depth, -g, side * depth, g, 0.1f, wall, ballOnly);
            s.wall(side * depth, g, side * w, g, 0.1f, wall, ballOnly);
        }

        // Outer bounds for players.
        int players = CollisionGroups.RED | CollisionGroups.BLUE;
        s.planes.add(new Plane(0f, 1f, -s.height, 0.1f, wall, players));
        s.planes.add(new Plane(0f, -1f, -s.height, 0.1f, wall, players));
        s.planes.add(new Plane(1f, 0f, -s.width, 0.1f, wall, players));
        s.planes.add(new Plane(-1f, 0f, -s.width, 0.1f, wall, players));

        // Goal posts collide with everything and never move.
        for (int sx = -1; sx <= 1; sx += 2) {
            for (int sy = -1; sy <= 1; sy += 2) {
                s.posts.add(new Disc(sx * w, sy * g, s.postRadius, 0f, 1f, 0.5f, wall, CollisionGroups.ALL));
            }
        }
        return s;
    }

    private void wall(float x0, float y0, float x1, float y1, float bCoef, int cGroup, int cMask) {
        segments.add(new Segment(x0, y0, x1, y1, bCoef, cGroup, cMask));
        addVertex(x0, y0, bCoef, cGroup, cMask);
        addVertex(x1, y1, bCoef, cGroup, cMask);
    }

    private void addVertex(float x, float y, float bCoef, int cGroup, int cMask) {
        for (Vertex v : vertices) {
            if (v.x == x && v.y == y) {
                return;
            }
        }
        vertices.add(new Vertex(x, y, bCoef, cGroup, cMask));
    }

    /**
     * Which goal the ball entered while moving from (x0, y0) to (x1, y1):
     * {@link Team#RED} for the left goal, {@link Team#BLUE} for the right one, null for neither.
     */
    public Team goalCrossed(float x0, float y0, float x1, float y1) {
        if (x0 >= -pitchWidth && x1 < -pitchWidth && crossesWithinGoal(x0, y0, x1, y1, -pitchWidth)) {
            return Team.RED;
        }
        if (x0 <= pitchWidth && x1 > pitchWidth && crossesWithinGoal(x0, y0, x1, y1, pitchWidth)) {
            return Team.BLUE;
        }
        return null;
    }

    private boolean crossesWithinGoal(float x0, float y0, float x1, float y1, float lineX) {
        float t = (lineX - x0) / (x1 - x0);
        float y = y0 + (y1 - y0) * t;
        return Math.abs(y) < goalHalfWidth;
    }
}
