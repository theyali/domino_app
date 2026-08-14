import 'package:flutter/material.dart';

import '../models/game_room.dart';

class JoinRoomRequest {
  final String playerName;
  final String password;

  const JoinRoomRequest({
    required this.playerName,
    required this.password,
  });
}

class JoinRoomBottomSheet extends StatefulWidget {
  final GameRoom room;
  final String initialPlayerName;

  const JoinRoomBottomSheet({
    super.key,
    required this.room,
    this.initialPlayerName = '',
  });

  @override
  State<JoinRoomBottomSheet> createState() => _JoinRoomBottomSheetState();
}

class _JoinRoomBottomSheetState extends State<JoinRoomBottomSheet> {
  late final TextEditingController _playerNameController;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _playerNameController = TextEditingController(text: widget.initialPlayerName);
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final playerName = _playerNameController.text.trim();

    if (playerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите имя игрока.')),
      );
      return;
    }

    Navigator.of(context).pop(
      JoinRoomRequest(
        playerName: playerName,
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.room.displayName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.room.currentPlayers} / ${widget.room.maxPlayers} игроков',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _playerNameController,
              maxLength: 40,
              textInputAction: widget.room.isLocked
                  ? TextInputAction.next
                  : TextInputAction.done,
              onSubmitted: widget.room.isLocked ? null : (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Твоё имя',
                prefixIcon: Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            if (widget.room.isLocked) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                maxLength: 64,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Пароль комнаты',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: const OutlineInputBorder(),
                  counterText: '',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Войти за стол'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
