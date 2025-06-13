// lib/screens/create_ambulance_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ambulance_model.dart';
import '../providers/ambulance_providers.dart';

class CreateAmbulanceScreen extends ConsumerStatefulWidget {
  final String hospitalId;
  final AmbulanceModel? ambulanceToEdit;

  const CreateAmbulanceScreen({
    Key? key,
    required this.hospitalId,
    this.ambulanceToEdit,
  }) : super(key: key);

  @override
  ConsumerState<CreateAmbulanceScreen> createState() =>
      _CreateAmbulanceScreenState();
}

class _CreateAmbulanceScreenState extends ConsumerState<CreateAmbulanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licensePlateController = TextEditingController();
  final _modelController = TextEditingController();

  AmbulanceStatus _selectedStatus = AmbulanceStatus.offline;
  bool get _isEditing => widget.ambulanceToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFieldsForEditing();
    }
  }

  void _populateFieldsForEditing() {
    final ambulance = widget.ambulanceToEdit!;
    _licensePlateController.text = ambulance.licensePlate;
    _modelController.text = ambulance.model;
    _selectedStatus = ambulance.status;
  }

  @override
  void dispose() {
    _licensePlateController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      final isLoading = ref.watch(ambulanceLoadingProvider);
      final error = ref.watch(ambulanceErrorProvider);

      return _buildScreen(context, isLoading, error);
    } catch (e, stackTrace) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading screen'),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildScreen(BuildContext context, bool isLoading, String? error) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Ambulance' : 'Add New Ambulance',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _handleSave,
            child: Text(
              _isEditing ? 'UPDATE' : 'CREATE',
              style: const TextStyle(
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
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.local_shipping,
                        size: 48,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isEditing
                            ? 'Update Ambulance Details'
                            : 'Add New Ambulance',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isEditing
                            ? 'Modify the ambulance information below'
                            : 'Fill in the details to register a new ambulance',
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
              if (error != null)
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
                        child: Text(error,
                            style: TextStyle(color: Colors.red.shade700)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => ref
                            .read(ambulanceErrorProvider.notifier)
                            .state = null,
                      ),
                    ],
                  ),
                ),

              // Basic Information Section
              _buildSectionTitle('Basic Information'),
              const SizedBox(height: 16),

              // License Plate Field
              TextFormField(
                controller: _licensePlateController,
                decoration: InputDecoration(
                  labelText: 'License Plate *',
                  hintText: 'e.g., ABC-1234',
                  prefixIcon: const Icon(Icons.confirmation_number),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'License plate is required';
                  }
                  if (value.trim().length < 3) {
                    return 'License plate must be at least 3 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Model Field
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: 'Ambulance Model *',
                  hintText: 'e.g., Mercedes Sprinter',
                  prefixIcon: const Icon(Icons.local_shipping),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ambulance model is required';
                  }
                  if (value.trim().length < 2) {
                    return 'Model must be at least 2 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Status Section
              _buildSectionTitle('Status'),
              const SizedBox(height: 16),

              // Status Selection
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
                      'Initial Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...AmbulanceStatus.values.map((status) {
                      final color =
                          Color(AmbulanceStatus.getStatusColor(status));
                      return RadioListTile<AmbulanceStatus>(
                        title: Row(
                          children: [
                            Icon(Icons.circle, color: color, size: 16),
                            const SizedBox(width: 8),
                            Text(status.displayName),
                          ],
                        ),
                        subtitle: Text(_getStatusDescription(status)),
                        value: status,
                        groupValue: _selectedStatus,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedStatus = value;
                            });
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          isLoading ? null : () => Navigator.pop(context),
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
                      onPressed: isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isEditing
                                  ? 'Update Ambulance'
                                  : 'Create Ambulance',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Additional Information
              if (!_isEditing)
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
                        '• Driver assignment can be done after creation\n'
                        '• GPS tracking will be available once a driver is assigned\n'
                        '• Status can be updated at any time',
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

  String _getStatusDescription(AmbulanceStatus status) {
    switch (status) {
      case AmbulanceStatus.available:
        return 'Ready for emergency response';
      case AmbulanceStatus.onDuty:
        return 'Currently responding to emergency';
      case AmbulanceStatus.maintenance:
        return 'Under maintenance or repair';
      case AmbulanceStatus.offline:
        return 'Not in service';
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Clear any existing errors
    ref.read(ambulanceErrorProvider.notifier).state = null;

    if (_isEditing) {
      await _updateAmbulance();
    } else {
      await _createAmbulance();
    }
  }

  Future<void> _createAmbulance() async {
    try {
      // Try using the provider first
      final actions = ref.read(ambulanceActionsProvider);

      final ambulance = AmbulanceModel(
        id: '', // Will be set by Firestore
        licensePlate: _licensePlateController.text.trim().toUpperCase(),
        model: _modelController.text.trim(),
        status: _selectedStatus,
        hospitalId: widget.hospitalId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final ambulanceId = await actions.createAmbulance(ambulance);

      if (ambulanceId != null && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Ambulance ${ambulance.licensePlate} created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // If provider fails, try direct Firestore save
      await _saveDirectToFirestore();
    }
  }

  Future<void> _updateAmbulance() async {
    try {
      final actions = ref.read(ambulanceActionsProvider);
      final updates = <String, dynamic>{};

      if (_licensePlateController.text.trim() !=
          widget.ambulanceToEdit!.licensePlate) {
        updates['licensePlate'] =
            _licensePlateController.text.trim().toUpperCase();
      }

      if (_modelController.text.trim() != widget.ambulanceToEdit!.model) {
        updates['model'] = _modelController.text.trim();
      }

      if (_selectedStatus != widget.ambulanceToEdit!.status) {
        updates['status'] = _selectedStatus.value;
      }

      if (updates.isNotEmpty) {
        final success =
            await actions.updateAmbulance(widget.ambulanceToEdit!.id, updates);
        if (success && mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ambulance updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating ambulance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveDirectToFirestore() async {
    try {
      // Check authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !user.emailVerified) {
        throw 'Please log in with a verified account';
      }

      // Save directly to Firestore
      final firestore = FirebaseFirestore.instance;
      final ambulanceData = {
        'licensePlate': _licensePlateController.text.trim().toUpperCase(),
        'model': _modelController.text.trim(),
        'status': _selectedStatus.value,
        'hospitalId': widget.hospitalId,
        'isActive': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      await firestore.collection('ambulances').add(ambulanceData);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Ambulance ${_licensePlateController.text} created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving ambulance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
