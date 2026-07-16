/// A generated compliance QR code — shared by Power Units and Trailers,
/// mirroring the web's `generateTruckQrCode`/`generateTrailerQrCode`.
class VehicleQrCode {
  const VehicleQrCode({required this.qrCodeDataUrl, required this.downloadUrl});

  final String qrCodeDataUrl;
  final String downloadUrl;
}
