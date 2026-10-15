package com.nightball.ui;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.ScreenAdapter;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.utils.Align;
import com.nightball.NightballGame;
import com.nightball.game.Match;
import com.nightball.game.MatchState;
import com.nightball.game.Snapshot;
import com.nightball.game.Team;
import com.nightball.session.Session;

public final class GameScreen extends ScreenAdapter {
    private final NightballGame game;
    private final Ui ui;
    private final Session session;
    private final FieldRenderer field = new FieldRenderer();
    private final TouchControls touch = new TouchControls();
    private final boolean touchDevice = Ui.isTouchDevice();

    public GameScreen(NightballGame game, Session session) {
        this.game = game;
        this.ui = game.ui;
        this.session = session;
        field.resize(Gdx.graphics.getWidth(), Gdx.graphics.getHeight());
    }

    @Override
    public void resize(int width, int height) {
        field.resize(width, height);
    }

    @Override
    public void render(float delta) {
        readInput();
        session.update(delta, System.currentTimeMillis());
        if (session.closedReason() != null) {
            game.leaveSession(session.closedReason());
            return;
        }
        if (!session.inGame()) {
            game.show(new LobbyScreen(game, session));
            return;
        }

        Gdx.gl.glEnable(GL20.GL_BLEND);
        Gdx.gl.glBlendFunc(GL20.GL_SRC_ALPHA, GL20.GL_ONE_MINUS_SRC_ALPHA);
        Snapshot s = session.renderState();
        if (s != null) {
            field.render(s, session.localPlayerId(), session.players(), ui.shapes, ui.batch, ui.font);
        }

        ui.begin();
        if (s != null) {
            drawHud(s);
        }
        if (touchDevice) {
            touch.draw(ui);
        }
        String exitLabel = session.isHost() ? "End" : "Leave";
        boolean exit = ui.button(exitLabel, ui.width() - 130f, ui.height() - 60f, 110f, 46f, true)
                || Gdx.input.isKeyJustPressed(Input.Keys.BACK) || Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE);
        if (exit) {
            if (session.isHost()) {
                session.stopGame();
            } else {
                game.leaveSession(null);
            }
        }
    }

    private void readInput() {
        float x = 0f;
        float y = 0f;
        boolean kick;
        if (touchDevice) {
            touch.update(ui);
            x = touch.moveX();
            y = touch.moveY();
            kick = touch.kick();
        } else {
            Input in = Gdx.input;
            if (in.isKeyPressed(Input.Keys.LEFT) || in.isKeyPressed(Input.Keys.A)) x -= 1f;
            if (in.isKeyPressed(Input.Keys.RIGHT) || in.isKeyPressed(Input.Keys.D)) x += 1f;
            if (in.isKeyPressed(Input.Keys.DOWN) || in.isKeyPressed(Input.Keys.S)) y -= 1f;
            if (in.isKeyPressed(Input.Keys.UP) || in.isKeyPressed(Input.Keys.W)) y += 1f;
            kick = in.isKeyPressed(Input.Keys.X) || in.isKeyPressed(Input.Keys.SPACE)
                    || in.isKeyPressed(Input.Keys.CONTROL_LEFT);
        }
        session.setLocalInput(x, y, kick);
    }

    private void drawHud(Snapshot s) {
        float cx = ui.width() / 2f;
        float top = ui.height() - 34f;
        ui.label(String.valueOf(s.redScore), cx - 60f, top, 2.6f, Ui.RED, Align.center);
        ui.label("-", cx, top, 2.6f, Ui.TEXT, Align.center);
        ui.label(String.valueOf(s.blueScore), cx + 60f, top, 2.6f, Ui.BLUE, Align.center);

        int seconds = s.timeTicks / Match.TICKS_PER_SECOND;
        String time = String.format("%d:%02d", seconds / 60, seconds % 60);
        if (s.timeLimitSeconds > 0 && seconds >= s.timeLimitSeconds) {
            time += "  golden goal";
        }
        ui.label(time, 30f, top, 1.8f, Ui.TEXT, Align.left);

        String banner = null;
        if (s.state == MatchState.GOAL) {
            banner = s.lastScorer == Team.RED ? "RED SCORES!" : "BLUE SCORES!";
        } else if (s.state == MatchState.OVER) {
            banner = s.redScore > s.blueScore ? "RED WINS" : "BLUE WINS";
        }
        if (banner != null) {
            ui.label(banner, cx, ui.height() / 2f + 120f, 4f,
                    banner.startsWith("RED") ? Ui.RED : Ui.BLUE, Align.center);
        }
        if (!touchDevice && s.state == MatchState.KICKOFF && s.tick < 240) {
            ui.label("Move: arrows / WASD     Kick: X or Space", cx, 40f, 1.3f, Ui.MUTED, Align.center);
        }
    }
}
