import 'package:flutter/material.dart';
import '../models/sparepart.dart';
import '../services/exchange_rate_service.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

class SparepartDetailPage extends StatefulWidget {
  final Sparepart sparepart;

  const SparepartDetailPage({super.key, required this.sparepart});

  @override
  State<SparepartDetailPage> createState() => _SparepartDetailPageState();
}

class _SparepartDetailPageState extends State<SparepartDetailPage> {
  final ExchangeRateService _exchangeService = ExchangeRateService();

  String _selectedCurrency = 'IDR';
  double? _convertedPrice;
  bool _isConverting = false;
  String _conversionError = '';

  final List<Map<String, String>> _currencies = [
    {'code': 'IDR', 'symbol': 'Rp', 'name': 'Indonesian Rupiah'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
  ];

  @override
  void initState() {
    super.initState();
    _convertedPrice = widget.sparepart.harga?.toDouble();
  }

  Future<void> _convertCurrency(String toCurrency) async {
    if (widget.sparepart.harga == null) return;

    setState(() {
      _isConverting = true;
      _conversionError = '';
    });

    try {
      final convertedAmount = await _exchangeService.convertCurrency(
        amount: widget.sparepart.harga!.toDouble(),
        from: 'IDR', // Asumsi harga dari API dalam IDR
        to: toCurrency,
      );

      if (mounted) {
        setState(() {
          _convertedPrice = convertedAmount;
          _selectedCurrency = toCurrency;
          _isConverting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _conversionError = 'Gagal konversi: ${e.toString()}';
          _isConverting = false;
        });
      }
    }
  }

  String _formatPrice(double? price, String currencyCode) {
    if (price == null) return 'N/A';

    final currency = _currencies.firstWhere(
      (c) => c['code'] == currencyCode,
      orElse: () => {'symbol': '', 'code': currencyCode},
    );

    final formatter = NumberFormat.currency(
      symbol: currency['symbol'] ?? '',
      decimalDigits: currencyCode == 'IDR' || currencyCode == 'JPY' ? 0 : 2,
      locale: 'id_ID',
    );

    return formatter.format(price);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: kAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Sparepart'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        backgroundColor: kAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Hero(
              tag: 'sparepart-${widget.sparepart.idProduk}',
              child: Container(
                width: double.infinity,
                height: 300,
                color: kCardAlt.withValues(alpha: 0.3),
                child:
                    widget.sparepart.gambarUrl != null &&
                        widget.sparepart.gambarUrl!.isNotEmpty
                    ? Image.network(
                        widget.sparepart.gambarUrl!,
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 64,
                                  color: kMuted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Gambar tidak tersedia',
                                  style: TextStyle(color: kMuted),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Icon(
                          Icons.bike_scooter,
                          size: 100,
                          color: kMuted,
                        ),
                      ),
              ),
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.sparepart.kategori,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: kAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Product Name
                  Text(
                    widget.sparepart.nama,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Price Section with Currency Converter
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Harga',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (_isConverting)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (widget.sparepart.harga != null) ...[
                          Text(
                            _formatPrice(_convertedPrice, _selectedCurrency),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _currencies.map((currency) {
                              final isSelected =
                                  currency['code'] == _selectedCurrency;
                              return FilterChip(
                                label: Text(
                                  '${currency['code']} ${currency['symbol']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : Theme.of(context).primaryColor,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: Theme.of(context).primaryColor,
                                backgroundColor: Colors.white,
                                onSelected: (selected) {
                                  if (selected && !_isConverting) {
                                    _convertCurrency(currency['code']!);
                                  }
                                },
                                side: BorderSide(
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[300]!,
                                ),
                              );
                            }).toList(),
                          ),
                          if (_conversionError.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _conversionError,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ] else
                          Text(
                            'Harga tidak tersedia',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(color: kMuted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Product Information
                  Text(
                    'Informasi Produk',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildInfoRow(
                    Icons.qr_code,
                    'ID Produk',
                    widget.sparepart.idProduk,
                  ),
                  _buildInfoRow(Icons.label, 'Merek', widget.sparepart.merek),
                  _buildInfoRow(
                    Icons.category,
                    'Kategori',
                    widget.sparepart.kategori,
                  ),
                  if (widget.sparepart.tipeMotor.isNotEmpty)
                    _buildInfoRow(
                      Icons.two_wheeler,
                      'Tipe Motor',
                      widget.sparepart.tipeMotorString,
                    ),
                  if (widget.sparepart.stok != null)
                    _buildInfoRow(
                      Icons.inventory_2,
                      'Stok',
                      '${widget.sparepart.stok} ${widget.sparepart.satuan ?? ''}',
                    ),

                  // Description
                  if (widget.sparepart.deskripsi != null &&
                      widget.sparepart.deskripsi!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Deskripsi',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.sparepart.deskripsi!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],

                  // Specifications
                  if (widget.sparepart.spesifikasi != null &&
                      widget.sparepart.spesifikasi!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Spesifikasi',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: widget.sparepart.spesifikasi!.entries
                            .map(
                              (entry) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 3,
                                      child: Text(entry.value.toString()),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
