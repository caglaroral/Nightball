package com.nightball.net;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetSocketAddress;
import java.net.SocketAddress;
import java.net.SocketException;
import java.nio.ByteBuffer;
import java.util.concurrent.ConcurrentLinkedQueue;

/**
 * A UDP socket with a background receive thread. Packets are queued and read on the game thread
 * with {@link #poll()}, so all game state is touched from one thread only.
 */
public final class UdpEndpoint {
    public static final class Packet {
        public final SocketAddress from;
        public final ByteBuffer data;

        Packet(SocketAddress from, ByteBuffer data) {
            this.from = from;
            this.data = data;
        }
    }

    private static final int MAX_QUEUED = 2048;

    private final DatagramSocket socket;
    private final ConcurrentLinkedQueue<Packet> inbox = new ConcurrentLinkedQueue<Packet>();
    private final Thread thread;
    private volatile boolean running = true;

    /** Binds to the given port, or any free port when port is 0. */
    public UdpEndpoint(int port, String name) throws SocketException {
        DatagramSocket s = new DatagramSocket(null);
        try {
            s.setReuseAddress(true);
            s.setBroadcast(true);
            s.bind(new InetSocketAddress(port));
        } catch (SocketException e) {
            s.close();
            throw e;
        }
        socket = s;
        thread = new Thread(new Runnable() {
            @Override
            public void run() {
                receiveLoop();
            }
        }, name);
        thread.setDaemon(true);
        thread.start();
    }

    private void receiveLoop() {
        byte[] buffer = new byte[Protocol.MAX_PACKET];
        DatagramPacket packet = new DatagramPacket(buffer, buffer.length);
        while (running) {
            try {
                packet.setLength(buffer.length);
                socket.receive(packet);
                if (inbox.size() < MAX_QUEUED) {
                    byte[] copy = new byte[packet.getLength()];
                    System.arraycopy(buffer, 0, copy, 0, copy.length);
                    inbox.add(new Packet(packet.getSocketAddress(), ByteBuffer.wrap(copy)));
                }
            } catch (Exception e) {
                if (!running || socket.isClosed()) {
                    return;
                }
            }
        }
    }

    public Packet poll() {
        return inbox.poll();
    }

    public boolean send(ByteBuffer buffer, SocketAddress to) {
        return NetUtil.send(socket, buffer, to);
    }

    public int localPort() {
        return socket.getLocalPort();
    }

    public void close() {
        running = false;
        socket.close();
    }
}
