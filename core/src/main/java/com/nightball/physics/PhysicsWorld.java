package com.nightball.physics;

import java.util.ArrayList;
import java.util.List;

/**
 * Haxball-style disc physics. One call to {@link #step()} advances one tick (1/60 s).
 * The update order and the collision responses follow Haxball's game-min.js:
 * move, damp, then resolve disc-disc, plane, segment and vertex contacts.
 */
public final class PhysicsWorld {
    public final List<Disc> discs = new ArrayList<Disc>();
    public final List<Plane> planes = new ArrayList<Plane>();
    public final List<Segment> segments = new ArrayList<Segment>();
    public final List<Vertex> vertices = new ArrayList<Vertex>();

    public void step() {
        for (int i = 0, n = discs.size(); i < n; i++) {
            Disc d = discs.get(i);
            d.x += d.vx;
            d.y += d.vy;
            d.vx = (d.vx + d.gravityX) * d.damping;
            d.vy = (d.vy + d.gravityY) * d.damping;
        }

        for (int i = 0, n = discs.size(); i < n; i++) {
            Disc a = discs.get(i);
            for (int j = i + 1; j < n; j++) {
                Disc b = discs.get(j);
                if (a.collidesWith(b.cGroup, b.cMask)) {
                    resolveDiscs(a, b);
                }
            }
            if (a.invMass == 0f) {
                continue;
            }
            for (int k = 0, m = planes.size(); k < m; k++) {
                Plane p = planes.get(k);
                if (a.collidesWith(p.cGroup, p.cMask)) {
                    resolvePlane(a, p);
                }
            }
            for (int k = 0, m = segments.size(); k < m; k++) {
                Segment s = segments.get(k);
                if (a.collidesWith(s.cGroup, s.cMask)) {
                    resolveSegment(a, s);
                }
            }
            for (int k = 0, m = vertices.size(); k < m; k++) {
                Vertex v = vertices.get(k);
                if (a.collidesWith(v.cGroup, v.cMask)) {
                    resolveVertex(a, v);
                }
            }
        }
    }

    static void resolveDiscs(Disc a, Disc b) {
        float dx = a.x - b.x;
        float dy = a.y - b.y;
        float radii = a.radius + b.radius;
        float distSq = dx * dx + dy * dy;
        float massSum = a.invMass + b.invMass;
        if (distSq <= 0f || distSq > radii * radii || massSum == 0f) {
            return;
        }
        float dist = (float) Math.sqrt(distSq);
        float nx = dx / dist;
        float ny = dy / dist;
        float shareA = a.invMass / massSum;
        float overlap = radii - dist;
        a.x += nx * overlap * shareA;
        a.y += ny * overlap * shareA;
        b.x -= nx * overlap * (1f - shareA);
        b.y -= ny * overlap * (1f - shareA);

        float approach = nx * (a.vx - b.vx) + ny * (a.vy - b.vy);
        if (approach < 0f) {
            approach *= a.bCoef * b.bCoef + 1f;
            a.vx -= nx * approach * shareA;
            a.vy -= ny * approach * shareA;
            b.vx += nx * approach * (1f - shareA);
            b.vy += ny * approach * (1f - shareA);
        }
    }

    static void resolvePlane(Disc d, Plane p) {
        float penetration = p.distance - (p.normalX * d.x + p.normalY * d.y) + d.radius;
        if (penetration <= 0f) {
            return;
        }
        d.x += p.normalX * penetration;
        d.y += p.normalY * penetration;
        bounce(d, p.normalX, p.normalY, p.bCoef);
    }

    static void resolveSegment(Disc d, Segment s) {
        float sx = s.x1 - s.x0;
        float sy = s.y1 - s.y0;
        // Only the part between the endpoints; the endpoints themselves are vertices.
        if ((d.x - s.x0) * sx + (d.y - s.y0) * sy <= 0f) {
            return;
        }
        if ((d.x - s.x1) * sx + (d.y - s.y1) * sy >= 0f) {
            return;
        }
        float nx = s.normalX;
        float ny = s.normalY;
        float dist = nx * (d.x - s.x1) + ny * (d.y - s.y1);
        if (dist < 0f) {
            dist = -dist;
            nx = -nx;
            ny = -ny;
        }
        if (dist >= d.radius) {
            return;
        }
        float push = d.radius - dist;
        d.x += nx * push;
        d.y += ny * push;
        bounce(d, nx, ny, s.bCoef);
    }

    static void resolveVertex(Disc d, Vertex v) {
        float dx = d.x - v.x;
        float dy = d.y - v.y;
        float distSq = dx * dx + dy * dy;
        if (distSq <= 0f || distSq > d.radius * d.radius) {
            return;
        }
        float dist = (float) Math.sqrt(distSq);
        float nx = dx / dist;
        float ny = dy / dist;
        float push = d.radius - dist;
        d.x += nx * push;
        d.y += ny * push;
        bounce(d, nx, ny, v.bCoef);
    }

    private static void bounce(Disc d, float nx, float ny, float wallBCoef) {
        float normalSpeed = d.vx * nx + d.vy * ny;
        if (normalSpeed < 0f) {
            normalSpeed *= d.bCoef * wallBCoef + 1f;
            d.vx -= nx * normalSpeed;
            d.vy -= ny * normalSpeed;
        }
    }
}
