/// Mirrors web `constants/maintenance.ts` protected inventory parts.
class InventoryHelpers {
  InventoryHelpers._();

  static const noneInvoice = 'INV-None';
  static const shopSuppliesInvoice = 'INV-ShopSupplies';

  static bool isNonePart({
    String? code,
    String? partTypeName,
    String? invoiceNumber,
  }) {
    final c = code?.trim().toLowerCase() ?? '';
    final type = partTypeName?.trim().toLowerCase() ?? '';
    final invoice = invoiceNumber?.trim() ?? '';
    return c == 'none' || type == 'none' || invoice == noneInvoice;
  }

  static bool isShopSuppliesPart({
    String? code,
    String? partTypeName,
    String? invoiceNumber,
  }) {
    final c = code?.trim().toLowerCase() ?? '';
    final type = partTypeName?.trim().toLowerCase() ?? '';
    final invoice = invoiceNumber?.trim() ?? '';
    return c == 'shop supplies' ||
        type == 'shop supplies' ||
        invoice == shopSuppliesInvoice;
  }

  static bool isProtectedPart({
    String? code,
    String? partTypeName,
    String? invoiceNumber,
  }) =>
      isNonePart(
        code: code,
        partTypeName: partTypeName,
        invoiceNumber: invoiceNumber,
      ) ||
      isShopSuppliesPart(
        code: code,
        partTypeName: partTypeName,
        invoiceNumber: invoiceNumber,
      );
}
