import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/photo_provider.dart';
import 'package:frontend/presentation/screens/photo/photo_viewer_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = context.select<PhotoProvider, List<dynamic>>(
      (p) => p.items.where((e) => e.favorite == true).toList(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('즐겨찾기')),
      body: favorites.isEmpty
          ? const Center(child: Text('즐겨찾기한 사진이 없습니다.'))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final it = favorites[index];
                final String imageUrl = it.imageUrl ?? '';
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhotoViewerScreen(
                          photoId: it.photoId,
                          imageUrl: imageUrl,
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: imageUrl.isEmpty
                        ? Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image),
                            ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            },
                          ),
                  ),
                );
              },
            ),
    );
  }
}
