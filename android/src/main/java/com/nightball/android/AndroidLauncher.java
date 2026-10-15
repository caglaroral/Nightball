package com.nightball.android;

import android.content.Context;
import android.net.wifi.WifiManager;
import android.os.Bundle;

import com.badlogic.gdx.backends.android.AndroidApplication;
import com.badlogic.gdx.backends.android.AndroidApplicationConfiguration;
import com.nightball.NightballGame;
import com.nightball.Platform;

public class AndroidLauncher extends AndroidApplication implements Platform {
    private WifiManager.MulticastLock multicastLock;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        AndroidApplicationConfiguration config = new AndroidApplicationConfiguration();
        config.useImmersiveMode = true;
        config.useAccelerometer = false;
        config.useCompass = false;
        config.numSamples = 2;
        initialize(new NightballGame(this), config);
    }

    @Override
    public synchronized void setLanActive(boolean active) {
        if (active) {
            if (multicastLock == null) {
                WifiManager wifi = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
                if (wifi == null) {
                    return;
                }
                multicastLock = wifi.createMulticastLock("nightball-lan");
                multicastLock.setReferenceCounted(false);
            }
            multicastLock.acquire();
        } else if (multicastLock != null && multicastLock.isHeld()) {
            multicastLock.release();
        }
    }

    @Override
    protected void onDestroy() {
        setLanActive(false);
        super.onDestroy();
    }
}
