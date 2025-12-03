import 'package:intl/intl.dart';

class Sparepart {
  final String idProduk;
  final String nama;
  final String merek;
  final String kategori;
  final List<String> tipeMotor;
  final String? deskripsi;
  final String? gambarUrl;
  final double? harga;
  final int? stok;
  final String? satuan;
  final Map<String, dynamic>? spesifikasi;

  Sparepart({
    required this.idProduk,
    required this.nama,
    required this.merek,
    required this.kategori,
    required this.tipeMotor,
    this.deskripsi,
    this.gambarUrl,
    this.harga,
    this.stok,
    this.satuan,
    this.spesifikasi,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_produk': idProduk,
      'nama': nama,
      'merek': merek,
      'kategori': kategori,
      'tipe_motor': tipeMotor,
      'deskripsi': deskripsi,
      // Persist using gambar_url to match DB column
      'gambar_url': gambarUrl,
      'harga': harga,
      'stok': stok,
      'satuan': satuan,
      'spesifikasi': spesifikasi,
    };
  }

  factory Sparepart.fromMap(Map<String, dynamic> map) {
    return Sparepart(
      idProduk: map['id_produk']?.toString() ?? '',
      nama: map['nama'] ?? '',
      merek: map['merek'] ?? '',
      kategori: map['kategori'] ?? '',
      tipeMotor: map['tipe_motor'] != null
          ? List<String>.from(
              map['tipe_motor'] is List
                  ? map['tipe_motor']
                  : [map['tipe_motor']],
            )
          : [],
      deskripsi: map['deskripsi'],
      // Read gambar_url first, fall back to common keys for backward compatibility
      gambarUrl:
          map['gambar_url'] ??
          map['image_url'] ??
          map['image'] ??
          map['gambar'],
      harga: map['harga'] != null
          ? (map['harga'] is int
                ? map['harga'].toDouble()
                : (map['harga'] as num).toDouble())
          : null,
      stok: map['stok'] != null ? (map['stok'] as num).toInt() : null,
      satuan: map['satuan'],
      spesifikasi: map['spesifikasi'] != null
          ? Map<String, dynamic>.from(map['spesifikasi'])
          : null,
    );
  }

  String get tipeMotorString => tipeMotor.join(', ');

  String get hargaFormatted {
    if (harga == null) return 'Harga tidak tersedia';
    return 'Rp ${NumberFormat('#,##0', 'id_ID').format(harga)}';
  }
}
