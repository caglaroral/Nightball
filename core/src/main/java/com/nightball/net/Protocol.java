package com.nightball.net;

import com.nightball.game.MatchState;
import com.nightball.game.Snapshot;
import com.nightball.game.Team;

import java.nio.BufferUnderflowException;
import java.nio.ByteBuffer;
import java.nio.charset.Charset;

/**
 * UDP message format. Every packet starts with MAGIC (2 bytes), VERSION and a type byte.
 *
 * Reliability model: the host repeats the lobby state several times per second and sends a full
 * snapshot every tick, and clients send their full input every frame, so a lost packet is simply
 * replaced by the next one. Only JOIN is retried until answered.
 */
public final class Protocol {
    public static final int DISCOVERY_PORT = 47777;
    public static final int GAME_PORT = 47778;
    public static final int MAX_PACKET = 1400;
    public static final int MAX_NAME_BYTES = 24;

    static final short MAGIC = 0x4E42;
    static final byte VERSION = 1;

    // Discovery
    public static final byte DISCOVER = 1;
    public static final byte ROOM_INFO = 2;
    // Client -> host
    public static final byte JOIN = 3;
    public static final byte INPUT = 6;
    public static final byte TEAM = 7;
    public static final byte LEAVE = 8;
    // Host -> client
    public static final byte WELCOME = 4;
    public static final byte REJECT = 5;
    public static final byte LOBBY = 9;
    public static final byte SNAPSHOT = 10;
    public static final byte BYE = 11;

    private static final Charset UTF8 = Charset.forName("UTF-8");

    private Protocol() {
    }

    public static ByteBuffer begin(ByteBuffer buffer, byte type) {
        buffer.clear();
        buffer.putShort(MAGIC);
        buffer.put(VERSION);
        buffer.put(type);
        return buffer;
    }

    /** Returns the message type, or -1 if the packet is not ours or from another version. */
    public static int readType(ByteBuffer buffer) {
        if (buffer.remaining() < 4 || buffer.getShort() != MAGIC || buffer.get() != VERSION) {
            return -1;
        }
        return buffer.get();
    }

    public static void putString(ByteBuffer buffer, String value) {
        byte[] bytes = value.getBytes(UTF8);
        int length = Math.min(bytes.length, MAX_NAME_BYTES);
        // Do not cut a multi-byte character in half.
        while (length > 0 && length < bytes.length && (bytes[length] & 0xC0) == 0x80) {
            length--;
        }
        buffer.put((byte) length);
        buffer.put(bytes, 0, length);
    }

    public static String getString(ByteBuffer buffer) {
        int length = buffer.get() & 0xFF;
        byte[] bytes = new byte[length];
        buffer.get(bytes);
        return new String(bytes, UTF8);
    }

    public static void putSnapshot(ByteBuffer b, Snapshot s) {
        b.putInt(s.tick);
        b.put((byte) s.state.ordinal());
        b.put((byte) s.redScore);
        b.put((byte) s.blueScore);
        b.putInt(s.timeTicks);
        b.putShort((short) s.timeLimitSeconds);
        b.put((byte) s.kickoffTeam.id);
        b.put((byte) s.lastScorer.id);
        b.putFloat(s.ballX);
        b.putFloat(s.ballY);
        b.put((byte) s.playerCount);
        for (int i = 0; i < s.playerCount; i++) {
            b.put((byte) s.playerIds[i]);
            b.put((byte) (s.playerTeams[i].id | (s.playerKicking[i] ? 0x80 : 0)));
            b.putFloat(s.playerX[i]);
            b.putFloat(s.playerY[i]);
        }
    }

    public static boolean getSnapshot(ByteBuffer b, Snapshot s) {
        try {
            s.tick = b.getInt();
            s.state = MatchState.byOrdinal(b.get());
            s.redScore = b.get() & 0xFF;
            s.blueScore = b.get() & 0xFF;
            s.timeTicks = b.getInt();
            s.timeLimitSeconds = b.getShort() & 0xFFFF;
            s.kickoffTeam = Team.byId(b.get());
            s.lastScorer = Team.byId(b.get());
            s.ballX = b.getFloat();
            s.ballY = b.getFloat();
            int count = Math.min(b.get() & 0xFF, Snapshot.MAX_PLAYERS);
            for (int i = 0; i < count; i++) {
                s.playerIds[i] = b.get() & 0xFF;
                int flags = b.get();
                s.playerTeams[i] = Team.byId(flags & 0x7F);
                s.playerKicking[i] = (flags & 0x80) != 0;
                s.playerX[i] = b.getFloat();
                s.playerY[i] = b.getFloat();
            }
            s.playerCount = count;
            return true;
        } catch (BufferUnderflowException e) {
            return false;
        }
    }

    /** Movement axis quantised to a signed byte. */
    public static byte packAxis(float value) {
        return (byte) Math.round(Math.max(-1f, Math.min(1f, value)) * 127f);
    }

    public static float unpackAxis(byte value) {
        return value / 127f;
    }
}
