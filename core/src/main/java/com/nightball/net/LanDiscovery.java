package com.nightball.net;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.SocketException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Finds rooms on the local network: broadcasts DISCOVER once a second and collects the
 * ROOM_INFO replies. Call {@link #update(long)} from the game thread.
 */
public final class LanDiscovery {
    private static final long QUERY_INTERVAL_MS = 1000;
    private static final long ROOM_TIMEOUT_MS = 3500;

    private final UdpEndpoint endpoint;
    private final ByteBuffer out = ByteBuffer.allocate(16);
    private final Map<String, RoomInfo> rooms = new LinkedHashMap<String, RoomInfo>();
    private List<InetAddress> targets;
    private long nextQueryMillis;

    public LanDiscovery() throws SocketException {
        endpoint = new UdpEndpoint(0, "nightball-discovery");
    }

    public void update(long nowMillis) {
        if (nowMillis >= nextQueryMillis) {
            nextQueryMillis = nowMillis + QUERY_INTERVAL_MS;
            sendQuery();
        }
        UdpEndpoint.Packet packet;
        while ((packet = endpoint.poll()) != null) {
            ByteBuffer in = packet.data;
            if (Protocol.readType(in) != Protocol.ROOM_INFO || !(packet.from instanceof InetSocketAddress)) {
                continue;
            }
            try {
                String name = Protocol.getString(in);
                int gamePort = in.getShort() & 0xFFFF;
                int players = in.get() & 0xFF;
                int maxPlayers = in.get() & 0xFF;
                boolean inGame = in.get() != 0;
                InetAddress host = ((InetSocketAddress) packet.from).getAddress();
                InetSocketAddress address = new InetSocketAddress(host, gamePort);
                String key = host.getHostAddress() + ":" + gamePort;
                // Loopback replies duplicate a LAN one when host and client share a machine.
                if (host.isLoopbackAddress() && containsPort(gamePort)) {
                    continue;
                }
                if (!host.isLoopbackAddress()) {
                    rooms.remove("127.0.0.1:" + gamePort);
                }
                rooms.put(key, new RoomInfo(name, address, players, maxPlayers, inGame, nowMillis));
            } catch (RuntimeException ignored) {
                // Malformed packet.
            }
        }
        for (Iterator<RoomInfo> it = rooms.values().iterator(); it.hasNext(); ) {
            if (nowMillis - it.next().lastSeenMillis > ROOM_TIMEOUT_MS) {
                it.remove();
            }
        }
    }

    private boolean containsPort(int port) {
        for (RoomInfo room : rooms.values()) {
            if (room.address.getPort() == port && !room.address.getAddress().isLoopbackAddress()) {
                return true;
            }
        }
        return false;
    }

    private void sendQuery() {
        if (targets == null) {
            targets = NetUtil.broadcastAddresses();
            try {
                // Lets a room hosted on the same computer show up while testing.
                targets.add(InetAddress.getByName("127.0.0.1"));
            } catch (Exception ignored) {
            }
        }
        Protocol.begin(out, Protocol.DISCOVER);
        for (InetAddress target : targets) {
            endpoint.send(out, new InetSocketAddress(target, Protocol.DISCOVERY_PORT));
        }
    }

    public List<RoomInfo> rooms() {
        return new ArrayList<RoomInfo>(rooms.values());
    }

    public void close() {
        endpoint.close();
    }
}
