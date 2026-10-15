package com.nightball.ui;

import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.utils.Align;
import com.badlogic.gdx.utils.viewport.ExtendViewport;
import com.nightball.game.Snapshot;
import com.nightball.game.Stadium;
import com.nightball.game.Team;
import com.nightball.physics.Disc;
import com.nightball.physics.Segment;
import com.nightball.session.LobbyPlayer;

import java.util.List;

/** Draws the pitch and the discs in stadium coordinates. */
final class FieldRenderer {
    private static final Color GRASS = new Color(0x718C5AFF);
    private static final Color GRASS_DARK = new Color(0x6A8454FF);
    private static final Color LINE = new Color(0xC7E6BDFF);
    private static final Color OUTLINE = Color.BLACK;

    private final Stadium stadium = Stadium.classic();
    final ExtendViewport viewport;

    FieldRenderer() {
        viewport = new ExtendViewport(stadium.width * 2f + 30f, stadium.height * 2f + 30f);
    }

    void resize(int width, int height) {
        viewport.update(width, height, false);
        viewport.getCamera().position.set(0f, 0f, 0f);
    }

    void render(Snapshot s, int localPlayerId, List<LobbyPlayer> players, ShapeRenderer shapes,
                SpriteBatch batch, BitmapFont font) {
        viewport.getCamera().position.set(0f, 0f, 0f);
        viewport.apply();
        shapes.setProjectionMatrix(viewport.getCamera().combined);
        batch.setProjectionMatrix(viewport.getCamera().combined);

        shapes.begin(ShapeRenderer.ShapeType.Filled);
        drawPitch(shapes);
        for (int i = 0; i < s.playerCount; i++) {
            Team team = s.playerTeams[i];
            float x = s.playerX[i];
            float y = s.playerY[i];
            float r = 15f;
            if (s.playerIds[i] == localPlayerId) {
                shapes.setColor(1f, 1f, 1f, 1f);
                ring(shapes, x, y, r + 7f, 1.5f);
            }
            shapes.setColor(s.playerKicking[i] ? Color.WHITE : OUTLINE);
            shapes.circle(x, y, r + 2f, 32);
            shapes.setColor(team == Team.RED ? Ui.RED : Ui.BLUE);
            shapes.circle(x, y, r, 32);
        }
        shapes.setColor(OUTLINE);
        shapes.circle(s.ballX, s.ballY, 12f, 24);
        shapes.setColor(Color.WHITE);
        shapes.circle(s.ballX, s.ballY, 10f, 24);
        shapes.end();

        font.getData().setScale(0.9f);
        font.setColor(1f, 1f, 1f, 0.85f);
        batch.begin();
        for (int i = 0; i < s.playerCount; i++) {
            String name = nameOf(players, s.playerIds[i]);
            if (name != null) {
                font.draw(batch, name, s.playerX[i], s.playerY[i] - 22f, 0f, Align.center, false);
            }
        }
        batch.end();
    }

    private void drawPitch(ShapeRenderer shapes) {
        float w = stadium.pitchWidth;
        float h = stadium.pitchHeight;
        shapes.setColor(GRASS);
        shapes.rect(-stadium.width - 200f, -stadium.height - 200f, stadium.width * 2f + 400f, stadium.height * 2f + 400f);
        // Mowing stripes inside the pitch.
        float stripe = w * 2f / 8f;
        shapes.setColor(GRASS_DARK);
        for (int i = 0; i < 8; i += 2) {
            shapes.rect(-w + i * stripe, -h, stripe, h * 2f);
        }
        shapes.setColor(LINE);
        ring(shapes, 0f, 0f, stadium.kickoffRadius, 3f);
        shapes.rectLine(0f, -h, 0f, h, 3f);
        for (Segment seg : stadium.segments) {
            shapes.rectLine(seg.x0, seg.y0, seg.x1, seg.y1, 3f);
        }
        for (Disc post : stadium.posts) {
            shapes.setColor(OUTLINE);
            shapes.circle(post.x, post.y, post.radius + 2f, 20);
            shapes.setColor(Color.WHITE);
            shapes.circle(post.x, post.y, post.radius, 20);
        }
    }

    /** Circle outline in the current colour. */
    private static void ring(ShapeRenderer shapes, float x, float y, float radius, float thickness) {
        int segments = 64;
        float step = (float) (Math.PI * 2 / segments);
        for (int i = 0; i < segments; i++) {
            float a0 = i * step;
            float a1 = a0 + step;
            shapes.rectLine(x + (float) Math.cos(a0) * radius, y + (float) Math.sin(a0) * radius,
                    x + (float) Math.cos(a1) * radius, y + (float) Math.sin(a1) * radius, thickness);
        }
    }

    private static String nameOf(List<LobbyPlayer> players, int id) {
        for (LobbyPlayer p : players) {
            if (p.id == id) {
                return p.name;
            }
        }
        return null;
    }
}
