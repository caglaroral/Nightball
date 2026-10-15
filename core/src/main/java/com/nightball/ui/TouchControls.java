package com.nightball.ui;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.Vector3;
import com.badlogic.gdx.utils.Align;

/**
 * Left half of the screen: a floating joystick that appears where the thumb lands.
 * Right half: hold anywhere to kick.
 */
final class TouchControls {
    private static final int MAX_POINTERS = 10;
    private static final float STICK_RADIUS = 80f;
    private static final float DEAD_ZONE = 0.15f;

    private final Vector3 point = new Vector3();
    private int stickPointer = -1;
    private float originX, originY, knobX, knobY;
    private boolean kick;
    private float moveX, moveY;

    void update(Ui ui) {
        kick = false;
        boolean stickHeld = false;
        float half = ui.width() / 2f;
        for (int p = 0; p < MAX_POINTERS; p++) {
            if (!Gdx.input.isTouched(p)) {
                continue;
            }
            ui.pointer(p, point);
            if (p == stickPointer) {
                stickHeld = true;
                knobX = point.x;
                knobY = point.y;
            } else if (point.x < half && stickPointer < 0) {
                stickPointer = p;
                stickHeld = true;
                originX = knobX = point.x;
                originY = knobY = point.y;
            } else if (point.x >= half) {
                kick = true;
            }
        }
        if (!stickHeld) {
            stickPointer = -1;
        }

        moveX = 0f;
        moveY = 0f;
        if (stickPointer >= 0) {
            float dx = (knobX - originX) / STICK_RADIUS;
            float dy = (knobY - originY) / STICK_RADIUS;
            float length = (float) Math.sqrt(dx * dx + dy * dy);
            if (length > DEAD_ZONE) {
                float strength = Math.min(1f, (length - DEAD_ZONE) / (1f - DEAD_ZONE));
                moveX = dx / length * strength;
                moveY = dy / length * strength;
            }
        }
    }

    float moveX() {
        return moveX;
    }

    float moveY() {
        return moveY;
    }

    boolean kick() {
        return kick;
    }

    void draw(Ui ui) {
        ShapeRenderer shapes = ui.shapes;
        shapes.begin(ShapeRenderer.ShapeType.Filled);
        if (stickPointer >= 0) {
            shapes.setColor(1f, 1f, 1f, 0.15f);
            shapes.circle(originX, originY, STICK_RADIUS, 40);
            float dx = knobX - originX;
            float dy = knobY - originY;
            float length = (float) Math.sqrt(dx * dx + dy * dy);
            if (length > STICK_RADIUS) {
                dx *= STICK_RADIUS / length;
                dy *= STICK_RADIUS / length;
            }
            shapes.setColor(1f, 1f, 1f, 0.4f);
            shapes.circle(originX + dx, originY + dy, 34f, 32);
        }
        float kickX = ui.width() - 120f;
        float kickY = 120f;
        shapes.setColor(1f, 1f, 1f, kick ? 0.45f : 0.18f);
        shapes.circle(kickX, kickY, 70f, 40);
        shapes.end();
        ui.label("KICK", kickX, kickY, 1.5f, Ui.TEXT, Align.center);
    }
}
