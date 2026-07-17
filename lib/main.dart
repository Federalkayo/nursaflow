import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

 import 'package:firebase_core/firebase_core.dart';
 import 'firebase_options.dart'; 

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/local_notifications_service.dart';
import 'core/services/push_notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: uncomment once `flutterfire configure` has generated
  // firebase_options.dart for this project.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await LocalNotificationsService.init();
  await PushNotificationsService.init();

  runApp(const ProviderScope(child: NursaFlowApp()));
}

class NursaFlowApp extends ConsumerWidget {
  const NursaFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'NursaFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light, 
      routerConfig: router,
    );
  }
}
