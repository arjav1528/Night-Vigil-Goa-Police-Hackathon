import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:night_vigil/api/duty_repository.dart';
import 'package:night_vigil/bloc/auth_bloc.dart';
import 'package:night_vigil/bloc/duty_bloc.dart';
import 'package:night_vigil/utils/custom_snackbar.dart';
import 'package:night_vigil/utils/loading_indicator.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class HomeScreen extends StatelessWidget {

  
  const HomeScreen({super.key});

  Future<bool> _onWillPop(BuildContext context) async {
    await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Exit'),
            content: const Text('Are you sure you want to exit the app?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onWillPop(context),
      child: Scaffold(
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
                          // debugPrint("Duty tapped: $duty");
                          if(duty.status == 'COMPLETED') {
                            CustomSnackBar.show(
                              context,
                              message: 'This duty is already completed.',
                              alertType: AlertType.info,
                            );
                            return;
                          }
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
      ),
    );
  }
}