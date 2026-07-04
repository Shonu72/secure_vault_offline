import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_vault_offline/core/theme.dart';

// ── Models & State ────────────────────────────────────────────────────────────
class FormFieldSchema {
  final String id;
  final String type;
  final String label;
  final String? placeholder;
  final bool required;
  final List<Map<String, String>>? options;
  final Map<String, dynamic>? validation;
  final Map<String, String>? visibilityCondition;

  FormFieldSchema({
    required this.id,
    required this.type,
    required this.label,
    this.placeholder,
    this.required = false,
    this.options,
    this.validation,
    this.visibilityCondition,
  });

  factory FormFieldSchema.fromJson(Map<String, dynamic> json) {
    return FormFieldSchema(
      id: json['id'] as String,
      type: json['type'] as String,
      label: json['label'] as String,
      placeholder: json['placeholder'] as String?,
      required: json['required'] as bool? ?? false,
      options: (json['options'] as List?)
          ?.map((e) => Map<String, String>.from(e as Map))
          .toList(),
      validation: json['validation'] as Map<String, dynamic>?,
      visibilityCondition: json['visibilityCondition'] == null
          ? null
          : (json['visibilityCondition'] as Map).map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ),
    );
  }
}

class DynamicFormState {
  final Map<String, String> values;
  final Map<String, String?> errors;

  const DynamicFormState({
    required this.values,
    required this.errors,
  });

  DynamicFormState copyWith({
    Map<String, String>? values,
    Map<String, String?>? errors,
  }) {
    return DynamicFormState(
      values: values ?? this.values,
      errors: errors ?? this.errors,
    );
  }
}

// ── Riverpod Providers ────────────────────────────────────────────────────────
class DynamicFormNotifier extends StateNotifier<DynamicFormState> {
  final List<FormFieldSchema> fields;

  DynamicFormNotifier(this.fields)
      : super(const DynamicFormState(values: {}, errors: {}));

  void initForm(Map<String, String> defaultValues) {
    state = DynamicFormState(
      values: defaultValues,
      errors: {},
    );
  }

  void updateField(String fieldId, String value) {
    final updatedValues = Map<String, String>.from(state.values);
    updatedValues[fieldId] = value;

    // Trigger validation logic for modified field
    final updatedErrors = Map<String, String?>.from(state.errors);
    final fieldSchema = fields.firstWhere((f) => f.id == fieldId);
    updatedErrors[fieldId] = _validateField(fieldSchema, value);

    state = state.copyWith(values: updatedValues, errors: updatedErrors);
  }

  String? _validateField(FormFieldSchema field, String value) {
    if (field.required && value.trim().isEmpty) {
      return '${field.label} is required';
    }
    
    final rule = field.validation;
    if (rule != null && value.isNotEmpty) {
      if (rule.containsKey('regex')) {
        final reg = RegExp(rule['regex'] as String);
        if (!reg.hasMatch(value)) {
          return rule['errorMessage'] as String? ?? 'Invalid format';
        }
      }
      if (rule.containsKey('minValue')) {
        final doubleVal = double.tryParse(value) ?? 0;
        final minLimit = (rule['minValue'] as num).toDouble();
        if (doubleVal < minLimit) {
          return 'Minimum value is $minLimit';
        }
      }
    }
    return null;
  }

  bool validateAll() {
    final newErrors = <String, String?>{};
    bool isValid = true;

    for (final field in fields) {
      // Skip validating if field is hidden by condition
      if (!_isFieldVisible(field)) continue;

      final val = state.values[field.id] ?? '';
      final err = _validateField(field, val);
      if (err != null) {
        newErrors[field.id] = err;
        isValid = false;
      }
    }

    state = state.copyWith(errors: newErrors);
    return isValid;
  }

  bool _isFieldVisible(FormFieldSchema field) {
    final condition = field.visibilityCondition;
    if (condition == null) return true;

    final depFieldId = condition['fieldId'];
    final expectedVal = condition['equals'];
    final actualVal = state.values[depFieldId];
    return actualVal == expectedVal;
  }
}

final dynamicFormStateProvider =
    StateNotifierProvider.family<DynamicFormNotifier, DynamicFormState, List<FormFieldSchema>>((ref, fields) {
  return DynamicFormNotifier(fields);
});

// ── UI Page Layout ────────────────────────────────────────────────────────────
class AddAssetPage extends ConsumerStatefulWidget {
  const AddAssetPage({super.key});

  @override
  ConsumerState<AddAssetPage> createState() => _AddAssetPageState();
}

class _AddAssetPageState extends ConsumerState<AddAssetPage> {
  List<FormFieldSchema> _fields = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchemaFromAssets();
  }

  Future<void> _loadSchemaFromAssets() async {
    try {
      // Load and parse dynamic form schema config from local file assets
      final jsonString = await rootBundle.loadString('assets/form_schema.json');
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      final List<dynamic> fieldsList = jsonMap['fields'] as List;

      setState(() {
        _fields = fieldsList.map((e) => FormFieldSchema.fromJson(e as Map<String, dynamic>)).toList();
        _isLoading = false;
      });

      // Populate default state values (crypto default selected)
      ref.read(dynamicFormStateProvider(_fields).notifier).initForm({
        'asset_type': 'crypto',
        'asset_name': 'Bitcoin (BTC)',
        'wallet_address': '0x1A2B3C', // Pre-populated to trigger validation warning in mockup
        'network': 'Ethereum ERC-20',
      });
    } catch (e) {
      // In case bundle fails (e.g. during fresh setup tests), fall back to memory schema
      _loadFallbackSchema();
    }
  }

  void _loadFallbackSchema() {
    final fallbackFields = [
      FormFieldSchema(
        id: 'asset_name',
        type: 'text',
        label: 'Asset Name',
        placeholder: 'e.g. Bitcoin (BTC)',
        required: true,
      ),
      FormFieldSchema(
        id: 'asset_type',
        type: 'dropdown',
        label: 'Asset Type',
        required: true,
        options: [
          {'label': 'Crypto', 'value': 'crypto'},
          {'label': 'Fixed Deposit', 'value': 'fd'},
          {'label': 'Stocks', 'value': 'stocks'},
        ],
      ),
      FormFieldSchema(
        id: 'wallet_address',
        type: 'text',
        label: 'Wallet Address',
        placeholder: 'Enter crypto wallet address',
        required: true,
        visibilityCondition: {'fieldId': 'asset_type', 'equals': 'crypto'},
        validation: {
          'regex': r'^0x[a-fA-F0-9]{40}$',
          'errorMessage': 'Invalid Wallet Address',
        },
      ),
      FormFieldSchema(
        id: 'network',
        type: 'dropdown',
        label: 'Network (optional)',
        options: [
          {'label': 'Ethereum ERC-20', 'value': 'Ethereum ERC-20'},
          {'label': 'Bitcoin Network', 'value': 'Bitcoin Network'},
          {'label': 'Solana SPL', 'value': 'Solana SPL'},
        ],
      ),
      FormFieldSchema(
        id: 'memo',
        type: 'text',
        label: 'Memo (optional)',
        placeholder: 'Memo',
      ),
    ];

    setState(() {
      _fields = fallbackFields;
      _isLoading = false;
    });

    ref.read(dynamicFormStateProvider(_fields).notifier).initForm({
      'asset_type': 'crypto',
      'asset_name': 'Bitcoin (BTC)',
      'wallet_address': '0x1A2B3C',
      'network': 'Ethereum ERC-20',
    });
  }

  void _onSave() {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(dynamicFormStateProvider(_fields).notifier);
    if (notifier.validateAll()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Asset Saved Successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    } else {
      HapticFeedback.vibrate(); // error feedback
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final formState = ref.watch(dynamicFormStateProvider(_fields));
    final notifier = ref.read(dynamicFormStateProvider(_fields).notifier);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Asset',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _onSave,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Asset Details',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Render all dynamically visible form fields
            ..._fields.map((field) {
              // Check visibility condition rule
              final isVisible = notifier._isFieldVisible(field);
              if (!isVisible) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: _buildFormField(field, formState, notifier),
              );
            }),

            const SizedBox(height: 24),

            // Add Asset Primary Action Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E286F), // Deep blue theme button in mockup
                  foregroundColor: AppColors.textPrimary,
                ),
                onPressed: _onSave,
                child: const Text(
                  'Add Asset',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(
    FormFieldSchema field,
    DynamicFormState state,
    DynamicFormNotifier notifier,
  ) {
    final value = state.values[field.id] ?? '';
    final error = state.errors[field.id];

    switch (field.type) {
      case 'dropdown':
        final options = field.options ?? [];
        return DropdownButtonFormField<String>(
          value: value.isEmpty ? null : value,
          dropdownColor: AppColors.surface,
          decoration: InputDecoration(
            labelText: field.label,
            prefixIcon: Icon(_getFieldIcon(field.id), color: AppColors.textSecondary),
            errorText: error,
          ),
          items: options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt['value'],
              child: Text(opt['label'] ?? ''),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              notifier.updateField(field.id, val);
            }
          },
        );

      case 'text':
      case 'numeric':
      default:
        // Use local TextEditingController dynamically to prevent rebuilding on every keystroke
        return TextFormField(
          initialValue: value,
          keyboardType: field.type == 'numeric' ? TextInputType.number : TextInputType.text,
          onChanged: (val) => notifier.updateField(field.id, val),
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.placeholder,
            errorText: error,
            prefixIcon: Icon(_getFieldIcon(field.id), color: AppColors.textSecondary),
            suffixIcon: error != null
                ? const Icon(Icons.error_outline_rounded, color: AppColors.borderError)
                : value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                        onPressed: () => notifier.updateField(field.id, ''),
                      )
                    : null,
          ),
        );
    }
  }

  IconData _getFieldIcon(String id) {
    switch (id) {
      case 'asset_name':
        return Icons.business_center_outlined;
      case 'asset_type':
        return Icons.swap_horizontal_circle_outlined;
      case 'wallet_address':
        return Icons.account_balance_wallet_outlined;
      case 'network':
        return Icons.lan_outlined;
      case 'memo':
      default:
        return Icons.notes_outlined;
    }
  }
}
