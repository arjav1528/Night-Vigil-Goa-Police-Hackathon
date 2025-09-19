import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:night_vigil/api/duty_repository.dart';
import 'package:night_vigil/models/duty_assignment_model.dart';

// States
abstract class DutyState {}
class DutyInitial extends DutyState {}
class DutyLoading extends DutyState {}
class DutyLoadSuccess extends DutyState {
  final List<DutyAssignment> duties;
  DutyLoadSuccess({required this.duties});
}
class DutyLoadFailure extends DutyState {
  final String error;
  DutyLoadFailure({required this.error});
}

// Event
abstract class DutyEvent {}
class FetchDuties extends DutyEvent {}

// BLoC
class DutyBloc extends Bloc<DutyEvent, DutyState> {
  final DutyRepository dutyRepository;

  DutyBloc({required this.dutyRepository}) : super(DutyInitial()) {
    on<FetchDuties>((event, emit) async {
      emit(DutyLoading());
      try {
        final duties = await dutyRepository.getMyDuties();
        emit(DutyLoadSuccess(duties: duties));
      } catch (e) {
        emit(DutyLoadFailure(error: e.toString()));
      }
    });
  }
}