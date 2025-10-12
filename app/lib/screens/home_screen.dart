import 'package:app/api/duty_repository.dart';
import 'package:app/bloc/auth_bloc.dart';
import 'package:app/bloc/duty_bloc.dart';
import 'package:app/bloc/geofencing_bloc.dart';
import 'package:app/utils/custom_snackbar.dart';
import 'package:app/widgets/geofencing_widget.dart';
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
            icon: const Icon(Icons.location_on),
            tooltip: 'Geofencing',
            onPressed: () {
              // Navigate to geofencing screen
              context.go('/geofencing');
            },
          ),
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
              // Check for active duties and start geofencing automatically
              final now = DateTime.now();
              final activeDuties = state.duties.where((duty) => 
                now.isAfter(duty.startTime) && now.isBefore(duty.endTime) && duty.status == 'COMPLETED'
              ).toList();
              
              // Auto-start geofencing for checked-in duties
              if (activeDuties.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final geofencingBloc = context.read<GeofencingBloc>();
                  if (geofencingBloc.state is! GeofencingActive) {
                    debugPrint('Auto-starting geofencing for ${activeDuties.length} active duties');
                    geofencingBloc.add(StartGeofencingWithDuties(activeDuties));
                  }
                });
              }

              if (state.duties.isEmpty) {
                return Center(
                  child: Text('No duties assigned for today.', style: Theme.of(context).textTheme.bodyMedium),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<DutyBloc>().add(FetchDuties());
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Geofencing widget
                      // GeofencingWidget(duties: state.duties),
                      
                      // Duties list
                      // Padding(
                      //   padding: EdgeInsets.symmetric(horizontal: 16.w),
                      //   child: Text(
                      //     'My Duties',
                      //     style: Theme.of(context).textTheme.headlineSmall,
                      //   ),
                      // ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.all(16.w),
                        itemCount: state.duties.length,
                        itemBuilder: (context, index) {
                          final duty = state.duties[index];
                          final startTimeFormatted = DateFormat('MMM d, hh:mm a').format(duty.startTime);
                          final endTimeFormatted = DateFormat('hh:mm a').format(duty.endTime);
                          final dutyTimeString = '$startTimeFormatted - $endTimeFormatted';

                          return BlocBuilder<GeofencingBloc, GeofencingState>(
                            builder: (context, geofencingState) {
                              // Get distance information if geofencing is active
                              String distanceInfo = '';
                              if (geofencingState is GeofencingActive) {
                                final distance = geofencingState.dutyDistances[duty.id];
                                if (distance != null) {
                                  if (distance >= 1000) {
                                    distanceInfo = '\nDistance: ${(distance / 1000).toStringAsFixed(2)} km';
                                  } else {
                                    distanceInfo = '\nDistance: ${distance.round()} m';
                                  }
                                  
                                  // Add status if user is within duty area
                                  if (geofencingState.dutiesUserIsIn.contains(duty.id)) {
                                    distanceInfo += ' (Inside)';
                                  } else if (distance > duty.radius) {
                                    distanceInfo += ' (${(distance - duty.radius).round()}m away)';
                                  }
                                }
                              }

                              return Card(
                                margin: EdgeInsets.only(bottom: 16.h),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                                  title: Text(duty.location, style: Theme.of(context).textTheme.titleLarge),
                                  subtitle: Text(
                                    'Time: $dutyTimeString\nStatus: ${duty.status}\nRadius: ${duty.radius.round()}m$distanceInfo',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  isThreeLine: true,
                                  trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
                                  onTap: () {
                                    final now = DateTime.now();
                                    
                                    // Debug information
                                    debugPrint('Current time: $now');
                                    debugPrint('Duty start time: ${duty.startTime}');
                                    debugPrint('Duty end time: ${duty.endTime}');
                                    debugPrint('Is after start: ${now.isAfter(duty.startTime)}');
                                    debugPrint('Is before end: ${now.isBefore(duty.endTime)}');

                                    if(duty.status == 'COMPLETED') {
                                      CustomSnackBar.show(
                                        context,
                                        message: 'You have already checked in for this duty.',
                                        alertType: AlertType.info,
                                      );
                                      return;
                                    }
                                    
                                    if (now.isAfter(duty.startTime) && now.isBefore(duty.endTime)) {
                                      context.go('/duty/${duty.id}', extra: duty);
                                    } else if (now.isBefore(duty.startTime)) {
                                      CustomSnackBar.show(
                                        context,
                                        message: 'This duty has not started yet. Start time: ${DateFormat('MMM d, hh:mm a').format(duty.startTime)}',
                                        alertType: AlertType.warning,
                                      );
                                    } else {
                                      CustomSnackBar.show(
                                        context,
                                        message: 'This duty has already ended. End time: ${DateFormat('MMM d, hh:mm a').format(duty.endTime)}',
                                        alertType: AlertType.error,
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
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