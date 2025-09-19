import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:night_vigil/api/duty_repository.dart';
import 'package:night_vigil/bloc/auth_bloc.dart';
import 'package:night_vigil/bloc/duty_bloc.dart';
import 'package:night_vigil/utils/loading_indicator.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
              // Dispatch the LoggedOut event to the AuthBloc to handle logout
              context.read<AuthBloc>().add(LoggedOut());
            },
          ),
        ],
      ),
      // Provide the DutyBloc to this part of the widget tree
      body: BlocProvider(
        create: (context) => DutyBloc(
          // Access the globally provided DutyRepository
          dutyRepository: RepositoryProvider.of<DutyRepository>(context),
        )..add(FetchDuties()), // Immediately fetch duties when the screen loads
        child: BlocBuilder<DutyBloc, DutyState>(
          builder: (context, state) {
            // --- Loading State ---
            if (state is DutyLoading || state is DutyInitial) {
              return const LoadingIndicator();
            }

            // --- Success State ---
            if (state is DutyLoadSuccess) {
              // Handle case where there are no duties
              if (state.duties.isEmpty) {
                return Center(
                  child: Text(
                    'No duties assigned for today.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              // Display the list of duties
              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: state.duties.length,
                itemBuilder: (context, index) {
                  final duty = state.duties[index];
                  return Card(
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
                      subtitle: Text(
                        'Status: ${duty.status}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: duty.status == 'COMPLETED'
                          ? Colors.green.shade700
                              : duty.status == 'PENDING'
                          ? Colors.orange.shade800
                              : Colors.grey.shade600,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 16.sp,
                      ),
                      onTap: () {
                        // Navigate to duty details screen in the future
                        // context.go('/duty/${duty.id}');
                      },
                    ),
                  );
                },
              );
            }

            // --- Failure State ---
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

            // Default empty state
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}