import 'package:bloc_pagination/bloc_pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/simple_bloc.dart';

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  late BlocPaginationLoadController<String> controller;

  @override
  void initState() {
    controller = BlocPaginationLoadController<String>(
      pageSize: 10,
      pageFuture: (page) {
        context.read<SimpleBloc>().add(LoadItems());
      },
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SimpleBloc>();

    return Scaffold(
      appBar: AppBar(title: const Text("Bloc Pagination Example")),
      body: Column(
        children: [
          Expanded(
            child: BlocPaginationListView<String>(
              pageLoadController: controller,
              loadingBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              itemBuilder: (context, item, index) =>
                  ListTile(title: Text(item)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          bloc.add(LoadItems());
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    context.read<SimpleBloc>().stream.listen((state) {
      if (state is SimpleLoaded) {
        controller.appendItems(state.items);
      } else if (state is SimpleInitial) {
        controller.reset();
      }
    });
  }
}
