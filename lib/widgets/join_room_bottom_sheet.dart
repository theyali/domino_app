import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/game_room.dart';

class JoinRoomRequest {
  final String password;

  const JoinRoomRequest({required this.password});
}

class JoinRoomBottomSheet extends StatefulWidget {
  final GameRoom room;

  const JoinRoomBottomSheet({
    super.key,
    required this.room,
  });

  @override
  State<JoinRoomBottomSheet> createState() => _JoinRoomBottomSheetState();
}

class _JoinRoomBottomSheetState extends State<JoinRoomBottomSheet> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      JoinRoomRequest(password: _passwordController.text),
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
              context.tr(
                'room_players',
                arguments: {
                  'current': widget.room.currentPlayers,
                  'max': widget.room.maxPlayers,
                },
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('join_account_description'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.room.isLocked) ...[
              const SizedBox(height: 22),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                maxLength: 64,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: context.tr('room_password'),
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
                label: Text(context.tr('join_table')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
