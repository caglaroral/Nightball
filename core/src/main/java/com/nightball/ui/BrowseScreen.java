package com.nightball.ui;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.ScreenAdapter;
import com.badlogic.gdx.utils.Align;
import com.nightball.NightballGame;
import com.nightball.net.LanDiscovery;
import com.nightball.net.Protocol;
import com.nightball.net.RoomInfo;
import com.nightball.session.ClientSession;

import java.net.InetSocketAddress;
import java.util.List;

/** Lists rooms found on the Wi-Fi and lets the player type a host address instead. */
public final class BrowseScreen extends ScreenAdapter {
    private final NightballGame game;
    private final Ui ui;
    private final Ui.TextBox address = new Ui.TextBox("Or join by address (e.g. 192.168.1.20)", "", 40);
    private LanDiscovery discovery;
    private String message;

    public BrowseScreen(NightballGame game) {
        this.game = game;
        this.ui = game.ui;
    }

    @Override
    public void show() {
        game.platform.setLanActive(true);
        try {
            discovery = new LanDiscovery();
        } catch (Exception e) {
            message = "Room search is unavailable; join by address.";
        }
    }

    @Override
    public void render(float delta) {
        if (discovery != null) {
            discovery.update(System.currentTimeMillis());
        }
        ui.begin();
        float margin = 40f;
        float top = ui.height() - margin;
        float w = ui.width() - 2f * margin;
        ui.label("Rooms on this network", margin, top - 20f, 2.2f, Ui.TEXT, Align.left);

        List<RoomInfo> rooms = discovery != null ? discovery.rooms() : java.util.Collections.<RoomInfo>emptyList();
        float y = top - 110f;
        if (rooms.isEmpty()) {
            ui.label(discovery != null ? "Searching..." : "", margin, y + 28f, 1.4f, Ui.MUTED, Align.left);
        }
        for (RoomInfo room : rooms) {
            if (y < 200f) {
                break;
            }
            String line = room.name + "    " + room.players + "/" + room.maxPlayers
                    + (room.inGame ? "    playing" : "") + "    " + room.hostAddress();
            if (ui.row(line, margin, y, w, 56f)) {
                join(room.address);
                return;
            }
            y -= 66f;
        }

        float bottom = 40f;
        ui.textBox(address, margin, bottom, w - 380f, 60f);
        boolean connect = ui.button("Connect", margin + w - 360f, bottom, 170f, 60f, !address.value.trim().isEmpty());
        if (connect || (ui.consumeEnter() && !address.value.trim().isEmpty())) {
            joinTyped();
            return;
        }
        if (ui.button("Back", margin + w - 170f, bottom, 170f, 60f, true) || backPressed()) {
            game.platform.setLanActive(false);
            game.show(new MenuScreen(game, null));
            return;
        }
        if (message != null) {
            ui.label(message, margin, bottom + 110f, 1.3f, Ui.RED, Align.left);
        }
    }

    private boolean backPressed() {
        return Gdx.input.isKeyJustPressed(Input.Keys.BACK)
                || (Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) && !ui.isEditingText());
    }

    private void joinTyped() {
        String text = address.value.trim();
        int port = Protocol.GAME_PORT;
        int colon = text.lastIndexOf(':');
        if (colon > 0) {
            try {
                port = Integer.parseInt(text.substring(colon + 1));
                text = text.substring(0, colon);
            } catch (NumberFormatException e) {
                message = "Port must be a number";
                return;
            }
        }
        try {
            // Literal addresses resolve without a network lookup.
            join(new InetSocketAddress(java.net.InetAddress.getByName(text), port));
        } catch (Exception e) {
            message = "Not a valid address: " + text;
        }
    }

    private void join(InetSocketAddress room) {
        try {
            ClientSession session = new ClientSession(room, game.playerName(), System.currentTimeMillis());
            game.setSession(session);
            game.show(new LobbyScreen(game, session));
        } catch (Exception e) {
            message = "Could not connect: " + e.getMessage();
        }
    }

    @Override
    public void dispose() {
        if (discovery != null) {
            discovery.close();
            discovery = null;
        }
    }
}
