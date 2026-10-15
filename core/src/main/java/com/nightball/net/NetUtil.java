package com.nightball.net;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.InterfaceAddress;
import java.net.NetworkInterface;
import java.net.SocketAddress;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public final class NetUtil {
    private NetUtil() {
    }

    /** IPv4 addresses of this device on the local network, for showing to other players. */
    public static List<String> localAddresses() {
        List<String> result = new ArrayList<String>();
        for (InterfaceAddress address : interfaceAddresses()) {
            InetAddress ip = address.getAddress();
            if (ip.isSiteLocalAddress()) {
                result.add(ip.getHostAddress());
            }
        }
        return result;
    }

    /** Broadcast address of every active IPv4 network, plus the global broadcast address. */
    public static List<InetAddress> broadcastAddresses() {
        List<InetAddress> result = new ArrayList<InetAddress>();
        for (InterfaceAddress address : interfaceAddresses()) {
            InetAddress broadcast = address.getBroadcast();
            if (broadcast != null && !result.contains(broadcast)) {
                result.add(broadcast);
            }
        }
        try {
            InetAddress global = InetAddress.getByName("255.255.255.255");
            if (!result.contains(global)) {
                result.add(global);
            }
        } catch (Exception ignored) {
        }
        return result;
    }

    private static List<InterfaceAddress> interfaceAddresses() {
        List<InterfaceAddress> result = new ArrayList<InterfaceAddress>();
        try {
            for (NetworkInterface ni : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                if (!ni.isUp() || ni.isLoopback()) {
                    continue;
                }
                for (InterfaceAddress address : ni.getInterfaceAddresses()) {
                    if (address.getAddress() instanceof Inet4Address) {
                        result.add(address);
                    }
                }
            }
        } catch (Exception ignored) {
            // Some platforms restrict interface enumeration; callers fall back to defaults.
        }
        return result;
    }

    /** Sends without throwing: on a LAN a failed send is treated like a lost packet. */
    public static boolean send(DatagramSocket socket, ByteBuffer buffer, SocketAddress to) {
        if (socket == null || socket.isClosed()) {
            return false;
        }
        try {
            socket.send(new DatagramPacket(buffer.array(), buffer.position(), to));
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
