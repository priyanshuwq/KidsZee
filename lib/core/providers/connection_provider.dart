import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectionStatus { idle, scanning, connecting, connected, disconnected, error }
enum Protocol { ble, btClassic, webSocket, mqtt }

class ConnectionState {
  final ConnectionStatus status;
  final Protocol protocol;
  final String? deviceName;
  final String? deviceId;
  final String? errorMessage;

  const ConnectionState({
    this.status = ConnectionStatus.idle,
    this.protocol = Protocol.ble,
    this.deviceName,
    this.deviceId,
    this.errorMessage,
  });

  bool get isConnected => status == ConnectionStatus.connected;

  ConnectionState copyWith({
    ConnectionStatus? status,
    Protocol? protocol,
    String? deviceName,
    String? deviceId,
    String? errorMessage,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      protocol: protocol ?? this.protocol,
      deviceName: deviceName ?? this.deviceName,
      deviceId: deviceId ?? this.deviceId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  ConnectionNotifier() : super(const ConnectionState());

  void startScan(Protocol protocol) {
    state = state.copyWith(
      status: ConnectionStatus.scanning,
      protocol: protocol,
    );
  }

  void connect(String deviceId, String deviceName) {
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      deviceId: deviceId,
      deviceName: deviceName,
    );
  }

  void onConnected() {
    state = state.copyWith(status: ConnectionStatus.connected);
  }

  void onDisconnected() {
    state = state.copyWith(
      status: ConnectionStatus.disconnected,
      deviceName: null,
      deviceId: null,
    );
  }

  void setError(String msg) {
    state = state.copyWith(
      status: ConnectionStatus.error,
      errorMessage: msg,
    );
  }

  void setProtocol(Protocol protocol) {
    state = state.copyWith(protocol: protocol);
  }

  void reset() {
    state = const ConnectionState();
  }
}

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionState>(
  (ref) => ConnectionNotifier(),
);
