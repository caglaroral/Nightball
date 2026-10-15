package com.nightball.ui;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.ScreenAdapter;
import com.badlogic.gdx.utils.Align;
import com.nightball.NightballGame;
import com.nightball.session.HostSession;

public final class MenuScreen extends ScreenAdapter {
    private final NightballGame game;
    private final Ui ui;
    private final Ui.TextBox name;
    private String message;

    public MenuScreen(NightballGame game, String message) {
        this.game = game;
        this.ui = game.ui;
        this.message = message;
        this.name = new Ui.TextBox("Your name", game.playerName(), 16);
    }

    @Override
    public void render(float delta) {
        ui.begin();
        float cx = ui.width() / 2f;
        float top = ui.height();
        ui.label("NIGHTBALL", cx, top - 90f, 5f, Ui.TEXT, Align.center);
        ui.label("Football with friends on the same Wi-Fi", cx, top - 150f, 1.4f, Ui.MUTED, Align.center);

        float w = 420f;
        float x = cx - w / 2f;
        ui.textBox(name, x, top - 270f, w, 60f);

        if (ui.button("Host a room", x, top - 360f, w, 64f, true)) {
            host();
        }
        if (ui.button("Join a room", x, top - 440f, w, 64f, true)) {
            rememberName();
            game.show(new BrowseScreen(game));
            return;
        }
        if (message != null) {
            ui.label(message, cx, 40f, 1.3f, Ui.RED, Align.center);
        }
        if (Gdx.input.isKeyJustPressed(Input.Keys.BACK)) {
            Gdx.app.exit();
        }
    }

    private void host() {
        String player = rememberName();
        try {
            HostSession session = new HostSession(player, player + "'s room");
            game.setSession(session);
            game.show(new LobbyScreen(game, session));
        } catch (Exception e) {
            message = "Could not open a room: " + e.getMessage();
        }
    }

    private String rememberName() {
        String player = name.value.trim().isEmpty() ? "Player" : name.value.trim();
        game.savePlayerName(player);
        return player;
    }
}
