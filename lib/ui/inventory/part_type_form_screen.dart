import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/part_models.dart';
import 'package:rapide_nforce/services/inventory_service.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class PartTypeFormScreen extends StatefulWidget {
  const PartTypeFormScreen({super.key, this.partType});

  final PartTypeModel? partType;

  bool get isEdit => partType != null;

  @override
  State<PartTypeFormScreen> createState() => _PartTypeFormScreenState();
}

class _PartTypeFormScreenState extends State<PartTypeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _triggerController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.partType?.name ?? '');
    _triggerController = TextEditingController(
      text: '${widget.partType?.lowStockTrigger ?? 5}',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _triggerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final name = _nameController.text.trim();
    final trigger = int.parse(_triggerController.text.trim());

    final result = widget.isEdit
        ? await InventoryService.instance.updatePartType(
            id: widget.partType!.id,
            name: name,
            lowStockTrigger: trigger,
          )
        : await InventoryService.instance.createPartType(
            name: name,
            lowStockTrigger: trigger,
          );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.isSuccess) {
      AppToast.showError(result.message ?? 'Save failed');
      return;
    }

    AppToast.showSuccess(widget.isEdit ? 'Part type updated' : 'Part type created');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Part Type' : 'Add Part Type'),
      ),
      body: WebPageBody(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Part type name'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _triggerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Low stock trigger',
                      helperText: 'Alert when quantity falls below this number',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 0) return 'Enter a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  WebPrimaryButton(
                    label: widget.isEdit ? 'Save changes' : 'Create part type',
                    loading: _loading,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
