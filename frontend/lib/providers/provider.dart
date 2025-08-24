import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'photo_provider.dart';
import 'album_provider.dart';

final List<ChangeNotifierProvider> globalProviders = [
  ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
  ChangeNotifierProvider<PhotoProvider>(create: (_) => PhotoProvider()),
  ChangeNotifierProvider<AlbumProvider>(create: (_) => AlbumProvider()),
];

class AppProviders extends StatelessWidget {
  final Widget child;
  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(providers: globalProviders, child: child);
  }
}
