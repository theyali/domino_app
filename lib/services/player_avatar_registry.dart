import 'package:flutter/widgets.dart';

class PlayerAvatarRegistry {
  PlayerAvatarRegistry._();

  static final PlayerAvatarRegistry instance = PlayerAvatarRegistry._();

  final Map<int, _AvatarRegistration> _registrations =
      <int, _AvatarRegistration>{};

  void register({
    required int playerId,
    required Object owner,
    required BuildContext context,
  }) {
    _registrations[playerId] = _AvatarRegistration(
      owner: owner,
      context: context,
    );
  }

  void unregister({
    required int playerId,
    required Object owner,
  }) {
    final current = _registrations[playerId];
    if (current == null || !identical(current.owner, owner)) {
      return;
    }
    _registrations.remove(playerId);
  }

  Offset? globalCenterFor(int playerId) {
    final registration = _registrations[playerId];
    final context = registration?.context;
    if (context == null) return null;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    return renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
    );
  }
}

class _AvatarRegistration {
  final Object owner;
  final BuildContext context;

  const _AvatarRegistration({
    required this.owner,
    required this.context,
  });
}
