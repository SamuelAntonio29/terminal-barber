import 'package:flutter/material.dart';
import 'main.dart';

class AppBarCustom extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;

  const AppBarCustom({super.key, required this.title, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      actions: [
        IconButton(
          icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round),
          tooltip: isDark ? 'Modo claro' : 'Modo escuro',
          onPressed: () => MyApp.of(context)?.toggleTheme(),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
