package com.nightball.lwjgl3;

import com.badlogic.gdx.backends.lwjgl3.Lwjgl3Application;
import com.badlogic.gdx.backends.lwjgl3.Lwjgl3ApplicationConfiguration;
import com.nightball.LaunchOptions;
import com.nightball.NightballGame;
import com.nightball.Platform;

public final class Lwjgl3Launcher {
    public static void main(String[] args) {
        Lwjgl3ApplicationConfiguration config = new Lwjgl3ApplicationConfiguration();
        config.setTitle("Nightball");
        config.setWindowedMode(1280, 720);
        config.useVsync(true);
        config.setForegroundFPS(60);
        config.setBackBufferConfig(8, 8, 8, 8, 16, 0, 4);
        LaunchOptions options = LaunchOptions.parse(args);
        if (options.name != null) {
            config.setTitle("Nightball - " + options.name);
        }
        new Lwjgl3Application(new NightballGame(Platform.NONE, options), config);
    }
}
