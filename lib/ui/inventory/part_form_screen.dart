import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/part_models.dart';
import 'package:rapide_nforce/services/inventory_service.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class PartFormScreen extends StatefulWidget {
  const PartFormScreen({super.key, this.part});

  final PartModel? part;

  bool get isEdit => part != null;

  @override
  State<PartFormScreen> createState() => _PartFormScreenState();
}

class _PartFormScreenState extends State<PartFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _qtyController;
  late final TextEditingController _costController;
  late final TextEditingController _invoiceController;

  List<PartTypeModel> _partTypes = [];
  int? _selectedTypeId;
  bool _loadingTypes = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.part;
    _codeController = TextEditingController(text: p?.code ?? '');
    _qtyController = TextEditingController(text: '${p?.quantity ?? 1}');
    _costController = TextEditingController(
      text: p?.cost != null ? p!.cost!.toStringAsFixed(2) : '',
    );
    _invoiceController = TextEditingController(text: p?.invoiceNumber ?? '');
    _selectedTypeId = p?.typeId;
    _loadTypes();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    _invoiceController.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    final result = await InventoryService.instance.fetchPartTypes(
      page: 1,
      limit: 1000,
    );
    if (!mounted) return;
    setState(() {
      _loadingTypes = false;
      _partTypes = result.data?.items ?? [];
      _selectedTypeId ??= _partTypes.isNotEmpty ? _partTypes.first.id : null;
    });
  }

  double? _parseCost() {
    final t = _costController.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTypeId == null) {
      AppToast.showError('Select a part type');
      return;
    }

    setState(() => _saving = true);
    final qty = int.parse(_qtyController.text.trim());
    final cost = _parseCost();
    final total = cost != null
        ? double.parse((qty * cost).toStringAsFixed(2))
        : null;

    final result = widget.isEdit
        ? await InventoryService.instance.updatePart(
            id: widget.part!.id,
            typeId: _selectedTypeId!,
            code: _codeController.text.trim(),
            quantity: qty,
            cost: cost,
            totalCost: total,
            invoiceNumber: _invoiceController.text.trim().isEmpty
                ? null
                : _invoiceController.text.trim(),
          )
        : await InventoryService.instance.createPart(
            typeId: _selectedTypeId!,
            code: _codeController.text.trim(),
            quantity: qty,
            cost: cost,
            totalCost: total,
            invoiceNumber: _invoiceController.text.trim().isEmpty
                ? null
                : _invoiceController.text.trim(),
          );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.isSuccess) {
      AppToast.showError(result.message ?? 'Save failed');
      return;
    }

    AppToast.showSuccess(widget.isEdit ? 'Part updated' : 'Part created');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit Part' : 'Add Part')),
      body: WebPageBody(
        child: _loadingTypes
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: _selectedTypeId,
                          decoration: const InputDecoration(
                            labelText: 'Part type',
                          ),
                          items: _partTypes
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(t.name),
                                ),
                              )
                              .toList(),
                          onChanged: widget.isEdit
                              ? null
                              : (v) => setState(() => _selectedTypeId = v),
                          validator: (v) =>
                              v == null ? 'Select part type' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _codeController,
                          readOnly: widget.isEdit && widget.part!.isProtected,
                          decoration: const InputDecoration(
                            labelText: 'Part code',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Code is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                          ),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n < 0) {
                              return 'Enter valid quantity';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _costController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Unit cost (optional)',
                            prefixText: '\$ ',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _invoiceController,
                          decoration: const InputDecoration(
                            labelText: 'Invoice number (optional)',
                          ),
                        ),
                        const SizedBox(height: 28),
                        WebPrimaryButton(
                          label: widget.isEdit ? 'Save changes' : 'Create part',
                          loading: _saving,
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
