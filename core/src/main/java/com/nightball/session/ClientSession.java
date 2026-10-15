package com.nightball.session;

import com.nightball.game.Match;
import com.nightball.game.Snapshot;
import com.nightball.game.Team;
import com.nightball.net.Protocol;
import com.nightball.net.UdpEndpoint;

import java.net.InetSocketAddress;
import java.net.SocketException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * Joins a room hosted on another device. Sends input every frame and draws the host's
 * snapshots a few ticks in the past, blending between them for smooth movement.
 */
public final class ClientSession implements Session {
    private static final long JOIN_RETRY_MS = 250;
    private static final long JOIN_TIMEOUT_MS = 5000;
    private static final long HOST_TIMEOUT_MS = 4000;
    private static final long INPUT_INTERVAL_MS = 15;
    /** How far behind the newest snapshot we draw, so there is always a next one to blend to. */
    private static final float RENDER_DELAY_TICKS = 3f;
    private static final int BUFFER_SIZE = 32;

    private final InetSocketAddress host;
    private final String playerName;
    private final UdpEndpoint endpoint;
    private final int nonce = new Random().nextInt();
    private final ByteBuffer out = ByteBuffer.allocate(Protocol.MAX_PACKET);

    private final long startedMillis;
    private long nextJoinMillis;
    private long lastHeardMillis;
    private long nextInputMillis;
    private int inputSeq;
    private float inputX, inputY;
    private boolean inputKick;

    private int playerId = -1;
    private String roomName = "";
    private boolean inGame;
    private List<LobbyPlayer> players = new ArrayList<LobbyPlayer>();
    private String closedReason;

    private final Snapshot[] buffer = new Snapshot[BUFFER_SIZE];
    private final Snapshot render = new Snapshot();
    private int newestTick = -1;
    private float renderTick = -1f;

    public ClientSession(InetSocketAddress host, String playerName, long nowMillis) throws SocketException {
        this.host = host;
        this.playerName = playerName;
        this.endpoint = new UdpEndpoint(0, "nightball-client");
        this.startedMillis = nowMillis;
        for (int i = 0; i < BUFFER_SIZE; i++) {
            buffer[i] = new Snapshot();
            buffer[i].tick = -1;
        }
    }

    @Override
    public void update(float deltaSeconds, long now) {
        if (closedReason != null) {
            return;
        }
        if (playerId < 0) {
            if (now - startedMillis > JOIN_TIMEOUT_MS) {
                close("Could not reach the room");
                return;
            }
            if (now >= nextJoinMillis) {
                nextJoinMillis = now + JOIN_RETRY_MS;
                Protocol.begin(out, Protocol.JOIN);
                out.putInt(nonce);
                Protocol.putString(out, playerName);
                endpoint.send(out, host);
            }
        }

        readPackets(now);
        if (closedReason != null) {
            return;
        }

        if (playerId >= 0) {
            if (now - lastHeardMillis > HOST_TIMEOUT_MS) {
                close("Lost connection to the room");
                return;
            }
            if (now >= nextInputMillis) {
                nextInputMillis = now + INPUT_INTERVAL_MS;
                sendInput();
            }
        }
        advanceRenderClock(deltaSeconds);
    }

    private void readPackets(long now) {
        UdpEndpoint.Packet packet;
        while ((packet = endpoint.poll()) != null) {
            if (!host.equals(packet.from)) {
                continue;
            }
            ByteBuffer in = packet.data;
            try {
                int type = Protocol.readType(in);
                if (type == Protocol.WELCOME) {
                    if (in.getInt() == nonce && playerId < 0) {
                        playerId = in.get() & 0xFF;
                        roomName = Protocol.getString(in);
                        lastHeardMillis = now;
                    }
                } else if (type == Protocol.REJECT) {
                    if (in.getInt() == nonce) {
                        close(Protocol.getString(in));
                        return;
                    }
                } else if (playerId < 0) {
                    continue;
                } else if (type == Protocol.LOBBY) {
                    lastHeardMillis = now;
                    readLobby(in);
                } else if (type == Protocol.SNAPSHOT) {
                    lastHeardMillis = now;
                    readSnapshot(in);
                } else if (type == Protocol.BYE) {
                    close("The host closed the room");
                    return;
                }
            } catch (RuntimeException ignored) {
                // Malformed packet.
            }
        }
    }

    private void readLobby(ByteBuffer in) {
        boolean nowInGame = in.get() != 0;
        roomName = Protocol.getString(in);
        int count = in.get() & 0xFF;
        List<LobbyPlayer> list = new ArrayList<LobbyPlayer>(count);
        for (int i = 0; i < count; i++) {
            int id = in.get() & 0xFF;
            Team team = Team.byId(in.get());
            list.add(new LobbyPlayer(id, Protocol.getString(in), team));
        }
        players = list;
        if (inGame && !nowInGame) {
            clearSnapshots();
        }
        inGame = nowInGame;
    }

    private void readSnapshot(ByteBuffer in) {
        Snapshot scratch = render;
        if (!Protocol.getSnapshot(in, scratch)) {
            return;
        }
        // A new match restarts tick numbering.
        if (newestTick >= 0 && scratch.tick < newestTick - BUFFER_SIZE) {
            clearSnapshots();
        }
        buffer[scratch.tick % BUFFER_SIZE].set(scratch);
        if (scratch.tick > newestTick) {
            newestTick = scratch.tick;
        }
        if (renderTick < 0f) {
            renderTick = newestTick - RENDER_DELAY_TICKS;
        }
        // inGame follows LOBBY packets only, so a late snapshot cannot reopen a finished match.
    }

    private void clearSnapshots() {
        for (Snapshot s : buffer) {
            s.tick = -1;
        }
        newestTick = -1;
        renderTick = -1f;
    }

    private void advanceRenderClock(float deltaSeconds) {
        if (renderTick < 0f) {
            return;
        }
        renderTick += deltaSeconds * Match.TICKS_PER_SECOND;
        float target = newestTick - RENDER_DELAY_TICKS;
        float drift = target - renderTick;
        if (Math.abs(drift) > 20f) {
            renderTick = target;
        } else {
            // Gently catch up with or wait for the host's clock.
            renderTick += drift * 0.1f;
        }
        if (renderTick > newestTick) {
            renderTick = newestTick;
        }
    }

    private void sendInput() {
        Protocol.begin(out, Protocol.INPUT);
        out.put((byte) playerId);
        out.putInt(nonce);
        out.putInt(++inputSeq);
        out.put(Protocol.packAxis(inputX));
        out.put(Protocol.packAxis(inputY));
        out.put((byte) (inputKick ? 1 : 0));
        endpoint.send(out, host);
    }

    @Override
    public Snapshot renderState() {
        if (renderTick < 0f || !inGame) {
            return null;
        }
        int base = (int) Math.floor(renderTick);
        Snapshot before = null;
        Snapshot after = null;
        for (int t = base; t > base - BUFFER_SIZE / 2 && t >= 0 && before == null; t--) {
            before = stored(t);
        }
        for (int t = base + 1; t <= newestTick && after == null; t++) {
            after = stored(t);
        }
        if (before != null && after != null) {
            float alpha = (renderTick - before.tick) / (float) (after.tick - before.tick);
            render.interpolate(before, after, Math.max(0f, Math.min(1f, alpha)));
            return render;
        }
        Snapshot only = before != null ? before : after != null ? after : stored(newestTick);
        if (only == null) {
            return null;
        }
        render.set(only);
        return render;
    }

    private Snapshot stored(int tick) {
        if (tick < 0) {
            return null;
        }
        Snapshot s = buffer[tick % BUFFER_SIZE];
        return s.tick == tick ? s : null;
    }

    @Override
    public boolean isHost() {
        return false;
    }

    @Override
    public boolean isConnected() {
        return playerId >= 0 && closedReason == null;
    }

    @Override
    public String closedReason() {
        return closedReason;
    }

    @Override
    public int localPlayerId() {
        return playerId;
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
        return inGame;
    }

    @Override
    public void setLocalInput(float moveX, float moveY, boolean kick) {
        inputX = moveX;
        inputY = moveY;
        inputKick = kick;
    }

    @Override
    public void requestTeam(Team team) {
        if (playerId < 0) {
            return;
        }
        Protocol.begin(out, Protocol.TEAM);
        out.put((byte) playerId);
        out.putInt(nonce);
        out.put((byte) team.id);
        endpoint.send(out, host);
    }

    @Override
    public void startGame() {
    }

    @Override
    public void stopGame() {
    }

    @Override
    public void close() {
        if (closedReason == null && playerId >= 0) {
            Protocol.begin(out, Protocol.LEAVE);
            out.put((byte) playerId);
            out.putInt(nonce);
            endpoint.send(out, host);
            endpoint.send(out, host);
        }
        close("Left the room");
    }

    private void close(String reason) {
        if (closedReason == null) {
            closedReason = reason;
            endpoint.close();
        }
    }
}
