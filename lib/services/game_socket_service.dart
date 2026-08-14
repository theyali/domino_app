import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import 'active_game_session_store.dart';
import 'emotion_realtime_service.dart';
import 'gift_realtime_service.dart';

enum SocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class GameSocketService with WidgetsBindingObserver {
  static const Duration _heartbeatInterval = Duration(seconds: 10);
  static const Duration _heartbeatTimeout = Duration(seconds: 30);
  static const Duration _stateSyncTimeout = Duration(seconds: 8);

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<SocketConnectionStatus> _statusController =
      StreamController<SocketConnectionStatus>.broadcast();
  final ActiveGameSessionStore _sessionStore;
  final EmotionRealtimeService _emotionService = EmotionRealtimeService.instance;
  final GiftRealtimeService _giftService = GiftRealtimeService.instance;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _stateSyncTimer;

  int? _roomId;
  int? _playerId;
  int _connectionGeneration = 0;
  int _reconnectAttempt = 0;

  DateTime? _lastPongAt;
  bool _manualClose = false;
  bool _disposed = false;
  SocketConnectionStatus _status = SocketConnectionStatus.disconnected;

  GameSocketService({ActiveGameSessionStore? sessionStore})
      : _sessionStore = sessionStore ?? ActiveGameSessionStore() {
    WidgetsBinding.instance.addObserver(this);
  }

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Stream<SocketConnectionStatus> get statuses => _statusController.stream;

  SocketConnectionStatus get status => _status;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _disposed || _manualClose) {
      return;
    }

    final roomId = _roomId;
    final playerId = _playerId;
    if (roomId == null || playerId == null) return;

    unawaited(
      connectToRoom(
        roomId: roomId,
        playerId: playerId,
        reconnecting: true,
      ),
    );
  }

  Future<void> connectToRoom({
    required int roomId,
    required int playerId,
    bool reconnecting = false,
  }) async {
    if (_disposed) return;

    _roomId = roomId;
    _playerId = playerId;
    _manualClose = false;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _connectionGeneration += 1;
    final generation = _connectionGeneration;

    await _closeCurrentConnection();

    if (_disposed || _manualClose || generation != _connectionGeneration) {
      return;
    }

    unawaited(
      _openConnection(
        generation: generation,
        reconnecting: reconnecting,
      ),
    );
  }

  void send(Map<String, dynamic> message) {
    if (_status != SocketConnectionStatus.connected) return;
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> disconnect() async {
    if (_disposed && _manualClose) return;

    _manualClose = true;
    _connectionGeneration += 1;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _closeCurrentConnection();
    _setStatus(SocketConnectionStatus.disconnected);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _emotionService.detachSender(this);
    await disconnect();
    await _messageController.close();
    await _statusController.close();
  }

  Future<void> _openConnection({
    required int generation,
    required bool reconnecting,
  }) async {
    final roomId = _roomId;
    final playerId = _playerId;

    if (_disposed ||
        _manualClose ||
        roomId == null ||
        playerId == null ||
        generation != _connectionGeneration) {
      return;
    }

    _setStatus(
      reconnecting
          ? SocketConnectionStatus.reconnecting
          : SocketConnectionStatus.connecting,
    );

    final uri = ApiConfig.webSocketUri(
      '/ws/rooms/$roomId/',
      queryParameters: {'player_id': '$playerId'},
    );

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    _channelSubscription = channel.stream.listen(
      (event) => _handleIncomingMessage(
        event,
        generation: generation,
        channel: channel,
      ),
      onError: (_) => _handleDisconnected(
        generation: generation,
        channel: channel,
      ),
      onDone: () => _handleDisconnected(
        generation: generation,
        channel: channel,
      ),
      cancelOnError: false,
    );

    try {
      await channel.ready.timeout(const Duration(seconds: 8));

      if (!_isCurrentConnection(
        generation: generation,
        channel: channel,
      )) {
        await channel.sink.close();
        return;
      }

      _lastPongAt = DateTime.now();

      // Django sends room/game state immediately after accepting the socket.
      // We announce `connected` only after that authoritative state reaches
      // Flutter, not merely after the WebSocket handshake succeeds.
      if (_status != SocketConnectionStatus.connected) {
        _stateSyncTimer?.cancel();
        _stateSyncTimer = Timer(_stateSyncTimeout, () {
          _stateSyncTimer = null;

          if (!_isCurrentConnection(
                generation: generation,
                channel: channel,
              ) ||
              _status == SocketConnectionStatus.connected) {
            return;
          }

          unawaited(channel.sink.close());
          _handleDisconnected(
            generation: generation,
            channel: channel,
          );
        });
      }

      channel.sink.add(jsonEncode(const {'type': 'ping'}));
    } catch (_) {
      _handleDisconnected(
        generation: generation,
        channel: channel,
      );
    }
  }

  void _handleIncomingMessage(
    dynamic event, {
    required int generation,
    required WebSocketChannel channel,
  }) {
    if (!_isCurrentConnection(
      generation: generation,
      channel: channel,
    )) {
      return;
    }

    if (event is! String) return;

    try {
      final decoded = jsonDecode(event);
      if (decoded is! Map) return;

      final message = Map<String, dynamic>.from(decoded);
      _lastPongAt = DateTime.now();

      final type = message['type'];
      final isAuthoritativeState =
          type == 'room_state' || type == 'game_started' || type == 'game_state';

      if (isAuthoritativeState &&
          _status != SocketConnectionStatus.connected) {
        _stateSyncTimer?.cancel();
        _stateSyncTimer = null;
        _reconnectAttempt = 0;
        _setStatus(SocketConnectionStatus.connected);
        _attachEmotionSender(
          generation: generation,
          channel: channel,
        );
        _startHeartbeat(
          generation: generation,
          channel: channel,
        );
      }

      if (type == 'player_emotion') {
        _emotionService.handleSocketMessage(message);
      }
      _giftService.handleSocketMessage(message);

      if (type == 'pong') {
        return;
      }

      final roomId = _roomId;
      final playerId = _playerId;

      if ((type == 'game_started' || type == 'game_state') &&
          roomId != null &&
          playerId != null) {
        unawaited(
          _sessionStore.save(
            roomId: roomId,
            playerId: playerId,
          ),
        );
      }

      if (type == 'room_deleted' && roomId != null && playerId != null) {
        unawaited(
          _sessionStore.clearIfMatches(
            roomId: roomId,
            playerId: playerId,
          ),
        );
      }

      _messageController.add(message);
    } catch (_) {
      // Ignore malformed messages. The connection itself can stay alive.
    }
  }

  void _attachEmotionSender({
    required int generation,
    required WebSocketChannel channel,
  }) {
    _emotionService.attachSender(
      owner: this,
      sender: (assetPath) {
        if (!_isCurrentConnection(
              generation: generation,
              channel: channel,
            ) ||
            _status != SocketConnectionStatus.connected) {
          return false;
        }

        try {
          channel.sink.add(
            jsonEncode({
              'type': 'emotion',
              'emotion': assetPath,
            }),
          );
          return true;
        } catch (_) {
          return false;
        }
      },
    );
  }

  void _startHeartbeat({
    required int generation,
    required WebSocketChannel channel,
  }) {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (!_isCurrentConnection(
            generation: generation,
            channel: channel,
          ) ||
          _status != SocketConnectionStatus.connected) {
        timer.cancel();
        return;
      }

      final lastPongAt = _lastPongAt;
      if (lastPongAt != null &&
          DateTime.now().difference(lastPongAt) > _heartbeatTimeout) {
        timer.cancel();
        _heartbeatTimer = null;

        unawaited(channel.sink.close());
        _handleDisconnected(
          generation: generation,
          channel: channel,
        );
        return;
      }

      channel.sink.add(jsonEncode(const {'type': 'ping'}));
    });
  }

  void _handleDisconnected({
    required int generation,
    required WebSocketChannel channel,
  }) {
    if (!_isCurrentConnection(
      generation: generation,
      channel: channel,
    )) {
      return;
    }

    // Detach this exact socket before scheduling a replacement. Any delayed
    // onDone/onError callback from it will then fail _isCurrentConnection and
    // cannot knock a newer socket back into reconnecting state.
    final subscription = _channelSubscription;
    _channelSubscription = null;
    _channel = null;

    _emotionService.detachSender(this);
    _stateSyncTimer?.cancel();
    _stateSyncTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastPongAt = null;

    unawaited(subscription?.cancel());

    _setStatus(SocketConnectionStatus.disconnected);
    _scheduleReconnect(generation);
  }

  void _scheduleReconnect(int generation) {
    if (_disposed ||
        _manualClose ||
        generation != _connectionGeneration ||
        (_reconnectTimer?.isActive ?? false)) {
      return;
    }

    const retryDelays = <int>[1, 2, 3, 5, 5];
    final index = _reconnectAttempt < retryDelays.length
        ? _reconnectAttempt
        : retryDelays.length - 1;
    final delaySeconds = retryDelays[index];
    _reconnectAttempt += 1;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;

      if (_disposed ||
          _manualClose ||
          generation != _connectionGeneration) {
        return;
      }

      unawaited(
        _openConnection(
          generation: generation,
          reconnecting: true,
        ),
      );
    });
  }

  bool _isCurrentConnection({
    required int generation,
    required WebSocketChannel channel,
  }) {
    return !_disposed &&
        !_manualClose &&
        generation == _connectionGeneration &&
        identical(_channel, channel);
  }

  Future<void> _closeCurrentConnection() async {
    final subscription = _channelSubscription;
    final channel = _channel;

    _emotionService.detachSender(this);
    _stateSyncTimer?.cancel();
    _stateSyncTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastPongAt = null;
    _channelSubscription = null;
    _channel = null;

    await subscription?.cancel();

    try {
      await channel?.sink.close();
    } catch (_) {
      // The socket may already be closed by the server.
    }
  }

  void _setStatus(SocketConnectionStatus value) {
    if (_status == value) return;
    _status = value;

    if (!_statusController.isClosed) {
      _statusController.add(value);
    }
  }
}
