import 'package:flutter/material.dart';

class CreateRoomRequest {
  final String roomName;
  final int maxPlayers;
  final String password;

  const CreateRoomRequest({
    required this.roomName,
    required this.maxPlayers,
    required this.password,
  });
}

class CreateRoomBottomSheet extends StatefulWidget {
  const CreateRoomBottomSheet({super.key});

  @override
  State<CreateRoomBottomSheet> createState() =>
      _CreateRoomBottomSheetState();
}

class _CreateRoomBottomSheetState extends State<CreateRoomBottomSheet> {
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  int _maxPlayers = 2;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _roomNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      CreateRoomRequest(
        roomName: _roomNameController.text.trim(),
        maxPlayers: _maxPlayers,
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
            const Text(
              'Создать стол',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Ты войдёшь под именем своего аккаунта. Выбери количество игроков и при желании поставь пароль.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _roomNameController,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Название стола (необязательно)',
                prefixIcon: Icon(Icons.edit_outlined),
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Количество игроков',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
              ],
              selected: {_maxPlayers},
              onSelectionChanged: (selection) {
                setState(() {
                  _maxPlayers = selection.first;
                });
              },
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              maxLength: 64,
              obscureText: _obscurePassword,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Пароль (необязательно)',
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
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Создать комнату'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
