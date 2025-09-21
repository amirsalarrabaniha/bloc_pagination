# flutter_bloc_pagination

A **simple and flexible pagination controller** for Flutter BLoC.
Easily load pages, refresh items, and integrate with your BLoC architecture using a controller-based approach.

---

## Features

* Load items page by page
* Controller-based API (`BlocPaginationLoadController`)
* Refresh or reset the list
* Works seamlessly with `BlocBuilder`
* Easy integration with existing BLoC code

---

## Installation

Add the dependency in your `pubspec.yaml`:

```yaml
dependencies:
  bloc_pagination: ^0.0.1
```

Then run:

```bash
flutter pub get
```

---

## Usage

### 1. Create a Bloc

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class SimpleEvent {}
class LoadItems extends SimpleEvent {}

abstract class SimpleState {}
class SimpleInitial extends SimpleState {}
class SimpleLoading extends SimpleState {}
class SimpleLoaded extends SimpleState {
  final List<String> items;
  SimpleLoaded(this.items);
}

class SimpleBloc extends Bloc<SimpleEvent, SimpleState> {
  SimpleBloc() : super(SimpleInitial()) {
    on<LoadItems>((event, emit) async {
      emit(SimpleLoading());
      await Future.delayed(const Duration(seconds: 1));
      emit(SimpleLoaded(["Item 1", "Item 2"]));
    });
  }
}
```

---

### 2. Use `BlocPaginationLoadController` in your UI

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_pagination/bloc_pagination.dart';
import 'bloc/simple_bloc.dart';

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  final BlocPaginationLoadController<String> controller =
      BlocPaginationLoadController<String>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final bloc = context.read<SimpleBloc>();

    // Listen to Bloc stream and append items to controller
    bloc.stream.listen((state) {
      if (state is SimpleLoaded) {
        controller.appendItems(state.items);
      } else if (state is SimpleInitial) {
        controller.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SimpleBloc>();

    return Scaffold(
      appBar: AppBar(title: const Text("Bloc Pagination Example")),
      body: BlocPaginationListView<String>(
        controller: controller,
        loadingBuilder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
        itemBuilder: (context, item, index) => ListTile(
          title: Text(item),
        ),
        emptyBuilder: (_) => const Center(
          child: Text("No items found"),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => bloc.add(LoadItems()),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
```

---

## API

### `BlocPaginationLoadController<T>`

* `appendItems(List<T> items)` → Add new items to the list.
* `reset()` → Clear all items and reset pagination.
* `setHasMoreItems(bool hasMore)` → Indicate whether more pages exist.

### `BlocPaginationListView<T>`

* `controller` → Required `BlocPaginationLoadController`.
* `itemBuilder` → Build each item widget.
* `loadingBuilder` → Widget to show when loading.
* `emptyBuilder` → Widget to show when list is empty.

---

## Example

Check the `example/` folder for a working implementation using `SimpleBloc`.

---

## License

MIT License © 2025 Amir Rabaniha
