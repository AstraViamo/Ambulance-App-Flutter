// lib/screens/driver_navigation_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/route_model.dart';
import '../providers/auth_provider.dart';
import '../providers/location_providers.dart';
import '../providers/route_providers.dart';

class DriverNavigationScreen extends ConsumerStatefulWidget {
  final AmbulanceRouteModel route;

  const DriverNavigationScreen({
    Key? key,
    required this.route,
  }) : super(key: key);

  @override
  ConsumerState<DriverNavigationScreen> createState() =>
      _DriverNavigationScreenState();
}

class _DriverNavigationScreenState
    extends ConsumerState<DriverNavigationScreen> {
  Timer? _locationTimer;
  Position? _currentPosition;
  double? _distanceToDestination;
  int? _estimatedTimeMinutes;
  bool _isNavigating = false;
  List<NavigationStep> _navigationSteps = [];
  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNavigation() async {
    await _updateLocation();
    _generateNavigationSteps();
    _startLocationTracking();
    setState(() {
      _isNavigating = true;
    });
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateLocation();
    });
  }

  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });

        _calculateDistanceAndTime();
        _updateNavigationProgress();

        // Update location in the system
        ref.read(trackingStateProvider.notifier).startTracking(
              ambulanceId:
                  widget.route.ambulanceId, // or get from your route data
              driverId: widget.route.driverId,
              initialStatus: 'en_route', // or appropriate status
            );
      }
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  void _calculateDistanceAndTime() {
    if (_currentPosition == null) return;

    // This is a simplified calculation - in a real app, you'd use proper routing APIs
    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.route.endLat ?? 0.0,
      widget.route.endLng ?? 0.0,
    );

    setState(() {
      _distanceToDestination = distance / 1000; // Convert to kilometers
      _estimatedTimeMinutes =
          (distance / 1000 / 40 * 60).round(); // Assume 40 km/h average speed
    });
  }

  void _generateNavigationSteps() {
    // This is a mock implementation - in a real app, you'd get this from a routing service
    _navigationSteps = [
      NavigationStep(
        instruction: "Head north on Main Street",
        distance: 0.8,
        icon: Icons.straight,
      ),
      NavigationStep(
        instruction: "Turn right onto Oak Avenue",
        distance: 1.2,
        icon: Icons.turn_right,
      ),
      NavigationStep(
        instruction: "Continue straight for 2.5 km",
        distance: 2.5,
        icon: Icons.straight,
      ),
      NavigationStep(
        instruction: "Turn left onto Hospital Drive",
        distance: 0.3,
        icon: Icons.turn_left,
      ),
      NavigationStep(
        instruction: "Arrive at destination",
        distance: 0.0,
        icon: Icons.location_on,
      ),
    ];
  }

  void _updateNavigationProgress() {
    // Simplified progress tracking - in a real app, this would be more sophisticated
    if (_distanceToDestination != null && _distanceToDestination! < 5.0) {
      if (_currentStepIndex < _navigationSteps.length - 1) {
        setState(() {
          _currentStepIndex++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Navigation - ${widget.route.emergencyId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showNavigationSettings(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main navigation display
          Expanded(
            flex: 3,
            child: _buildMainNavigationView(),
          ),

          // Current instruction banner
          _buildCurrentInstructionBanner(),

          // Bottom control panel
          _buildBottomControlPanel(),
        ],
      ),
    );
  }

  Widget _buildMainNavigationView() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.black54],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mock map view
          Container(
            height: 250,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade400, width: 2),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    size: 80,
                    color: Colors.blue.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Interactive Map View',
                    style: TextStyle(
                      color: Colors.blue.shade400,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'GPS Navigation Active',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Distance and ETA info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavigationStat(
                'Distance',
                _distanceToDestination != null
                    ? '${_distanceToDestination!.toStringAsFixed(1)} km'
                    : '--',
                Icons.straighten,
                Colors.blue,
              ),
              _buildNavigationStat(
                'ETA',
                _estimatedTimeMinutes != null
                    ? '${_estimatedTimeMinutes} min'
                    : '--',
                Icons.access_time,
                Colors.green,
              ),
              _buildNavigationStat(
                'Speed',
                _currentPosition != null
                    ? '${(_currentPosition!.speed * 3.6).toStringAsFixed(0)} km/h'
                    : '--',
                Icons.speed,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentInstructionBanner() {
    if (_navigationSteps.isEmpty ||
        _currentStepIndex >= _navigationSteps.length) {
      return Container();
    }

    final currentStep = _navigationSteps[_currentStepIndex];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              currentStep.icon,
              color: Colors.blue.shade700,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentStep.instruction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (currentStep.distance > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'in ${(currentStep.distance * 1000).toStringAsFixed(0)}m',
                    style: TextStyle(
                      color: Colors.blue.shade100,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(top: BorderSide(color: Colors.grey.shade700)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.phone,
            label: 'Emergency',
            color: Colors.red,
            onPressed: () => _callEmergency(),
          ),
          _buildControlButton(
            icon: Icons.headset_mic,
            label: 'Dispatch',
            color: Colors.blue,
            onPressed: () => _contactDispatch(),
          ),
          _buildControlButton(
            icon: Icons.list,
            label: 'Steps',
            color: Colors.green,
            onPressed: () => _showNavigationSteps(),
          ),
          _buildControlButton(
            icon: Icons.flag,
            label: 'Arrived',
            color: Colors.orange,
            onPressed: () => _markAsArrived(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
          ),
          child: Icon(icon, size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showNavigationSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Navigation Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.volume_up, color: Colors.white),
              title: const Text('Voice Guidance',
                  style: TextStyle(color: Colors.white)),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
                activeColor: Colors.blue,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.white),
              title: const Text('Open in Google Maps',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openInExternalMap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_location, color: Colors.white),
              title: const Text('Share Location',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _shareLocation();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNavigationSteps() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Navigation Steps',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: _navigationSteps.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Colors.grey),
                  itemBuilder: (context, index) {
                    final step = _navigationSteps[index];
                    final isCurrentStep = index == _currentStepIndex;

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCurrentStep
                              ? Colors.blue
                              : Colors.grey.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          step.icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        step.instruction,
                        style: TextStyle(
                          color: isCurrentStep
                              ? Colors.blue.shade400
                              : Colors.white,
                          fontWeight: isCurrentStep
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: step.distance > 0
                          ? Text(
                              '${step.distance.toStringAsFixed(1)} km',
                              style: TextStyle(color: Colors.grey.shade400),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _callEmergency() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title:
            const Text('Emergency Call', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will call emergency services. Are you sure?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement emergency call
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calling emergency services...')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Call', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _contactDispatch() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contacting dispatch...')),
    );
  }

  void _openInExternalMap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening in external map app...')),
    );
  }

  void _shareLocation() {
    if (_currentPosition != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location shared: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
          ),
        ),
      );
    }
  }

  void _markAsArrived() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Mark as Arrived',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Have you arrived at the destination?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                final currentUser = ref.read(currentUserProvider);
                await currentUser.when(
                  data: (user) async {
                    if (user == null) return;

                    // Update route status to completed
                    await ref
                        .read(routeStatusUpdateProvider.notifier)
                        .completeRoute(
                          routeId: widget.route.id,
                          completedBy: user.id,
                          completedByName: user.fullName,
                          completionReason: 'Arrived at destination',
                        );
                  },
                  loading: () {},
                  error: (error, stack) {
                    throw Exception('User not found');
                  },
                );

                // Stop navigation
                _locationTimer?.cancel();

                // Show success message and go back
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Route completed successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );

                // Navigate back to dashboard
                Navigator.of(context).popUntil((route) => route.isFirst);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error completing route: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Mark as Completed'),
          ),
        ],
      ),
    );
  }
}

// Navigation step model
class NavigationStep {
  final String instruction;
  final double distance; // in kilometers
  final IconData icon;

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.icon,
  });
}
