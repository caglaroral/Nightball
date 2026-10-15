class_name NetUtil


## Interfaces created by containers, VMs and VPNs; other players cannot reach us through them.
const VIRTUAL_INTERFACES := ["docker", "br-", "veth", "lxc", "virbr", "vmnet", "vboxnet", "tun",
		"tap", "wg", "zt", "tailscale", "utun", "llw", "awdl", "bridge"]


## IPv4 addresses of this device on the local network, for showing to other players.
static func local_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for iface in IP.get_local_interfaces():
		if _is_virtual(String(iface["name"]).to_lower()):
			continue
		for address in iface["addresses"]:
			if _is_private_ipv4(address) and not result.has(address):
				result.append(address)
	result.sort()
	return result


static func _is_virtual(interface_name: String) -> bool:
	for prefix in VIRTUAL_INTERFACES:
		if interface_name.begins_with(prefix):
			return true
	return false


## Where room searches are sent: the global broadcast address, each local /24 network's
## broadcast address (Godot does not expose netmasks; home networks are almost always /24)
## and loopback so rooms on the same computer show up while testing.
static func discovery_targets() -> PackedStringArray:
	var result := PackedStringArray(["255.255.255.255", "127.0.0.1"])
	for address in local_addresses():
		var parts := address.split(".")
		var broadcast := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		if not result.has(broadcast):
			result.append(broadcast)
	return result


static func _is_private_ipv4(address: String) -> bool:
	if not address.is_valid_ip_address() or address.contains(":"):
		return false
	var parts := address.split(".")
	var a := parts[0].to_int()
	var b := parts[1].to_int()
	return a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168)


static func send(peer: PacketPeerUDP, packet: StreamPeerBuffer, ip: String, port: int) -> void:
	if peer == null or not peer.is_bound():
		return
	peer.set_dest_address(ip, port)
	# A failed send on a LAN is treated like a lost packet.
	peer.put_packet(packet.data_array)
