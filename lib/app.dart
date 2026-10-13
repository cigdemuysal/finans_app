import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'pages/root_page.dart';

// Masaüstünde (Windows/macOS/Linux) mouse ile sürükleyerek de
// kaydırabilmek için varsayılan scroll davranışını genişletiyoruz.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

class FinansApp extends StatelessWidget {
  const FinansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Açıcı Budget',
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const RootPage(),
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri == null) return null;
        final isJoinLink = uri.path == '/join' || uri.host == 'join';
        final isAuthCallback =
            uri.scheme == 'acici-budget' && uri.host == 'auth-callback';
        if (!isJoinLink && !isAuthCallback) {
          return null;
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => RootPage(
            initialTab: 3,
            inviteCode: isJoinLink ? uri.queryParameters['code'] : null,
          ),
        );
      },
    );
  }
}
