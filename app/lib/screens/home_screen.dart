import 'package:app/api/duty_repository.dart';
import 'package:app/bloc/auth_bloc.dart';
import 'package:app/bloc/duty_bloc.dart';
import 'package:app/utils/custom_snackbar.dart';
import 'package:app/widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';


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
              return  LoadingIndicator();
            }

            if (state is DutyLoadSuccess) {
              if (state.duties.isEmpty) {
                return Center(
                  child: Text('No duties assigned for today.', style: Theme.of(context).textTheme.bodyMedium),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<DutyBloc>().add(FetchDuties());
                },
                child: ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: state.duties.length,
                  itemBuilder: (context, index) {
                    final duty = state.duties[index];
                    final startTimeFormatted = DateFormat('MMM d, hh:mm a').format(duty.startTime);
                    final endTimeFormatted = DateFormat('hh:mm a').format(duty.endTime);
                    final dutyTimeString = '$startTimeFormatted - $endTimeFormatted';

                    return Card(
                      margin: EdgeInsets.only(bottom: 16.h),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                        title: Text(duty.location, style: Theme.of(context).textTheme.titleLarge),
                        subtitle: Text(
                          'Time: $dutyTimeString\nStatus: ${duty.status}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        isThreeLine: true,
                        trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
                        onTap: () {
                          final now = DateTime.now();
                          if (now.isAfter(duty.startTime) && now.isBefore(duty.endTime)) {
                            context.go('/duty/${duty.id}', extra: duty);
                          } else if (now.isBefore(duty.startTime)) {
                            CustomSnackBar.show(
                              context,
                              message: 'This duty has not started yet.',
                              alertType: AlertType.warning,
                            );
                          } else {
                            CustomSnackBar.show(
                              context,
                              message: 'This duty has already ended.',
                              alertType: AlertType.error,
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
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