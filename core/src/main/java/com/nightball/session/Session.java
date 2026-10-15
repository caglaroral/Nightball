package com.nightball.session;

import com.nightball.game.Snapshot;
import com.nightball.game.Team;

import java.util.List;

/** A room as seen by this device, whether it hosts the room or joined it. Game-thread only. */
public interface Session {
    int MAX_PLAYERS = 16;
    int MAX_PER_TEAM = 4;

    /** Pumps the network and, on the host, advances the simulation. */
    void update(float deltaSeconds, long nowMillis);

    boolean isHost();

    /** False while a client is still waiting for the host to accept it. */
    boolean isConnected();

    /** Non-null once the session has ended; explains why. */
    String closedReason();

    int localPlayerId();

    String roomName();

    List<LobbyPlayer> players();

    boolean inGame();

    /** Movement direction (length up to 1) and kick button of the local player. */
    void setLocalInput(float moveX, float moveY, boolean kick);

    void requestTeam(Team team);

    /** Host only. */
    void startGame();

    /** Host only: ends the match and returns everyone to the lobby. */
    void stopGame();

    /** Smoothed state to draw this frame, or null before the first snapshot. */
    Snapshot renderState();

    void close();
}
