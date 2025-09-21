import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'simple_event.dart';

part 'simple_state.dart';

class SimpleBloc extends Bloc<SimpleEvent, SimpleState> {
  SimpleBloc() : super(SimpleInitial()) {
    on<LoadItems>((event, emit) async {
      emit(SimpleLoading());
      await Future.delayed(const Duration(seconds: 1));
      emit(SimpleLoaded([for (int i = 0; i < 10; i++) "Item $i"]));
    });
  }
}
