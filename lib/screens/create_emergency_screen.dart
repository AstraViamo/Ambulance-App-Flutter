// lib/screens/create_emergency_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/emergency_model.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_providers.dart';

class CreateEmergencyScreen extends ConsumerStatefulWidget {
  final String hospitalId;

  const CreateEmergencyScreen({
    Key? key,
    required this.hospitalId,
  }) : super(key: key);

  @override
  ConsumerState<CreateEmergencyScreen> createState() =>
      _CreateEmergencyScreenState();
}

class _CreateEmergencyScreenState extends ConsumerState<CreateEmergencyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _callerNameController = TextEditingController();
  final _callerPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _callerNameController.dispose();
    _callerPhoneController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(emergencyFormProvider);
    final placeSuggestions = ref.watch(placeSuggestionsProvider);
    final selectedPlace = ref.watch(selectedPlaceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Emergency',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.emergency,
                        size: 48,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Emergency Dispatch',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Record emergency details and dispatch ambulance',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Error message
              if (formState.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(formState.error!,
                            style: TextStyle(color: Colors.red.shade700)),
                      ),
                    ],
                  ),
                ),

              // Caller Information Section
              _buildSectionTitle('Caller Information'),
              const SizedBox(height: 16),

              // Caller Name Field
              TextFormField(
                controller: _callerNameController,
                decoration: InputDecoration(
                  labelText: 'Caller Name *',
                  hintText: 'Enter caller\'s full name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Caller name is required';
                  }
                  return null;
                },
                onChanged: (value) {
                  ref
                      .read(emergencyFormProvider.notifier)
                      .updateCallerName(value);
                },
              ),

              const SizedBox(height: 16),

              // Caller Phone Field
              TextFormField(
                controller: _callerPhoneController,
                decoration: InputDecoration(
                  labelText: 'Caller Phone Number *',
                  hintText: 'Enter phone number',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  if (value.trim().length < 10) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
                onChanged: (value) {
                  ref
                      .read(emergencyFormProvider.notifier)
                      .updateCallerPhone(value);
                },
              ),

              const SizedBox(height: 24),

              // Emergency Details Section
              _buildSectionTitle('Emergency Details'),
              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Emergency Description *',
                  hintText: 'Describe the emergency situation',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Emergency description is required';
                  }
                  return null;
                },
                onChanged: (value) {
                  ref
                      .read(emergencyFormProvider.notifier)
                      .updateDescription(value);
                },
              ),

              const SizedBox(height: 16),

              // Priority Selection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Priority Level *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...EmergencyPriority.values.map((priority) {
                      final color = Color(priority.colorValue);
                      return RadioListTile<EmergencyPriority>(
                        title: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(priority.displayName),
                          ],
                        ),
                        subtitle: Text(_getPriorityDescription(priority)),
                        value: priority,
                        groupValue: formState.priority,
                        onChanged: (value) {
                          if (value != null) {
                            ref
                                .read(emergencyFormProvider.notifier)
                                .updatePriority(value);
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Location Section
              _buildSectionTitle('Patient Location'),
              const SizedBox(height: 16),

              // Location Search Field with Autocomplete
              Column(
                children: [
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'Patient Location *',
                      hintText: 'Search for location...',
                      prefixIcon: const Icon(Icons.location_on),
                      suffixIcon: selectedPlace != null
                          ? IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.green),
                              onPressed: null,
                            )
                          : const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (value) {
                      if (selectedPlace == null) {
                        return 'Please select a location from suggestions';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      ref
                          .read(placeSuggestionsProvider.notifier)
                          .searchPlaces(value);
                    },
                  ),

                  // Location suggestions
                  if (placeSuggestions.isNotEmpty && selectedPlace == null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: placeSuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = placeSuggestions[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on),
                            title: Text(suggestion.mainText),
                            subtitle: Text(suggestion.secondaryText),
                            onTap: () => _selectPlace(suggestion),
                          );
                        },
                      ),
                    ),

                  // Selected location display
                  if (selectedPlace != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Location',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                Text(selectedPlace!.formattedAddress),
                                Text(
                                  'Lat: ${selectedPlace!.latitude.toStringAsFixed(6)}, '
                                  'Lng: ${selectedPlace!.longitude.toStringAsFixed(6)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              ref.read(selectedPlaceProvider.notifier).state =
                                  null;
                              ref
                                  .read(emergencyFormProvider.notifier)
                                  .updateSelectedPlace(null);
                              _locationController.clear();
                              ref
                                  .read(placeSuggestionsProvider.notifier)
                                  .clearSuggestions();
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Create Emergency',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Information card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• After creating, you can find and assign the nearest ambulance\n'
                      '• Critical and high priority emergencies will be highlighted\n'
                      '• Location data helps optimize ambulance dispatch',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  String _getPriorityDescription(EmergencyPriority priority) {
    switch (priority) {
      case EmergencyPriority.low:
        return 'Non-urgent medical assistance';
      case EmergencyPriority.medium:
        return 'Standard emergency response';
      case EmergencyPriority.high:
        return 'Urgent medical emergency';
      case EmergencyPriority.critical:
        return 'Life-threatening emergency';
    }
  }

  Future<void> _selectPlace(PlaceSuggestion suggestion) async {
    try {
      // Clear suggestions
      ref.read(placeSuggestionsProvider.notifier).clearSuggestions();

      // Get place details
      final emergencyService = ref.read(emergencyServiceProvider);
      final placeDetails =
          await emergencyService.getPlaceDetails(suggestion.placeId);

      if (placeDetails != null) {
        // Update UI
        _locationController.text = placeDetails.formattedAddress;
        ref.read(selectedPlaceProvider.notifier).state = placeDetails;
        ref
            .read(emergencyFormProvider.notifier)
            .updateSelectedPlace(placeDetails);
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get location details. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final formState = ref.read(emergencyFormProvider);
    final selectedPlace = ref.read(selectedPlaceProvider);

    if (selectedPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location from suggestions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current user
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not found');
      }

      // Create emergency model
      final emergency = EmergencyModel(
        id: '', // Will be set by Firestore
        callerName: _callerNameController.text.trim(),
        callerPhone: _callerPhoneController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: formState.priority,
        status: EmergencyStatus.pending,
        patientAddressString: selectedPlace.formattedAddress,
        patientLat: selectedPlace.latitude,
        patientLng: selectedPlace.longitude,
        hospitalId: widget.hospitalId,
        createdBy: currentUser.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create emergency
      final emergencyActions = ref.read(emergencyActionsProvider);
      final emergencyId = await emergencyActions.createEmergency(emergency);

      if (emergencyId != null && mounted) {
        // Reset form
        ref.read(emergencyFormProvider.notifier).resetForm();
        ref.read(selectedPlaceProvider.notifier).state = null;

        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating emergency: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
