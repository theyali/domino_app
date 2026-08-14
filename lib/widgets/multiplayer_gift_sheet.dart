import 'package:flutter/material.dart';

import '../models/gift.dart';
import '../models/multiplayer_game_state.dart';
import '../services/gift_service.dart';

class GiftSendRequest {
  final int giftId;
  final List<int> recipientPlayerIds;

  const GiftSendRequest({
    required this.giftId,
    required this.recipientPlayerIds,
  });
}

class MultiplayerGiftSheet extends StatefulWidget {
  final int restaurantId;
  final int myPlayerId;
  final int initialRecipientPlayerId;
  final List<MultiplayerPlayerState> players;

  const MultiplayerGiftSheet({
    super.key,
    required this.restaurantId,
    required this.myPlayerId,
    required this.initialRecipientPlayerId,
    required this.players,
  });

  static Future<GiftSendRequest?> show(
    BuildContext context, {
    required int restaurantId,
    required int myPlayerId,
    required int initialRecipientPlayerId,
    required List<MultiplayerPlayerState> players,
  }) {
    return showModalBottomSheet<GiftSendRequest>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => MultiplayerGiftSheet(
        restaurantId: restaurantId,
        myPlayerId: myPlayerId,
        initialRecipientPlayerId: initialRecipientPlayerId,
        players: players,
      ),
    );
  }

  @override
  State<MultiplayerGiftSheet> createState() => _MultiplayerGiftSheetState();
}

class _GiftInventoryGroup {
  final Gift gift;
  final int count;

  const _GiftInventoryGroup({required this.gift, required this.count});
}

class _MultiplayerGiftSheetState extends State<MultiplayerGiftSheet> {
  static const GiftService _giftService = GiftService();

  bool _isLoading = true;
  String? _errorMessage;
  List<_GiftInventoryGroup> _groups = const [];
  int? _selectedGiftId;
  final Set<int> _recipientIds = <int>{};

  @override
  void initState() {
    super.initState();
    if (widget.initialRecipientPlayerId != widget.myPlayerId) {
      _recipientIds.add(widget.initialRecipientPlayerId);
    }
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final inventory = await _giftService.fetchInventory();
      final available = inventory.where(
        (item) =>
            item.isAvailable && item.gift.restaurantId == widget.restaurantId,
      );

      final grouped = <int, List<InventoryGift>>{};
      for (final item in available) {
        grouped.putIfAbsent(item.gift.id, () => <InventoryGift>[]).add(item);
      }

      final groups = grouped.values
          .map(
            (items) => _GiftInventoryGroup(
              gift: items.first.gift,
              count: items.length,
            ),
          )
          .toList()
        ..sort((a, b) => a.gift.name.compareTo(b.gift.name));

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGiftId = groups.isEmpty ? null : groups.first.gift.id;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  List<MultiplayerPlayerState> get _availableRecipients => widget.players
      .where(
        (player) =>
            player.id != widget.myPlayerId &&
            player.isActive &&
            player.userId != null,
      )
      .toList(growable: false);

  _GiftInventoryGroup? get _selectedGroup {
    final selectedId = _selectedGiftId;
    if (selectedId == null) return null;

    for (final group in _groups) {
      if (group.gift.id == selectedId) {
        return group;
      }
    }
    return null;
  }

  void _toggleRecipient(int playerId) {
    setState(() {
      if (_recipientIds.contains(playerId)) {
        _recipientIds.remove(playerId);
      } else {
        _recipientIds.add(playerId);
      }
    });
  }

  void _submit() {
    final group = _selectedGroup;
    if (group == null || _recipientIds.isEmpty) return;

    if (group.count < _recipientIds.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Нужно ${_recipientIds.length} шт. «${group.gift.name}», '
            'а в инвентаре ${group.count}.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      GiftSendRequest(
        giftId: group.gift.id,
        recipientPlayerIds: _recipientIds.toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipients = _availableRecipients;
    final selectedGroup = _selectedGroup;
    final canSubmit = selectedGroup != null &&
        _recipientIds.isNotEmpty &&
        selectedGroup.count >= _recipientIds.length;

    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Отправить подарок',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              'Можно выбрать нескольких игроков. Самого себя выбрать нельзя.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            const Text(
              'Получатели',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final player in recipients)
                  FilterChip(
                    selected: _recipientIds.contains(player.id),
                    onSelected: (_) => _toggleRecipient(player.id),
                    avatar: CircleAvatar(
                      child: Text(
                        player.name.trim().isEmpty
                            ? '?'
                            : player.name.trim()[0].toUpperCase(),
                      ),
                    ),
                    label: Text(player.name),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Мои подарки этого ресторана',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (!_isLoading)
                  Text(
                    '${_groups.fold<int>(0, (sum, item) => sum + item.count)} шт.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _buildGiftList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: canSubmit ? _submit : null,
                icon: const Icon(Icons.card_giftcard_rounded),
                label: Text(
                  _recipientIds.length <= 1
                      ? 'Отправить подарок'
                      : 'Отправить ${_recipientIds.length} подарка',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadInventory,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'В инвентаре пока нет доступных подарков этого ресторана.\n'
            'Для теста выдай их пользователю через Django Admin.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        final selected = _selectedGiftId == group.gift.id;

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              _selectedGiftId = group.gift.id;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: group.gift.imageUrl?.trim().isNotEmpty == true
                        ? Image.network(
                            group.gift.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.card_giftcard_rounded, size: 44),
                          )
                        : const Icon(Icons.card_giftcard_rounded, size: 44),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  group.gift.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${group.count} шт. · ${group.gift.price}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
