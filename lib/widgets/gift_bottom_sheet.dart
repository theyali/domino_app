import 'package:flutter/material.dart';

import '../models/player.dart';

class GiftBottomSheet extends StatefulWidget {
  final List<Player> players;
  final Player initiallySelectedPlayer;

  const GiftBottomSheet({
    super.key,
    required this.players,
    required this.initiallySelectedPlayer,
  });

  @override
  State<GiftBottomSheet> createState() => _GiftBottomSheetState();
}

class _GiftBottomSheetState extends State<GiftBottomSheet> {
  final Set<int> selectedPlayerIds = {};

  final List<String> gifts = [
    '🌹',
    '❤️',
    '🎁',
    '🧸',
    '👑',
    '🍰',
    '☕',
    '🍹',
    '🔥',
    '💎',
  ];

  @override
  void initState() {
    super.initState();
    selectedPlayerIds.add(widget.initiallySelectedPlayer.id);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 500,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        decoration: const BoxDecoration(
          color: _LocalGiftPalette.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
          border: Border(
            top: BorderSide(color: _LocalGiftPalette.ink, width: 3),
            left: BorderSide(color: _LocalGiftPalette.ink, width: 3),
            right: BorderSide(color: _LocalGiftPalette.ink, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 54,
                height: 7,
                decoration: BoxDecoration(
                  color: _LocalGiftPalette.ink,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Transform.rotate(
                  angle: -0.06,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _LocalGiftPalette.yellow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _LocalGiftPalette.ink,
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: _LocalGiftPalette.ink,
                          blurRadius: 0,
                          offset: Offset(3, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: _LocalGiftPalette.ink,
                      size: 29,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Кому подарить?',
                        style: TextStyle(
                          color: _LocalGiftPalette.ink,
                          fontSize: 27,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Выбери одного или нескольких игроков.',
                        style: TextStyle(
                          color: _LocalGiftPalette.inkSoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.players.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final player = widget.players[index];
                  final selected = selectedPlayerIds.contains(player.id);
                  final name = player.name.trim();
                  final letter = name.isEmpty ? '?' : name[0].toUpperCase();

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          selectedPlayerIds.remove(player.id);
                        } else {
                          selectedPlayerIds.add(player.id);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 100,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selected
                            ? _LocalGiftPalette.lime
                            : _LocalGiftPalette.paper,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _LocalGiftPalette.ink,
                          width: selected ? 2.8 : 2.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: _LocalGiftPalette.ink,
                            blurRadius: 0,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? _LocalGiftPalette.mint
                                  : _LocalGiftPalette.skyBlue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _LocalGiftPalette.ink,
                                width: 2.2,
                              ),
                            ),
                            child: Text(
                              letter,
                              style: const TextStyle(
                                color: _LocalGiftPalette.ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            player.isMe ? '${player.name} (Ты)' : player.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _LocalGiftPalette.ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(
                  Icons.redeem_rounded,
                  color: _LocalGiftPalette.ink,
                  size: 22,
                ),
                SizedBox(width: 7),
                Text(
                  'Подарки',
                  style: TextStyle(
                    color: _LocalGiftPalette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 11,
                  crossAxisSpacing: 11,
                ),
                itemCount: gifts.length,
                itemBuilder: (context, index) {
                  final gift = gifts[index];
                  final cardColor = _localGiftColors[
                      index % _localGiftColors.length];

                  return GestureDetector(
                    onTap: selectedPlayerIds.isEmpty
                        ? null
                        : () {
                            debugPrint(
                              'Отправляем $gift игрокам: $selectedPlayerIds',
                            );
                            Navigator.pop(context);
                          },
                    child: Opacity(
                      opacity: selectedPlayerIds.isEmpty ? 0.45 : 1,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _LocalGiftPalette.ink,
                            width: 2.3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: _LocalGiftPalette.ink,
                              blurRadius: 0,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _LocalGiftPalette.paper,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: _LocalGiftPalette.ink,
                              width: 1.6,
                            ),
                          ),
                          child: Text(
                            gift,
                            style: const TextStyle(fontSize: 29),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _localGiftColors = <Color>[
  _LocalGiftPalette.yellow,
  _LocalGiftPalette.skyBlue,
  _LocalGiftPalette.coral,
  _LocalGiftPalette.mint,
  _LocalGiftPalette.lavender,
];

class _LocalGiftPalette {
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF574C42);
  static const Color cream = Color(0xFFFFE8B6);
  static const Color paper = Color(0xFFFFF8E8);
  static const Color lime = Color(0xFF7CFC00);
  static const Color yellow = Color(0xFFFFD65C);
  static const Color skyBlue = Color(0xFF79CDF1);
  static const Color coral = Color(0xFFFF8A79);
  static const Color mint = Color(0xFF8CDD79);
  static const Color lavender = Color(0xFFC7A7FF);
}
