package com.nightball;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.Preferences;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.utils.ScreenUtils;
import com.nightball.net.Protocol;
import com.nightball.session.ClientSession;
import com.nightball.session.HostSession;
import com.nightball.session.Session;
import com.nightball.ui.LobbyScreen;
import com.nightball.ui.MenuScreen;
import com.nightball.ui.Ui;

import java.net.InetSocketAddress;

public final class NightballGame extends Game {
    public final Platform platform;
    public final LaunchOptions options;
    public Ui ui;
    private Preferences preferences;
    private Session session;

    public NightballGame(Platform platform) {
        this(platform, new LaunchOptions());
    }

    public NightballGame(Platform platform, LaunchOptions options) {
        this.platform = platform;
        this.options = options;
    }

    @Override
    public void create() {
        ui = new Ui();
        preferences = Gdx.app.getPreferences("nightball");
        Gdx.input.setInputProcessor(ui);
        Gdx.input.setCatchKey(Input.Keys.BACK, true);
        setScreen(firstScreen());
    }

    private Screen firstScreen() {
        String name = options.name != null ? options.name : playerName();
        try {
            if (options.host) {
                HostSession host = new HostSession(name, name + "'s room");
                setSession(host);
                return new LobbyScreen(this, host);
            }
            if (options.join != null) {
                String address = options.join;
                int port = Protocol.GAME_PORT;
                int colon = address.lastIndexOf(':');
                if (colon > 0) {
                    port = Integer.parseInt(address.substring(colon + 1));
                    address = address.substring(0, colon);
                }
                ClientSession client = new ClientSession(new InetSocketAddress(address, port), name,
                        System.currentTimeMillis());
                setSession(client);
                return new LobbyScreen(this, client);
            }
        } catch (Exception e) {
            return new MenuScreen(this, "Could not start: " + e.getMessage());
        }
        return new MenuScreen(this, null);
    }

    @Override
    public void render() {
        ScreenUtils.clear(Ui.BACKGROUND);
        super.render();
    }

    @Override
    public void resize(int width, int height) {
        ui.resize(width, height);
        super.resize(width, height);
    }

    public void show(Screen next) {
        Screen previous = getScreen();
        setScreen(next);
        if (previous != null) {
            previous.dispose();
        }
    }

    public String playerName() {
        return preferences.getString("name", "Player");
    }

    public void savePlayerName(String name) {
        preferences.putString("name", name);
        preferences.flush();
    }

    /** The room this device is in; replaces and closes any previous one. */
    public void setSession(Session next) {
        if (session != null && session != next) {
            session.close();
        }
        session = next;
        platform.setLanActive(next != null);
    }

    public void leaveSession(String message) {
        setSession(null);
        show(new MenuScreen(this, message));
    }

    @Override
    public void dispose() {
        setSession(null);
        Screen screen = getScreen();
        if (screen != null) {
            screen.dispose();
        }
        ui.dispose();
    }
}
