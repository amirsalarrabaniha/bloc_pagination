import 'package:example/simple_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/simple_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Bloc Example',
      home: BlocProvider(
        create: (_) => SimpleBloc(),
        child: const ExamplePage(),
      ),
    );
  }
}
