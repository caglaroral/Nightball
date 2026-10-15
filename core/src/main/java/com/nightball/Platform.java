package com.nightball;

/** Hooks that need platform-specific code. */
public interface Platform {
    /**
     * Called while rooms are being hosted or searched for. Android uses it to hold a Wi-Fi
     * multicast lock; without one many phones drop broadcast packets.
     */
    void setLanActive(boolean active);

    Platform NONE = new Platform() {
        @Override
        public void setLanActive(boolean active) {
        }
    };
}
