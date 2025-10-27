import 'package:flutter/material.dart';
import 'package:db_handler/views/splash.dart';
import 'package:db_handler/views/server_selection.dart';
import 'package:db_handler/views/database_selection.dart';
import 'package:db_handler/views/table_selection.dart';
import 'package:db_handler/views/data_editing.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DB Handler',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/server-selection': (context) => const ServerSelectionScreen(),
        '/database-selection': (context) {
          final server = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return DatabaseSelectionScreen(server: server);
        },
        '/table-selection': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          final server = args['server'] as Map<String, dynamic>;
          final database = args['database'] as String;
          return TableSelectionScreen(server: server, database: database);
        },
        '/data-editing': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          final server = args['server'] as Map<String, dynamic>;
          final database = args['database'] as String;
          final table = args['table'] as String;
          return DataEditingScreen(server: server, database: database, table: table);
        },
      },
    );
  }
}
