package com.nightball.net;

import java.net.InetSocketAddress;

/** A room found on the local network. */
public final class RoomInfo {
    public final String name;
    public final InetSocketAddress address;
    public final int players;
    public final int maxPlayers;
    public final boolean inGame;
    long lastSeenMillis;

    RoomInfo(String name, InetSocketAddress address, int players, int maxPlayers, boolean inGame, long lastSeenMillis) {
        this.name = name;
        this.address = address;
        this.players = players;
        this.maxPlayers = maxPlayers;
        this.inGame = inGame;
        this.lastSeenMillis = lastSeenMillis;
    }

    public String hostAddress() {
        return address.getAddress().getHostAddress();
    }
}
