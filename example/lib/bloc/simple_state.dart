part of 'simple_bloc.dart';

abstract class SimpleState {}

class SimpleInitial extends SimpleState {}

class SimpleLoading extends SimpleState {}

class SimpleLoaded extends SimpleState {
  final List<String> items;

  SimpleLoaded(this.items);
}
