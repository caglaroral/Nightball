package com.nightball.ui;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.ScreenAdapter;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.utils.Align;
import com.nightball.NightballGame;
import com.nightball.game.Team;
import com.nightball.net.NetUtil;
import com.nightball.session.HostSession;
import com.nightball.session.LobbyPlayer;
import com.nightball.session.Session;

import java.util.List;

public final class LobbyScreen extends ScreenAdapter {
    private final NightballGame game;
    private final Ui ui;
    private final Session session;
    private final String joinHint;

    public LobbyScreen(NightballGame game, Session session) {
        this.game = game;
        this.ui = game.ui;
        this.session = session;
        this.joinHint = session instanceof HostSession ? buildJoinHint((HostSession) session) : null;
    }

    private static String buildJoinHint(HostSession host) {
        List<String> addresses = NetUtil.localAddresses();
        String port = host.port() == com.nightball.net.Protocol.GAME_PORT ? "" : ":" + host.port();
        StringBuilder hint = new StringBuilder();
        if (!host.isDiscoverable()) {
            hint.append("Room search is unavailable here. ");
        }
        if (addresses.isEmpty()) {
            hint.append("Connect to Wi-Fi so others can join.");
        } else {
            hint.append("Others can join at ");
            for (int i = 0; i < addresses.size(); i++) {
                hint.append(i == 0 ? "" : " or ").append(addresses.get(i)).append(port);
            }
        }
        return hint.toString();
    }

    @Override
    public void render(float delta) {
        session.update(delta, System.currentTimeMillis());
        if (session.closedReason() != null) {
            game.leaveSession(session.closedReason());
            return;
        }
        if (session.inGame()) {
            game.show(new GameScreen(game, session));
            return;
        }

        ui.begin();
        float margin = 40f;
        float top = ui.height() - margin;
        boolean leave = ui.button("Leave", ui.width() - margin - 160f, top - 56f, 160f, 56f, true)
                || Gdx.input.isKeyJustPressed(Input.Keys.BACK) || Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE);
        if (leave) {
            game.leaveSession(null);
            return;
        }

        if (!session.isConnected()) {
            ui.label("Connecting...", ui.width() / 2f, ui.height() / 2f, 2.2f, Ui.TEXT, Align.center);
            return;
        }

        ui.label(session.roomName(), margin, top - 28f, 2.2f, Ui.TEXT, Align.left);
        if (joinHint != null) {
            ui.label(joinHint, margin, top - 80f, 1.3f, Ui.MUTED, Align.left);
        }

        float columnTop = top - 120f;
        float gap = 20f;
        float columnWidth = (ui.width() - 2f * margin - 2f * gap) / 3f;
        float columnHeight = columnTop - 150f;
        column("Red", Team.RED, Ui.RED, margin, columnTop, columnWidth, columnHeight);
        column("Spectators", Team.SPECTATOR, Ui.MUTED, margin + columnWidth + gap, columnTop, columnWidth, columnHeight);
        column("Blue", Team.BLUE, Ui.BLUE, margin + 2f * (columnWidth + gap), columnTop, columnWidth, columnHeight);

        if (session.isHost()) {
            boolean anyPlaying = count(Team.RED) + count(Team.BLUE) > 0;
            if (game.options.autoStart && session.players().size() >= 2) {
                game.options.autoStart = false;
                session.startGame();
            }
            if (ui.button("Start game", ui.width() / 2f - 160f, 30f, 320f, 64f, anyPlaying)) {
                session.startGame();
            }
        } else {
            ui.label("Waiting for the host to start...", ui.width() / 2f, 62f, 1.4f, Ui.MUTED, Align.center);
        }
    }

    private void column(String title, Team team, Color color, float x, float top, float w, float h) {
        ui.rect(x, top - h, w, h, Ui.PANEL);
        ui.rect(x, top - 6f, w, 6f, color);
        ui.label(title, x + 16f, top - 34f, 1.6f, color, Align.left);
        float y = top - 80f;
        for (LobbyPlayer p : session.players()) {
            if (p.team != team) {
                continue;
            }
            boolean me = p.id == session.localPlayerId();
            ui.label((me ? "> " : "") + p.name, x + 16f, y, 1.4f, me ? Ui.TEXT : Ui.MUTED, Align.left);
            y -= 34f;
        }
        LobbyPlayer me = local();
        boolean full = team != Team.SPECTATOR && count(team) >= Session.MAX_PER_TEAM;
        boolean canMove = me != null && me.team != team && !full;
        if (ui.button(team == Team.SPECTATOR ? "Watch" : "Join", x + 12f, top - h + 12f, w - 24f, 52f, canMove)) {
            session.requestTeam(team);
        }
    }

    private LobbyPlayer local() {
        for (LobbyPlayer p : session.players()) {
            if (p.id == session.localPlayerId()) {
                return p;
            }
        }
        return null;
    }

    private int count(Team team) {
        int count = 0;
        for (LobbyPlayer p : session.players()) {
            if (p.team == team) {
                count++;
            }
        }
        return count;
    }
}
