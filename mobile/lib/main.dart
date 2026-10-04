import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/i18n.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/update.dart';
import 'widgets/common.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await initializeDateFormatting('ar');
  await appLang.load();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  final session = await Session.start();
  runApp(BoulfrikApp(session: session));
}

class BoulfrikApp extends StatelessWidget {
  const BoulfrikApp({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: session,
      // Reconstruit l'application (langue, sens de lecture) au changement de langue.
      child: ListenableBuilder(
        listenable: appLang,
        builder: (context, _) => MaterialApp(
          title: 'Boulfrik',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: Locale(appLang.code),
          supportedLocales: const [Locale('fr'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const _Root(),
        ),
      ),
    );
  }
}

/// Vérifie les mises à jour, puis affiche la connexion ou l'application selon la session.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  UpdateInfo? _blocking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  Future<void> _checkUpdate() async {
    final info = await fetchUpdateInfo(context.api);
    if (info == null || !mounted || !info.available) return;
    if (info.required) {
      setState(() => _blocking = info);
    } else {
      navigatorKey.currentState?.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => UpdateScreen(info: info)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_blocking != null) return UpdateScreen(info: _blocking!);
    final session = context.session;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: session.isLoggedIn ? const HomeShell(key: ValueKey('home')) : const LoginScreen(key: ValueKey('login')),
    );
  }
}
