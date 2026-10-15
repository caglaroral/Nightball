package com.nightball.session;

import com.nightball.game.Team;

public final class LobbyPlayer {
    public final int id;
    public final String name;
    public Team team;

    public LobbyPlayer(int id, String name, Team team) {
        this.id = id;
        this.name = name;
        this.team = team;
    }
}
