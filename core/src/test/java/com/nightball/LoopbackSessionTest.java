package com.nightball;

import com.nightball.game.Snapshot;
import com.nightball.game.Team;
import com.nightball.net.LanDiscovery;
import com.nightball.net.RoomInfo;
import com.nightball.session.ClientSession;
import com.nightball.session.HostSession;
import com.nightball.session.LobbyPlayer;
import com.nightball.session.Session;
import org.junit.Test;

import java.net.InetSocketAddress;
import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

/** Runs a host and two clients over real UDP sockets on this machine. */
public class LoopbackSessionTest {

    private interface Condition {
        boolean met();
    }

    private static void pump(Condition condition, Session... sessions) throws InterruptedException {
        long deadline = System.currentTimeMillis() + 5000;
        long last = System.currentTimeMillis();
        while (!condition.met()) {
            assertTrue("timed out", System.currentTimeMillis() < deadline);
            Thread.sleep(5);
            long now = System.currentTimeMillis();
            for (Session s : sessions) {
                s.update((now - last) / 1000f, now);
            }
            last = now;
        }
    }

    @Test
    public void hostAndClientsPlayAMatch() throws Exception {
        final HostSession host = new HostSession("Host", "Test room");
        InetSocketAddress address = new InetSocketAddress("127.0.0.1", host.port());
        final ClientSession alice = new ClientSession(address, "Alice", System.currentTimeMillis());
        final ClientSession bob = new ClientSession(address, "Bob", System.currentTimeMillis());
        try {
            pump(new Condition() {
                public boolean met() {
                    return alice.isConnected() && bob.isConnected() && alice.players().size() == 3
                            && bob.players().size() == 3;
                }
            }, host, alice, bob);
            assertEquals("Test room", alice.roomName());
            // Host joined red, then teams are balanced.
            assertEquals(Team.BLUE, find(host.players(), alice.localPlayerId()).team);
            assertEquals(Team.RED, find(host.players(), bob.localPlayerId()).team);

            bob.requestTeam(Team.SPECTATOR);
            pump(new Condition() {
                public boolean met() {
                    return find(alice.players(), bob.localPlayerId()).team == Team.SPECTATOR;
                }
            }, host, alice, bob);

            host.startGame();
            pump(new Condition() {
                public boolean met() {
                    return alice.inGame() && alice.renderState() != null;
                }
            }, host, alice, bob);
            Snapshot first = alice.renderState();
            assertEquals(2, first.playerCount);
            final int aliceIndex = first.indexOf(alice.localPlayerId());
            final float startX = first.playerX[aliceIndex];

            // Alice (blue, right side) runs left; the host must simulate it and send it back.
            alice.setLocalInput(-1f, 0f, false);
            pump(new Condition() {
                public boolean met() {
                    Snapshot s = alice.renderState();
                    int i = s.indexOf(alice.localPlayerId());
                    return i >= 0 && s.playerX[i] < startX - 30f;
                }
            }, host, alice, bob);

            host.stopGame();
            pump(new Condition() {
                public boolean met() {
                    return !alice.inGame() && !bob.inGame();
                }
            }, host, alice, bob);

            bob.close();
            pump(new Condition() {
                public boolean met() {
                    return host.players().size() == 2;
                }
            }, host, alice);

            host.close();
            pump(new Condition() {
                public boolean met() {
                    return alice.closedReason() != null;
                }
            }, alice);
            assertEquals("The host closed the room", alice.closedReason());
        } finally {
            alice.close();
            bob.close();
            host.close();
        }
    }

    @Test
    public void clientGivesUpWhenNoRoomAnswers() throws Exception {
        final ClientSession lonely = new ClientSession(new InetSocketAddress("127.0.0.1", 1),
                "Nobody", System.currentTimeMillis());
        long start = System.currentTimeMillis();
        lonely.update(0f, start);
        assertNull(lonely.closedReason());
        lonely.update(0f, start + 6000);
        assertEquals("Could not reach the room", lonely.closedReason());
        assertFalse(lonely.isConnected());
    }

    @Test
    public void discoveryFindsLocalRoom() throws Exception {
        final HostSession host = new HostSession("Host", "Findable");
        final LanDiscovery discovery = new LanDiscovery();
        try {
            if (!host.isDiscoverable()) {
                return; // Discovery port in use on this machine; nothing to test.
            }
            long deadline = System.currentTimeMillis() + 5000;
            RoomInfo found = null;
            while (found == null && System.currentTimeMillis() < deadline) {
                long now = System.currentTimeMillis();
                host.update(0.005f, now);
                discovery.update(now);
                for (RoomInfo room : discovery.rooms()) {
                    if (room.name.equals("Findable") && room.address.getPort() == host.port()) {
                        found = room;
                    }
                }
                Thread.sleep(5);
            }
            assertNotNull("room not discovered", found);
            assertEquals(1, found.players);
            assertFalse(found.inGame);
        } finally {
            discovery.close();
            host.close();
        }
    }

    private static LobbyPlayer find(List<LobbyPlayer> players, int id) {
        for (LobbyPlayer p : players) {
            if (p.id == id) {
                return p;
            }
        }
        throw new AssertionError("player " + id + " missing");
    }
}
