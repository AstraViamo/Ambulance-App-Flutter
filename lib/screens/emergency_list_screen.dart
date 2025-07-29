// lib/screens/emergency_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/emergency_model.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_providers.dart';
import 'create_emergency_screen.dart';
import 'emergency_details_screen.dart';

class EmergencyListScreen extends ConsumerStatefulWidget {
  final bool showAppBar;

  const EmergencyListScreen({
    Key? key,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  ConsumerState<EmergencyListScreen> createState() =>
      _EmergencyListScreenState();
}

class _EmergencyListScreenState extends ConsumerState<EmergencyListScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String? hospitalId;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHospitalId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadHospitalId() async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser != null) {
        setState(() {
          hospitalId = currentUser.roleSpecificData.hospitalId;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading hospital data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (hospitalId == null) {
      return _buildLoadingWidget();
    }

    final emergencyStats = ref.watch(emergencyStatsProvider(hospitalId!));
    final error = ref.watch(emergencyErrorProvider);

    if (widget.showAppBar) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: _buildBody(emergencyStats, error),
      );
    } else {
      return _buildBody(emergencyStats, error);
    }
  }

  Widget _buildLoadingWidget() {
    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Emergency Dispatch',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red.shade700,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading hospital information...'),
            ],
          ),
        ),
      );
    } else {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading hospital information...'),
          ],
        ),
      );
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Emergency Dispatch',
          style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.red.shade700,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: _navigateToCreateEmergency,
          tooltip: 'Create Emergency',
        ),
        PopupMenuButton<EmergencySortOption>(
          icon: const Icon(Icons.sort, color: Colors.white),
          tooltip: 'Sort emergencies',
          onSelected: (option) {
            ref.read(emergencySortOptionProvider.notifier).state = option;
          },
          itemBuilder: (context) => EmergencySortOption.values
              .map(
                (option) => PopupMenuItem(
                  value: option,
                  child: Row(
                    children: [
                      Icon(option.icon, size: 16),
                      const SizedBox(width: 8),
                      Text(option.displayName),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: 'Active', icon: Icon(Icons.emergency)),
          Tab(text: 'All', icon: Icon(Icons.list)),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue emergencyStats, String? error) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // Custom header section when no AppBar is shown
            if (!widget.showAppBar) _buildCustomHeader(constraints),

            // Statistics section
            emergencyStats.when(
              data: (stats) => _buildStatsSection(stats, constraints),
              loading: () => SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator())),
              error: (error, stack) => Container(
                height: 100,
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text('Error loading stats: $error',
                      style: const TextStyle(color: Colors.red)),
                ),
              ),
            ),

            // Search bar
            Padding(
              padding: EdgeInsets.all(constraints.maxWidth > 600 ? 24 : 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by caller name, phone, or description...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),

            // Error message
            if (error != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            // Tab view or emergency list
            Expanded(
              child: widget.showAppBar
                  ? _buildTabView(constraints)
                  : _buildEmergencyList(constraints),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomHeader(BoxConstraints constraints) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(constraints.maxWidth > 600 ? 24 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.shade700,
            Colors.red.shade600,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.emergency,
                  color: Colors.white,
                  size: constraints.maxWidth > 600 ? 32 : 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Emergency Dispatch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: constraints.maxWidth > 600 ? 24 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: _navigateToCreateEmergency,
                  tooltip: 'Create Emergency',
                ),
                PopupMenuButton<EmergencySortOption>(
                  icon: const Icon(Icons.sort, color: Colors.white),
                  tooltip: 'Sort emergencies',
                  onSelected: (option) {
                    ref.read(emergencySortOptionProvider.notifier).state =
                        option;
                  },
                  itemBuilder: (context) => EmergencySortOption.values
                      .map(
                        (option) => PopupMenuItem(
                          value: option,
                          child: Row(
                            children: [
                              Icon(option.icon, size: 16),
                              const SizedBox(width: 8),
                              Text(option.displayName),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor and manage emergency calls',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: constraints.maxWidth > 600 ? 16 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(
      Map<String, int> stats, BoxConstraints constraints) {
    final isWideScreen = constraints.maxWidth > 600;

    return Container(
      margin: EdgeInsets.all(constraints.maxWidth > 600 ? 24 : 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency Overview',
            style: TextStyle(
              fontSize: isWideScreen ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          isWideScreen
              ? _buildWideStatsGrid(stats)
              : _buildNarrowStatsGrid(stats),
        ],
      ),
    );
  }

  Widget _buildWideStatsGrid(Map<String, int> stats) {
    return Row(
      children: [
        Expanded(
            child: _buildStatCard('Today', stats['today'] ?? 0, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(
            child:
                _buildStatCard('Active', stats['active'] ?? 0, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(
            child:
                _buildStatCard('Critical', stats['critical'] ?? 0, Colors.red)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard(
                'Pending', stats['pending'] ?? 0, Colors.purple)),
      ],
    );
  }

  Widget _buildNarrowStatsGrid(Map<String, int> stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child:
                    _buildStatCard('Today', stats['today'] ?? 0, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
                    'Active', stats['active'] ?? 0, Colors.orange)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    'Critical', stats['critical'] ?? 0, Colors.red)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
                    'Pending', stats['pending'] ?? 0, Colors.purple)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabView(BoxConstraints constraints) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildEmergencyList(constraints, activeOnly: true),
        _buildEmergencyList(constraints, activeOnly: false),
      ],
    );
  }

  Widget _buildEmergencyList(BoxConstraints constraints,
      {bool activeOnly = false}) {
    final emergenciesAsync = ref.watch(emergenciesProvider(hospitalId!));
    final sortOption = ref.watch(emergencySortOptionProvider);

    return emergenciesAsync.when(
      data: (emergencies) {
        var filteredEmergencies = emergencies;

        // Filter by active only if needed
        if (activeOnly) {
          filteredEmergencies = emergencies
              .where((e) => !e.isCompleted && !e.isCancelled)
              .toList();
        }

        // Apply search filter
        if (_searchController.text.isNotEmpty) {
          final searchTerm = _searchController.text.toLowerCase();
          filteredEmergencies = filteredEmergencies.where((emergency) {
            return emergency.callerName.toLowerCase().contains(searchTerm) ||
                emergency.callerPhone.toLowerCase().contains(searchTerm) ||
                emergency.description.toLowerCase().contains(searchTerm);
          }).toList();
        }

        // Sort emergencies
        filteredEmergencies.sort((a, b) {
          switch (sortOption) {
            case EmergencySortOption.newest:
              return b.createdAt.compareTo(a.createdAt);
            case EmergencySortOption.oldest:
              return a.createdAt.compareTo(b.createdAt);
            case EmergencySortOption.priority:
              return b.priority.urgencyLevel.compareTo(a.priority.urgencyLevel);
            case EmergencySortOption.status:
              return a.status.value.compareTo(b.status.value);
          }
        });

        if (filteredEmergencies.isEmpty) {
          return _buildEmptyState(activeOnly);
        }

        return ListView.builder(
          padding: EdgeInsets.all(constraints.maxWidth > 600 ? 24 : 16),
          itemCount: filteredEmergencies.length,
          itemBuilder: (context, index) {
            final emergency = filteredEmergencies[index];
            return _buildEmergencyCard(emergency, constraints);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading emergencies: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(emergenciesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool activeOnly) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            activeOnly ? Icons.check_circle : Icons.emergency,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            activeOnly ? 'No active emergencies' : 'No emergencies found',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            activeOnly
                ? 'All emergencies have been resolved'
                : _searchController.text.isNotEmpty
                    ? 'Try adjusting your search terms'
                    : 'Emergency calls will appear here',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          if (!activeOnly && _searchController.text.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateEmergency,
              icon: const Icon(Icons.add),
              label: const Text('Create Emergency'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmergencyCard(
      EmergencyModel emergency, BoxConstraints constraints) {
    final priorityColor = emergency.priority.colorValue != null
        ? Color(emergency.priority.colorValue!)
        : Colors.grey;

    final isWideScreen = constraints.maxWidth > 600;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: priorityColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToEmergencyDetails(emergency),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isWideScreen ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: priorityColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          emergency.priority == EmergencyPriority.critical
                              ? Icons.warning
                              : Icons.info,
                          color: priorityColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          emergency.priority.displayName.toUpperCase(),
                          style: TextStyle(
                            color: priorityColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: emergency.status.colorValue != null
                          ? Color(emergency.status.colorValue!).withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      emergency.status.displayName,
                      style: TextStyle(
                        color: emergency.status.colorValue != null
                            ? Color(emergency.status.colorValue!)
                            : Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTimeAgo(emergency.createdAt),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Caller information
              Row(
                children: [
                  Icon(Icons.person, color: Colors.grey.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      emergency.callerName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isWideScreen ? 16 : 15,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Phone number
              Row(
                children: [
                  Icon(Icons.phone, color: Colors.grey.shade600, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    emergency.callerPhone,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Description
              Text(
                emergency.description,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 14,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Location
              Row(
                children: [
                  Icon(Icons.location_on,
                      color: Colors.grey.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      emergency.patientAddressString,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Action buttons for critical/high priority
              if (emergency.priority == EmergencyPriority.critical ||
                  emergency.priority == EmergencyPriority.high) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!emergency.isAssigned)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _assignAmbulance(emergency),
                          icon: const Icon(Icons.local_shipping, size: 16),
                          label: const Text('Assign'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: priorityColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    if (emergency.isAssigned && !emergency.isCompleted) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _trackRoute(emergency),
                          icon: const Icon(Icons.navigation, size: 16),
                          label: const Text('Track'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: priorityColor,
                            side: BorderSide(color: priorityColor),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _navigateToCreateEmergency() {
    if (hospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hospital ID not found. Please try logging in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEmergencyScreen(hospitalId: hospitalId!),
      ),
    ).then((result) {
      if (result == true) {
        ref.refresh(emergenciesProvider(hospitalId!));
        ref.refresh(emergencyStatsProvider(hospitalId!));
      }
    });
  }

  void _navigateToEmergencyDetails(EmergencyModel emergency) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyDetailsScreen(emergency: emergency),
      ),
    );
  }

  void _assignAmbulance(EmergencyModel emergency) {
    // Implement ambulance assignment logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Assigning ambulance to ${emergency.callerName}...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _trackRoute(EmergencyModel emergency) {
    // Implement route tracking logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tracking route for ${emergency.callerName}...'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
