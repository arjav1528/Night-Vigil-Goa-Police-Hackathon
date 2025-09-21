import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart'; // <-- Import the new package
import 'package:night_vigil/api/duty_repository.dart';
import 'package:night_vigil/bloc/auth_bloc.dart';
import 'package:night_vigil/bloc/duty_bloc.dart';
import 'package:night_vigil/utils/loading_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:night_vigil/models/duty_assignment_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Duties'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              context.read<AuthBloc>().add(LoggedOut());
            },
          ),
        ],
      ),
      body: BlocProvider(
        create: (context) => DutyBloc(
          dutyRepository: RepositoryProvider.of<DutyRepository>(context),
        )..add(FetchDuties()),
        child: BlocBuilder<DutyBloc, DutyState>(
          builder: (context, state) {
            if (state is DutyLoading || state is DutyInitial) {
              return const LoadingIndicator();
            }

            if (state is DutyLoadSuccess) {
              if (state.duties.isEmpty) {
                return Center(
                  child: Text(
                    'No duties assigned for today.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: state.duties.length,
                itemBuilder: (context, index) {
                  final duty = state.duties[index];

                  // --- THIS IS THE NEW FORMATTING LOGIC ---
                  // Format the start and end times into a readable string
                  final startTimeFormatted = DateFormat('MMM d, hh:mm a').format(duty.startTime);
                  final endTimeFormatted = DateFormat('hh:mm a').format(duty.endTime);
                  final dutyTimeString = '$startTimeFormatted - $endTimeFormatted';
                  // ---------------------------------------------

                  return Card(
                    color: duty.status == 'Completed'
                        ? Colors.green[50]
                        : duty.status == 'Missed'
                            ? Colors.red[50]
                            : Colors.white,
                    margin: EdgeInsets.only(bottom: 16.h),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 16.w,
                      ),
                      title: Text(
                        duty.location,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      // --- UPDATED SUBTITLE ---
                      subtitle: Text(
                        'Time: $dutyTimeString\nStatus: ${duty.status}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      isThreeLine: true, // Allow the ListTile to have more height
                      // -------------------------
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 16.sp,
                      ),
                      onTap: () {
                        context.go('/duty/${duty.id}', extra: duty);
                      },
                    ),
                  );
                },
              );
            }

            if (state is DutyLoadFailure) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(32.w),
                  child: Text(
                    'Failed to load duties: ${state.error}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}