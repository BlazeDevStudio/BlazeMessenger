part of '../protocol.dart';

// A discovered endpoint is a transport claim, not an approved/trusted device.
class Peer {
  final String id;
  final String name;
  final String key;
  final String host;
  final int port;
  final DateTime seen;

  const Peer({required this.id, required this.name, required this.key,
    required this.host, required this.port, required this.seen});

  String get shortCode => id.substring(0, min(8, id.length)).toUpperCase();
  Uri uri(String path) => Uri(scheme: 'http', host: host, port: port, path: path);

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'key': key, 'host': host, 'port': port,
  };

  static Peer? fromDiscovery(Map<String, dynamic> json, String host) {
    if (json['v'] != protocolVersion) return null;
    final id = json['id'];
    final name = json['name'];
    final key = json['key'];
    final port = json['port'];
    if (id is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) return null;
    if (name is! String || name.trim().isEmpty || name.length > 80) return null;
    if (key is! String || port is! int || port < 1 || port > 65535) return null;
    try {
      final publicKey = base64Decode(key);
      if (publicKey.length != 32 || fingerprint(publicKey) != id) return null;
    } catch (_) { return null; }
    return Peer(id: id, name: name, key: key, host: host,
      port: port, seen: DateTime.now());
  }
}
