import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/photo_provider.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context
        .watch<PhotoProvider>()
        .items
        .where((e) => e.favorite)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('즐겨찾기')),
      body: items.isEmpty
          ? const Center(child: Text('즐겨찾기한 사진이 없습니다.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.72,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final it = items[i];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    it.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFFE0E0E0)),
                  ),
                );
              },
            ),
    );
  }
}
