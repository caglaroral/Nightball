package com.nightball.session;

import com.nightball.game.Match;
import com.nightball.game.Snapshot;
import com.nightball.game.Stadium;
import com.nightball.game.Team;
import com.nightball.net.Protocol;
import com.nightball.net.UdpEndpoint;

import java.net.SocketAddress;
import java.net.SocketException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

/** Runs the room: answers discovery, accepts players and simulates the match at 60 Hz. */
public final class HostSession implements Session {
    public static final int SCORE_LIMIT = 3;
    public static final int TIME_LIMIT_SECONDS = 3 * 60;

    private static final int HOST_ID = 0;
    private static final float STEP = 1f / Match.TICKS_PER_SECOND;
    private static final long CLIENT_TIMEOUT_MS = 5000;
    private static final long LOBBY_INTERVAL_MS = 250;

    private static final class Remote {
        final int id;
        final SocketAddress address;
        final int nonce;
        long lastHeardMillis;
        int lastInputSeq = Integer.MIN_VALUE;

        Remote(int id, SocketAddress address, int nonce, long now) {
            this.id = id;
            this.address = address;
            this.nonce = nonce;
            this.lastHeardMillis = now;
        }
    }

    private final String roomName;
    private final UdpEndpoint game;
    private final UdpEndpoint discovery;
    private final List<LobbyPlayer> players = new ArrayList<LobbyPlayer>();
    private final List<Remote> remotes = new ArrayList<Remote>();
    private final ByteBuffer out = ByteBuffer.allocate(Protocol.MAX_PACKET);

    private Match match;
    private final Snapshot previous = new Snapshot();
    private final Snapshot current = new Snapshot();
    private final Snapshot render = new Snapshot();
    private float accumulator;
    private float inputX, inputY;
    private boolean inputKick;

    private int nextId = 1;
    private boolean lobbyDirty = true;
    private long nextLobbyMillis;
    private String closedReason;

    public HostSession(String hostName, String roomName) throws SocketException {
        this.roomName = roomName;
        UdpEndpoint gameEndpoint;
        try {
            gameEndpoint = new UdpEndpoint(Protocol.GAME_PORT, "nightball-host");
        } catch (SocketException e) {
            // Port taken, e.g. a second room on the same computer; discovery reports the real port.
            gameEndpoint = new UdpEndpoint(0, "nightball-host");
        }
        game = gameEndpoint;
        UdpEndpoint discoveryEndpoint = null;
        try {
            discoveryEndpoint = new UdpEndpoint(Protocol.DISCOVERY_PORT, "nightball-host-discovery");
        } catch (SocketException e) {
            // Rooms can still be joined by IP address.
        }
        discovery = discoveryEndpoint;
        players.add(new LobbyPlayer(HOST_ID, hostName, Team.RED));
    }

    /** True when other devices can find this room automatically. */
    public boolean isDiscoverable() {
        return discovery != null;
    }

    public int port() {
        return game.localPort();
    }

    @Override
    public void update(float deltaSeconds, long now) {
        if (closedReason != null) {
            return;
        }
        answerDiscovery();
        readPackets(now);
        dropSilentClients(now);

        if (match != null) {
            accumulator += Math.min(deltaSeconds, 0.25f);
            while (accumulator >= STEP) {
                accumulator -= STEP;
                match.setInput(HOST_ID, inputX, inputY, inputKick);
                match.tick();
                previous.set(current);
                match.writeSnapshot(current);
                sendSnapshot();
            }
            if (match.isFinished()) {
                stopGame();
            }
        }

        if (lobbyDirty || now >= nextLobbyMillis) {
            lobbyDirty = false;
            nextLobbyMillis = now + LOBBY_INTERVAL_MS;
            sendLobby();
        }
    }

    private void answerDiscovery() {
        if (discovery == null) {
            return;
        }
        UdpEndpoint.Packet packet;
        while ((packet = discovery.poll()) != null) {
            if (Protocol.readType(packet.data) != Protocol.DISCOVER) {
                continue;
            }
            Protocol.begin(out, Protocol.ROOM_INFO);
            Protocol.putString(out, roomName);
            out.putShort((short) game.localPort());
            out.put((byte) players.size());
            out.put((byte) MAX_PLAYERS);
            out.put((byte) (match != null ? 1 : 0));
            discovery.send(out, packet.from);
        }
    }

    private void readPackets(long now) {
        UdpEndpoint.Packet packet;
        while ((packet = game.poll()) != null) {
            ByteBuffer in = packet.data;
            try {
                int type = Protocol.readType(in);
                if (type == Protocol.JOIN) {
                    handleJoin(packet.from, in.getInt(), Protocol.getString(in), now);
                    continue;
                }
                if (type != Protocol.INPUT && type != Protocol.TEAM && type != Protocol.LEAVE) {
                    continue;
                }
                Remote remote = remote(in.get() & 0xFF, in.getInt(), packet.from);
                if (remote == null) {
                    continue;
                }
                remote.lastHeardMillis = now;
                if (type == Protocol.INPUT) {
                    int seq = in.getInt();
                    float x = Protocol.unpackAxis(in.get());
                    float y = Protocol.unpackAxis(in.get());
                    boolean kick = in.get() != 0;
                    if (seq > remote.lastInputSeq) {
                        remote.lastInputSeq = seq;
                        if (match != null) {
                            match.setInput(remote.id, x, y, kick);
                        }
                    }
                } else if (type == Protocol.TEAM) {
                    setTeam(remote.id, Team.byId(in.get()));
                } else {
                    removePlayer(remote.id);
                }
            } catch (RuntimeException ignored) {
                // Malformed packet.
            }
        }
    }

    private void handleJoin(SocketAddress from, int nonce, String name, long now) {
        Remote existing = remoteAt(from);
        if (existing != null && existing.nonce == nonce) {
            sendWelcome(existing);
            return;
        }
        if (existing != null) {
            removePlayer(existing.id);
        }
        if (players.size() >= MAX_PLAYERS) {
            Protocol.begin(out, Protocol.REJECT);
            out.putInt(nonce);
            Protocol.putString(out, "Room is full");
            game.send(out, from);
            return;
        }
        int id = allocateId();
        Team team = match != null ? Team.SPECTATOR : smallerTeam();
        String cleanName = name.trim().isEmpty() ? "Player " + id : name.trim();
        players.add(new LobbyPlayer(id, cleanName, team));
        Remote remote = new Remote(id, from, nonce, now);
        remotes.add(remote);
        sendWelcome(remote);
        lobbyDirty = true;
    }

    private void sendWelcome(Remote remote) {
        Protocol.begin(out, Protocol.WELCOME);
        out.putInt(remote.nonce);
        out.put((byte) remote.id);
        Protocol.putString(out, roomName);
        game.send(out, remote.address);
    }

    private int allocateId() {
        while (true) {
            int id = nextId;
            nextId = nextId >= 250 ? 1 : nextId + 1;
            if (player(id) == null) {
                return id;
            }
        }
    }

    private Team smallerTeam() {
        int red = count(Team.RED);
        int blue = count(Team.BLUE);
        if (Math.min(red, blue) >= MAX_PER_TEAM) {
            return Team.SPECTATOR;
        }
        return red <= blue ? Team.RED : Team.BLUE;
    }

    private void dropSilentClients(long now) {
        for (Iterator<Remote> it = remotes.iterator(); it.hasNext(); ) {
            Remote remote = it.next();
            if (now - remote.lastHeardMillis > CLIENT_TIMEOUT_MS) {
                it.remove();
                removeLobbyPlayer(remote.id);
            }
        }
    }

    private void removePlayer(int id) {
        for (Iterator<Remote> it = remotes.iterator(); it.hasNext(); ) {
            if (it.next().id == id) {
                it.remove();
            }
        }
        removeLobbyPlayer(id);
    }

    private void removeLobbyPlayer(int id) {
        for (Iterator<LobbyPlayer> it = players.iterator(); it.hasNext(); ) {
            if (it.next().id == id) {
                it.remove();
            }
        }
        if (match != null) {
            match.removePlayer(id);
        }
        lobbyDirty = true;
    }

    private void setTeam(int id, Team team) {
        LobbyPlayer player = player(id);
        if (player == null || match != null || player.team == team) {
            return;
        }
        if (team != Team.SPECTATOR && count(team) >= MAX_PER_TEAM) {
            return;
        }
        player.team = team;
        lobbyDirty = true;
    }

    private void sendLobby() {
        Protocol.begin(out, Protocol.LOBBY);
        out.put((byte) (match != null ? 1 : 0));
        Protocol.putString(out, roomName);
        out.put((byte) players.size());
        for (LobbyPlayer p : players) {
            out.put((byte) p.id);
            out.put((byte) p.team.id);
            Protocol.putString(out, p.name);
        }
        for (Remote remote : remotes) {
            game.send(out, remote.address);
        }
    }

    private void sendSnapshot() {
        Protocol.begin(out, Protocol.SNAPSHOT);
        Protocol.putSnapshot(out, current);
        for (Remote remote : remotes) {
            game.send(out, remote.address);
        }
    }

    private Remote remote(int id, int nonce, SocketAddress from) {
        for (Remote r : remotes) {
            if (r.id == id && r.nonce == nonce && r.address.equals(from)) {
                return r;
            }
        }
        return null;
    }

    private Remote remoteAt(SocketAddress address) {
        for (Remote r : remotes) {
            if (r.address.equals(address)) {
                return r;
            }
        }
        return null;
    }

    private LobbyPlayer player(int id) {
        for (LobbyPlayer p : players) {
            if (p.id == id) {
                return p;
            }
        }
        return null;
    }

    private int count(Team team) {
        int count = 0;
        for (LobbyPlayer p : players) {
            if (p.team == team) {
                count++;
            }
        }
        return count;
    }

    @Override
    public boolean isHost() {
        return true;
    }

    @Override
    public boolean isConnected() {
        return closedReason == null;
    }

    @Override
    public String closedReason() {
        return closedReason;
    }

    @Override
    public int localPlayerId() {
        return HOST_ID;
    }

    @Override
    public String roomName() {
        return roomName;
    }

    @Override
    public List<LobbyPlayer> players() {
        return players;
    }

    @Override
    public boolean inGame() {
        return match != null;
    }

    @Override
    public void setLocalInput(float moveX, float moveY, boolean kick) {
        inputX = moveX;
        inputY = moveY;
        inputKick = kick;
    }

    @Override
    public void requestTeam(Team team) {
        setTeam(HOST_ID, team);
    }

    @Override
    public void startGame() {
        if (match != null || count(Team.RED) + count(Team.BLUE) == 0) {
            return;
        }
        match = new Match(Stadium.classic(), SCORE_LIMIT, TIME_LIMIT_SECONDS);
        for (LobbyPlayer p : players) {
            match.addPlayer(p.id, p.team);
        }
        match.resetPositions();
        match.writeSnapshot(current);
        previous.set(current);
        accumulator = 0f;
        lobbyDirty = true;
    }

    @Override
    public void stopGame() {
        match = null;
        lobbyDirty = true;
    }

    @Override
    public Snapshot renderState() {
        if (match == null) {
            return null;
        }
        render.interpolate(previous, current, accumulator / STEP);
        return render;
    }

    @Override
    public void close() {
        if (closedReason != null) {
            return;
        }
        closedReason = "Room closed";
        Protocol.begin(out, Protocol.BYE);
        for (int i = 0; i < 3; i++) {
            for (Remote remote : remotes) {
                game.send(out, remote.address);
            }
        }
        game.close();
        if (discovery != null) {
            discovery.close();
        }
    }
}
