import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../bloc/geofencing_bloc.dart';
import '../models/duty_assignment_model.dart';

class GeofencingWidget extends StatelessWidget {
  final List<DutyAssignment> duties;

  const GeofencingWidget({
    super.key,
    required this.duties,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Geofencing',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            BlocBuilder<GeofencingBloc, GeofencingState>(
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusIndicator(context, state),
                    const SizedBox(height: 16),
                    _buildActionButtons(context, state),
                    const SizedBox(height: 16),
                    if (state is GeofencingActive) ...[
                      _buildActiveGeofences(context, state),
                      const SizedBox(height: 16),
                      _buildCurrentLocation(context, state),
                    ],
                    if (state is GeofencingError)
                      _buildErrorMessage(context, state),
                    if (state is GeofencingPermissionDenied)
                      _buildPermissionMessage(context, state),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, GeofencingState state) {
    String status;
    Color color;
    IconData icon;

    if (state is GeofencingActive) {
      status = 'Active';
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (state is GeofencingInactive) {
      status = 'Inactive';
      color = Colors.grey;
      icon = Icons.radio_button_unchecked;
    } else if (state is GeofencingLoading) {
      status = 'Loading...';
      color = Colors.orange;
      icon = Icons.hourglass_empty;
    } else if (state is GeofencingError) {
      status = 'Error';
      color = Colors.red;
      icon = Icons.error;
    } else if (state is GeofencingPermissionDenied) {
      status = 'Permissions Required';
      color = Colors.red;
      icon = Icons.warning;
    } else {
      status = 'Unknown';
      color = Colors.grey;
      icon = Icons.help;
    }

    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          'Status: $status',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, GeofencingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show compulsory geofencing information
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Geofencing is compulsory and automatically starts when you check in for duty.',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Show refresh button only when geofencing is active
        if (state is GeofencingActive)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.read<GeofencingBloc>().add(
                        CheckCurrentLocationAgainstDuties(),
                      ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        // Show permission request button only when permissions are denied
        if (state is GeofencingPermissionDenied)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.read<GeofencingBloc>().add(
                        RequestGeofencingPermissions(),
                      ),
                  icon: const Icon(Icons.settings),
                  label: const Text('Grant Permissions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildActiveGeofences(BuildContext context, GeofencingActive state) {
    if (state.activeDuties.isEmpty) {
      return const Text('No active geofences');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Geofences (${state.activeDuties.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...state.activeDuties.map((duty) {
          final isInside = state.dutiesUserIsIn.contains(duty.id);
          final distance = state.dutyDistances[duty.id];
          
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: Icon(
                isInside ? Icons.location_on : Icons.location_off,
                color: isInside ? Colors.green : Colors.grey,
              ),
              title: Text(duty.location),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Radius: ${duty.radius.round()}m'),
                  Text(
                    'Time: ${DateFormat('HH:mm').format(duty.startTime)} - '
                    '${DateFormat('HH:mm').format(duty.endTime)}',
                  ),
                  if (distance != null)
                    Text(
                      'Distance: ${_formatDistance(distance)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isInside ? Colors.green : 
                               distance > duty.radius ? Colors.red : Colors.orange,
                      ),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(isInside ? 'Inside' : 'Outside'),
                    backgroundColor: isInside ? Colors.green : Colors.grey,
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  if (distance != null && !isInside)
                    Text(
                      '${(distance - duty.radius).round()}m away',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        }),
      ],
    );
  }

  /// Format distance for better readability
  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(2)} km';
    } else {
      return '${distanceInMeters.round()} m';
    }
  }

  Widget _buildCurrentLocation(BuildContext context, GeofencingActive state) {
    if (state.currentLocation == null) {
      return const Text('Location not available');
    }

    final location = state.currentLocation!;
    final locationAge = DateTime.now().difference(location.timestamp);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Location',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.my_location, 
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lat: ${location.latitude.toStringAsFixed(6)}, '
                        'Lng: ${location.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Accuracy: ±${location.accuracy.round()}m',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Row(
                  children: [
                    Text(
                      'Updated: ${DateFormat('HH:mm:ss').format(location.timestamp.toLocal())}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (locationAge.inMinutes > 2) ...[
                      Text(
                        ' (${locationAge.inMinutes} min ago)',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                // Show distance summary
                if (state.dutyDistances.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 4),
                  Text(
                    'Distance Summary',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...state.activeDuties.map((duty) {
                    final distance = state.dutyDistances[duty.id];
                    final isInside = state.dutiesUserIsIn.contains(duty.id);
                    
                    if (distance == null) return const SizedBox.shrink();
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            isInside ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 14,
                            color: isInside ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              duty.location,
                              style: TextStyle(
                                fontSize: 12,
                                color: isInside ? Colors.green : null,
                              ),
                            ),
                          ),
                          Text(
                            _formatDistance(distance),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isInside ? Colors.green : 
                                     distance > duty.radius ? Colors.red : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(BuildContext context, GeofencingError state) {
    // Check if this is a temporary location issue vs a serious error
    final isTemporaryLocationIssue = state.message.contains('timed out') || 
                                    state.message.contains('GPS signal') ||
                                    state.message.contains('trying in the background');
    
    return Card(
      color: isTemporaryLocationIssue ? Colors.orange.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isTemporaryLocationIssue ? Icons.warning : Icons.error, 
                  color: isTemporaryLocationIssue ? Colors.orange.shade700 : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTemporaryLocationIssue ? 'GPS Signal Issue' : 'Location Error',
                    style: TextStyle(
                      color: isTemporaryLocationIssue ? Colors.orange.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isTemporaryLocationIssue 
                ? 'GPS signal is weak. The app will continue monitoring using the last known location and keep trying to get a better signal.'
                : state.message,
              style: TextStyle(color: isTemporaryLocationIssue ? Colors.orange.shade700 : Colors.red.shade700),
            ),
            if (isTemporaryLocationIssue) ...[
              const SizedBox(height: 8),
              Text(
                'Tip: Move to an area with better sky visibility if possible.',
                style: TextStyle(
                  color: Colors.orange.shade600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Add retry button for location errors
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.read<GeofencingBloc>().add(
                          CheckCurrentLocationAgainstDuties(),
                        ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isTemporaryLocationIssue ? Colors.orange.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Show basic troubleshooting info
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Location Troubleshooting'),
                          content: const Text(
                            'Please ensure:\n'
                            '• Location services are enabled\n'
                            '• App has location permissions\n'
                            '• GPS signal is available\n'
                            '• Try restarting the app'
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Help'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isTemporaryLocationIssue ? Colors.orange.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionMessage(BuildContext context, GeofencingPermissionDenied state) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.message,
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Geofencing requires location permissions to work in the background. '
              'Please grant "Allow all the time" location permission.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class GeofencingScreen extends StatelessWidget {
  final List<DutyAssignment> duties;

  const GeofencingScreen({
    super.key,
    required this.duties,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofencing'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: (){
            if(context.canPop()){
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: const Icon(Icons.arrow_back)),
      ),
      body: BlocListener<GeofencingBloc, GeofencingState>(
        listener: (context, state) {
          // Show snackbar for refresh completion
          if (state is GeofencingActive) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          } else if (state is GeofencingError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Refresh failed: ${state.message}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        child: RefreshIndicator(
          onRefresh: () async {
            final completer = Completer<void>();
            
            // Listen for state changes to complete the refresh
            final subscription = context.read<GeofencingBloc>().stream.listen((state) {
              if (state is! GeofencingLoading && !completer.isCompleted) {
                completer.complete();
              }
            });

            try {
              // Trigger refresh events
              context.read<GeofencingBloc>().add(InitializeGeofencing());

              // Wait a brief moment to ensure the event is processed
              await Future.delayed(const Duration(milliseconds: 100));
              
              // Check current location
              context.read<GeofencingBloc>().add(CheckCurrentLocationAgainstDuties());
              
              // Wait for completion or timeout
              await completer.future.timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  if (!completer.isCompleted) {
                    completer.complete();
                  }
                },
              );
            } catch (e) {
              // Handle any errors during refresh
              if (!completer.isCompleted) {
                completer.complete();
              }
            } finally {
              subscription.cancel();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                GeofencingWidget(duties: duties),
                const SizedBox(height: 16),
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'How Geofencing Works',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '• Automatically starts when you check in for duty\n'
                          '• Continuously monitors your location during duty hours\n'
                          '• Works even when the app is closed\n'
                          '• Sends notifications for geofence events\n'
                          '• Automatically stops when your duty ends\n'
                          '• COMPULSORY - Cannot be manually disabled during duty',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.refresh, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pull down to refresh location and geofencing status',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Add some bottom padding for better scrolling experience
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}