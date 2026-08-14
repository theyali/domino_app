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
      child: SizedBox(
        height: 450,
        child: Column(
          children: [
            const SizedBox(height: 15),

            const Text(
              'Кому подарить?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.players.length,
                itemBuilder: (context, index) {
                  final player = widget.players[index];

                  final selected = selectedPlayerIds.contains(player.id);

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
                    child: Container(
                      width: 85,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: selected
                                ? Colors.green
                                : Colors.grey.shade300,
                            child: Text(player.name[0]),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            player.isMe ? '${player.name} (Ты)' : player.name,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                ),
                itemCount: gifts.length,
                itemBuilder: (context, index) {
                  final gift = gifts[index];

                  return GestureDetector(
                    onTap: () {
                      print('Отправляем $gift игрокам: $selectedPlayerIds');

                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(gift, style: const TextStyle(fontSize: 32)),
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
