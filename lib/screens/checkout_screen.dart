import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../config/pocketbase_config.dart';
import '../providers/cart_provider.dart';
import '../services/pocketbase_service.dart';
import '../services/biteship_service.dart';
import '../models/shipping_models.dart';
import 'dashboard_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _hpController = TextEditingController();
  final _alamatController = TextEditingController();

  bool _isLoading = false;
  bool _showSuccess = false;
  bool _isLoadingCities = false; // Default false, akan coba load dari API
  bool _isLoadingShipping = false;
  String? _orderId;

  // Simpan data untuk pesan WhatsApp
  List<CartItem> _checkoutItems = [];
  int _checkoutSubtotal = 0;
  int _checkoutOngkir = 0;
  int _checkoutTotal = 0;

  // Data user untuk navigasi ke dashboard
  String _userName = '';
  String _userId = '';
  String _userNamaToko = '';
  String _userDaerah = '';
  String _userNoWa = '';
  String _userNoAnggota = '';
  String _userNamaLengkap = '';
  String _userJabatan = '';
  String? _userSebagai;
  String _userAlamat = '';
  String? _userInstagram;
  String? _userFacebook;
  String? _userTiktok;
  String? _userWebsite;

  // Biteship - Kota/Area untuk tujuan pengiriman
  List<City> _cities = [];
  City? _selectedDestinationCity;

  // Shipping options
  List<ShippingResult> _shippingOptions = [];
  ShippingResult? _selectedCourier;
  ShippingService? _selectedService;

  // Weight in grams
  int _totalWeight = 0;

  // Fallback cities list (Jawa Timur)
  static const List<Map<String, String>> _fallbackCities = [
    {'id': '501', 'name': 'Surabaya'},
    {'id': '502', 'name': 'Sidoarjo'},
    {'id': '503', 'name': 'Gresik'},
    {'id': '504', 'name': 'Malang'},
    {'id': '505', 'name': 'Kota Malang'},
    {'id': '506', 'name': 'Kabupaten Malang'},
    {'id': '507', 'name': 'Pasuruan'},
    {'id': '508', 'name': 'Mojokerto'},
    {'id': '509', 'name': 'Jember'},
    {'id': '510', 'name': 'Banyuwangi'},
    {'id': '511', 'name': 'Bondowoso'},
    {'id': '512', 'name': 'Situbondo'},
    {'id': '513', 'name': 'Probolinggo'},
    {'id': '514', 'name': 'Lumajang'},
    {'id': '515', 'name': 'Kediri'},
    {'id': '516', 'name': 'Jombang'},
    {'id': '517', 'name': 'Madiun'},
    {'id': '518', 'name': 'Ngawi'},
    {'id': '519', 'name': 'Bojonegoro'},
    {'id': '520', 'name': 'Lamongan'},
    {'id': '521', 'name': 'Tuban'},
    {'id': '522', 'name': 'Bangkalan'},
    {'id': '523', 'name': 'Sampang'},
    {'id': '524', 'name': 'Pamekasan'},
    {'id': '525', 'name': 'Sumenep'},
    {'id': '526', 'name': 'Batu'},
    {'id': '527', 'name': 'Blitar'},
    {'id': '528', 'name': 'Tulungagung'},
    {'id': '529', 'name': 'Trenggalek'},
    {'id': '530', 'name': 'Ponorogo'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCities();
    _calculateWeight();
  }

  void _calculateWeight() {
    final cart = context.read<CartProvider>();
    setState(() {
      _totalWeight = cart.items.fold(0, (sum, item) => sum + item.totalBerat);
    });
  }

  Future<void> _loadCities() async {
    // Load fallback cities immediately with setState
    final fallbackCities = _fallbackCities.map((c) => City(
      id: c['id']!,
      provinceId: '12', // Jawa Timur
      province: 'Jawa Timur',
      type: 'Kota',
      cityName: c['name']!,
      postalCode: '',
    )).toList();

    setState(() {
      _cities = fallbackCities;
    });

    // Try to load from Biteship API in background (update if successful)
    try {
      final biteship = BiteshipService();
      await biteship.initCache();
      final areas = await biteship.getAreas();

      if (mounted && areas.isNotEmpty) {
        setState(() {
          _cities = areas.map((a) => City(
            id: a['id'] ?? '',
            provinceId: a['province_id'] ?? '',
            province: a['province'] ?? 'Jawa Timur',
            type: a['type'] ?? 'Kota',
            cityName: a['name'] ?? '',
            postalCode: a['postal_code'] ?? '',
          )).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading areas from Biteship, using fallback: $e');
      // Fallback cities already loaded above
    }
  }

  void _loadUserData() async {
    try {
      final pb = PocketBaseService.instance;
      final user = pb.authStore.record;
      if (user != null) {
        final userData = user.data;
        setState(() {
          // Fase 1: `users_auth` punya field `name`, `phone`, `daerah`, `alamat`.
          // `namatoko`, `nowa`, `noanggota` TIDAK ada di users_auth.
          // Fallback ke field legacy untuk backward compat.
          _namaController.text = userData['name']?.toString() ?? '';
          _userName = userData['name']?.toString() ?? '';
          _userId = user.id;
          _userNamaToko = userData['namatoko']?.toString() ?? '';
          _userDaerah = userData['daerah']?.toString() ?? '';
          // `phone` untuk users_auth, `nowa` fallback untuk legacy
          _userNoWa = userData['phone']?.toString() ??
              userData['nowa']?.toString() ??
              '';
          _userNoAnggota = userData['noanggota']?.toString() ?? '';
          _userNamaLengkap = userData['name']?.toString() ?? '';
          _userJabatan = userData['jabatan']?.toString() ?? '';
          _userSebagai = userData['sebagai']?.toString();
          _userAlamat = userData['alamat']?.toString() ?? '';
          _userInstagram = userData['instagram']?.toString();
          _userFacebook = userData['facebook']?.toString();
          _userTiktok = userData['tiktok']?.toString();
          _userWebsite = userData['website']?.toString();
          // Autofill address fields for registered user
          _hpController.text = _userNoWa;
          _alamatController.text = _userAlamat;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hpController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.items.isEmpty && !_showSuccess) {
            return const Center(child: Text('Keranjang kosong'));
          }

          if (_showSuccess) {
            return _buildSuccessScreen();
          }

          return _buildCheckoutForm(cart);
        },
      ),
    );
  }

  Widget _buildCheckoutForm(CartProvider cart) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Berat Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.scale, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Text(
                    'Total Berat: $_totalWeight gram',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Alamat Pengiriman
            Text(
              'Alamat Pengiriman',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildAddressForm(),
            const SizedBox(height: 24),

            // Pilihan Pengiriman
            Text(
              'Pilihan Pengiriman',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildShippingSection(),
            const SizedBox(height: 24),

            // Ringkasan Belanja
            Text(
              'Ringkasan Belanja',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildOrderSummary(cart),
            const SizedBox(height: 24),

            // Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || _selectedService == null)
                    ? null
                    : () => _processCheckout(cart),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(
                  _isLoading
                      ? 'MEMPROSES...'
                      : (_selectedService == null
                          ? 'PILIH KOTA TERLEBIH DAHULU'
                          : 'CHECKOUT'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _namaController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama Lengkap',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Nama wajib diisi';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _hpController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'No. HP / WhatsApp',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'No. HP wajib diisi';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _alamatController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Alamat Lengkap',
              prefixIcon: Icon(Icons.location_on_outlined),
              alignLabelWithHint: true,
              hintText: 'Jl. Nama Jalan, RT/RW, Kelurahan, Kecamatan',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Alamat wajib diisi';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Kota Tujuan Dropdown
          _isLoadingCities
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              : DropdownButtonFormField<City>(
                  value: _selectedDestinationCity,
                  decoration: const InputDecoration(
                    labelText: 'Kota Tujuan *',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  hint: const Text('Pilih kota tujuan'),
                  isExpanded: true,
                  items: _cities.map((city) {
                    return DropdownMenuItem(
                      value: city,
                      child: Text(
                        city.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (city) {
                    setState(() {
                      _selectedDestinationCity = city;
                      _shippingOptions = [];
                      _selectedCourier = null;
                      _selectedService = null;
                    });
                    if (city != null) {
                      _checkShipping();
                    }
                  },
                  validator: (value) {
                    if (value == null) return 'Pilih kota tujuan';
                    return null;
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildShippingSection() {
    if (_selectedDestinationCity == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pilih kota tujuan terlebih dahulu untuk melihat pilihan pengiriman',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingShipping) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Menghitung ongkir...'),
            ],
          ),
        ),
      );
    }

    if (_shippingOptions.isEmpty && !_isLoadingShipping) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tidak ada opsi pengiriman tersedia untuk route ini',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: _shippingOptions.map((courier) {
          return _buildCourierCard(courier);
        }).toList(),
      ),
    );
  }

  Widget _buildCourierCard(ShippingResult courier) {
    final isExpanded = _selectedCourier?.courierCode == courier.courierCode;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _selectedCourier = null;
                _selectedService = null;
              } else {
                _selectedCourier = courier;
                if (courier.services.isNotEmpty) {
                  _selectedService = courier.services.first;
                }
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isExpanded
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      courier.courierCode.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courier.courierName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${courier.services.length} opsi layanan',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isExpanded)
                  const Icon(Icons.expand_less)
                else
                  const Icon(Icons.expand_more),
              ],
            ),
          ),
        ),
        if (isExpanded)
          ...courier.services.map((service) {
            final isSelected = _selectedService?.serviceName == service.serviceName;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedService = service;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(left: 24),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.successColor.withOpacity(0.1)
                      : Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Radio<String>(
                      value: service.serviceName,
                      groupValue: _selectedService?.serviceName,
                      onChanged: (value) {
                        setState(() {
                          _selectedService = service;
                        });
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.serviceName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'ETD: ${service.etd} hari',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Rp ${_formatNumber(service.cost)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSelected
                            ? AppTheme.successColor
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _checkShipping() async {
    if (_selectedDestinationCity == null) return;

    setState(() {
      _isLoadingShipping = true;
      _shippingOptions = [];
    });

    try {
      final cart = context.read<CartProvider>();
      final biteship = BiteshipService();
      await biteship.initCache();

      List<ShippingResult> allResults = [];

      // Get unique cities (origins) from sellers
      final uniqueOrigins = cart.uniqueSellerCities;

      // For simplicity, use the first seller's city as origin
      if (uniqueOrigins.isNotEmpty) {
        final originCity = uniqueOrigins.first;

        // Map our city names to Biteship area IDs
        final originAreaId = await _getAreaId(originCity);
        final destinationAreaId = _selectedDestinationCity!.id;

        if (originAreaId != null) {
          try {
            final result = await biteship.getShippingCost(
              originAreaId: originAreaId,
              destinationAreaId: destinationAreaId,
              weight: _totalWeight,
            );

            if (result.isNotEmpty && result['pricing'] != null) {
              final pricing = result['pricing'] as List;
              for (var courierData in pricing) {
                try {
                  allResults.add(ShippingResult.fromJson(courierData));
                } catch (e) {
                  debugPrint('Error parsing courier: $e');
                }
              }
            }

            // If no results, use fallback
            if (allResults.isEmpty) {
              allResults = _getFallbackShippingOptions();
            }
          } catch (apiError) {
            debugPrint('Biteship API error, using fallback: $apiError');
            allResults = _getFallbackShippingOptions();
          }
        } else {
          allResults = _getFallbackShippingOptions();
        }
      } else {
        allResults = _getFallbackShippingOptions();
      }

      if (mounted) {
        setState(() {
          _shippingOptions = allResults;
          _isLoadingShipping = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking shipping: $e');
      if (mounted) {
        setState(() {
          _shippingOptions = _getFallbackShippingOptions();
          _isLoadingShipping = false;
        });
      }
    }
  }

  /// Get fallback shipping options when API is unavailable
  List<ShippingResult> _getFallbackShippingOptions() {
    // Fixed rates per kg (can be customized later)
    final weightKg = (_totalWeight / 1000).ceil(); // Round up to nearest kg
    final minWeightKg = weightKg < 1 ? 1 : weightKg;

    return [
      ShippingResult(
        courierName: 'J&T Express',
        courierCode: 'jnt',
        services: [
          ShippingService(
            serviceName: 'REG',
            description: 'Regular Service',
            cost: 12000 * minWeightKg,
            etd: 3,
          ),
          ShippingService(
            serviceName: 'YES',
            description: 'Yakin Esok Sampai',
            cost: 18000 * minWeightKg,
            etd: 1,
          ),
        ],
      ),
      ShippingResult(
        courierName: 'JNE',
        courierCode: 'jne',
        services: [
          ShippingService(
            serviceName: 'REG',
            description: 'Regular Service',
            cost: 15000 * minWeightKg,
            etd: 4,
          ),
          ShippingService(
            serviceName: 'YES',
            description: 'Yakin Esok Sampai',
            cost: 22000 * minWeightKg,
            etd: 1,
          ),
        ],
      ),
      ShippingResult(
        courierName: 'SiCepat',
        courierCode: 'sicepat',
        services: [
          ShippingService(
            serviceName: 'REG',
            description: 'Regular Service',
            cost: 14000 * minWeightKg,
            etd: 3,
          ),
          ShippingService(
            serviceName: 'SIUNTUNG',
            description: 'Same Day',
            cost: 25000 * minWeightKg,
            etd: 0,
          ),
        ],
      ),
      ShippingResult(
        courierName: 'AnterAja',
        courierCode: 'anteraja',
        services: [
          ShippingService(
            serviceName: 'REG',
            description: 'Regular Service',
            cost: 10000 * minWeightKg,
            etd: 4,
          ),
          ShippingService(
            serviceName: 'STAR',
            description: 'Priority Service',
            cost: 16000 * minWeightKg,
            etd: 2,
          ),
        ],
      ),
    ];
  }

  // Get Biteship area ID from city name
  Future<String?> _getAreaId(String cityName) async {
    // Biteship uses area IDs - for now, use fallback mapping
    // In production, you'd have a pre-loaded mapping of cities to Biteship area IDs

    // Try to find city in our loaded cities
    for (var city in _cities) {
      if (city.cityName.toLowerCase().contains(cityName.toLowerCase()) ||
          cityName.toLowerCase().contains(city.cityName.toLowerCase())) {
        return city.id; // Return our city ID as Biteship area ID
      }
    }

    // If not found, try partial match
    final normalizedName = cityName.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    for (var city in _cities) {
      final normalizedCityName = city.cityName.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
      if (normalizedCityName.contains(normalizedName) ||
          normalizedName.contains(normalizedCityName)) {
        return city.id;
      }
    }

    // Default to Surabaya area ID
    debugPrint('City not found: $cityName, using default');
    return '501'; // Surabaya
  }

  Widget _buildOrderSummary(CartProvider cart) {
    final shippingCost = _selectedService?.cost ?? 0;
    final totalPayment = (cart.totalAmount + shippingCost).toInt();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cart.items.length,
            separatorBuilder: (_, __) => Divider(height: 1),
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return ListTile(
                dense: true,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: item.productImage.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: item.productImage,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => const Icon(Icons.image, size: 20),
                          ),
                        )
                      : const Icon(Icons.image, size: 20),
                ),
                title: Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  '${item.quantity}x ${item.berat}g',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                trailing: Text(
                  'Rp ${_formatNumber(item.subtotal)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              );
            },
          ),
          const Divider(),

          // Shipping cost section
          if (_selectedService != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_shipping, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Ongkos Kirim (${_selectedCourier?.courierName} ${_selectedService?.serviceName})',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                  Text(
                    'Rp ${_formatNumber(shippingCost)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 14)),
                    Text(
                      'Rp ${_formatNumber(cart.totalAmount)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                if (_selectedService != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ongkos Kirim', style: TextStyle(fontSize: 14)),
                      Text(
                        'Rp ${_formatNumber(shippingCost)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Pembayaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rp ${_formatNumber(totalPayment)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    // Cek apakah ada nomor WA penjual
    bool hasSellerWa = _checkoutItems.any((item) => item.sellerWa.isNotEmpty);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 80,
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Checkout Berhasil!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Order ID: $_orderId',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Preview Pesan WhatsApp
            if (hasSellerWa) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.preview, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Preview Pesan WhatsApp',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Preview dengan foto produk
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Foto produk (jika ada)
                          if (_checkoutItems.isNotEmpty && _checkoutItems.first.productImage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: _checkoutItems.first.productImage,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) => Container(
                                    height: 120,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.image, size: 40),
                                  ),
                                ),
                              ),
                            ),

                          // Preview teks pesan
                          Text(
                            _generateWhatsAppMessage(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Hubungi via WhatsApp
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _sendWhatsAppToAllSellers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Text('💬', style: TextStyle(fontSize: 24)),
                  label: const Text(
                    'KIRIM VIA WHATSAPP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasSellerWa
                          ? 'Pesanan Anda akan diproses. Klik tombol WhatsApp untuk menghubungi penjual.'
                          : 'Pesanan Anda akan diproses. Penjual akan menghubungi Anda via WhatsApp.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tombol kembali
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('LIHAT KERANJANG'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigasi ke Dashboard dengan replace semua route
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DashboardScreen(
                            username: _userName.isNotEmpty ? _userName : _namaController.text.trim(),
                            namaToko: _userNamaToko,
                            daerah: _userDaerah,
                            noWa: _userNoWa,
                            userId: _userId,
                            noAnggota: _userNoAnggota,
                            namaLengkap: _userNamaLengkap.isNotEmpty ? _userNamaLengkap : _namaController.text.trim(),
                            jabatan: _userJabatan,
                            sebagai: _userSebagai,
                            alamat: _userAlamat,
                            instagram: _userInstagram,
                            facebook: _userFacebook,
                            tiktok: _userTiktok,
                            website: _userWebsite,
                          ),
                        ),
                        (route) => false, // Hapus semua route sebelumnya
                      );
                    },
                    child: const Text('KE BERANDA'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _processCheckout(CartProvider cart) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih metode pengiriman terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pb = PocketBaseService.instance;
      final user = pb.authStore.record;
      if (user == null) {
        throw Exception('Anda harus login untuk checkout');
      }

      // Get shipping info
      final shippingInfo = {
        'courier': _selectedCourier?.courierCode ?? '',
        'courierName': _selectedCourier?.courierName ?? '',
        'service': _selectedService?.serviceName ?? '',
        'cost': _selectedService?.cost ?? 0,
        'etd': _selectedService?.etd ?? 0,
        'destinationCity': _selectedDestinationCity?.displayName ?? '',
        'totalWeight': _totalWeight,
      };

      // Simpan data untuk pesan WhatsApp
      final shippingCost = _selectedService?.cost ?? 0;
      _checkoutItems = List.from(cart.items);
      _checkoutSubtotal = cart.totalAmount;
      _checkoutOngkir = shippingCost;
      _checkoutTotal = cart.totalAmount + shippingCost;

      final buyerAddress = _alamatController.text.trim();
      final buyerPhone = _hpController.text.trim();
      final buyerName = _namaController.text.trim();
      final kurirName = _selectedCourier?.courierCode ?? '';
      final serviceName = _selectedService?.serviceName ?? '';

      // ============================================
      // Fase 1: Buat PesananMarketplace per seller group
      // ============================================
      // CartProvider.itemsBySeller = Map<sellerId, List<CartItem>>
      // Kita group per seller, buat 1 PesananMarketplace per seller.
      final itemsBySeller = cart.itemsBySeller;
      final orderIds = <String>[];

      for (final entry in itemsBySeller.entries) {
        final sellerId = entry.key;
        final sellerItems = entry.value;
        if (sellerId.isEmpty) {
          debugPrint('Skip seller with empty id');
          continue;
        }

        // Hitung subtotal seller ini
        final sellerSubtotal = sellerItems.fold(0, (sum, item) => sum + item.subtotal);

        // Untuk pasar: ongkir per seller (simplified: pakai ongkir global dibagi rata,
        // atau satu ongkir per order). Kita pakai ongkir global untuk order ini.
        // Real implementation nanti kalau multi-seller butuh ongkir terhitung per seller.
        final orderTotal = sellerSubtotal + shippingCost;

        try {
          final result = await pb
              .collection(PocketBaseConfig.pesananMarketplaceCollection)
              .create(
            body: {
              'buyer': user.id, // users_auth record id
              'seller': sellerId, // SellersMarketplace record id
              'items': sellerItems.map((i) => i.toJson()).toList(),
              'total_harga': sellerSubtotal,
              'ongkir': shippingCost,
              'total_bayar': orderTotal,
              'status': 'pending',
              'alamat_kirim': buyerAddress,
              'no_wa_buyer': buyerPhone,
              'kurir': '$kurirName $serviceName'.trim(),
              // 'catatan' optional — bisa ditambah nanti
            },
          );
          orderIds.add(result.id);
        } catch (e) {
          debugPrint('Error create order for seller $sellerId: $e');
          // Lanjut ke seller berikutnya
        }
      }

      // Fallback ke Pesanan legacy kalau tidak ada PesananMarketplace yang terbuat
      if (orderIds.isEmpty) {
        debugPrint('No PesananMarketplace created — try legacy Pesanan');
        final result = await pb
            .collection(PocketBaseConfig.pesananCollection)
            .create(
          body: {
            'buyerid': user.id,
            'buyername': buyerName,
            'buyerphone': buyerPhone,
            'buyeraddress': buyerAddress,
            'totalamount': cart.totalAmount + shippingCost,
            'shippingcost': shippingCost,
            'shippinginfo': shippingInfo,
            'status': 'pending',
            'items': cart.items.map((item) => item.toJson()).toList(),
          },
        );
        orderIds.add(result.id);
      }

      setState(() {
        _orderId = orderIds.first; // Show first order id di success screen
        _showSuccess = true;
        _isLoading = false;
      });

      // Clear cart
      cart.clear();

    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  /// Generate pesan WhatsApp otomatis
  String _generateWhatsAppMessage() {
    final buffer = StringBuffer();

    buffer.writeln('Assalamualaikum Warahmatullahi Wabarakatuh');
    buffer.writeln();
    buffer.writeln('Saya : ${_namaController.text.trim()}');
    buffer.writeln('Kota  : ${_selectedDestinationCity?.displayName ?? "-"}');
    buffer.writeln('Telp  : ${_hpController.text.trim()}');
    buffer.writeln();

    // List produk
    buffer.writeln('Memesan :');
    for (final item in _checkoutItems) {
      // Tampilkan variant kalau ada (clone pattern diskusi 8 Agt 2026)
      if (item.hasVariant) {
        // Mis. "• Baju Batik - Merah (2x)"
        buffer.writeln('  • ${item.productName} - ${item.variantName} (${item.quantity}x)');
      } else {
        buffer.writeln('  • ${item.productName} (${item.quantity}x)');
      }
    }
    buffer.writeln();

    // Harga dan ongkir
    buffer.writeln('Harga  : Rp ${_formatNumber(_checkoutSubtotal)}');
    buffer.writeln('Ongkir : Rp ${_formatNumber(_checkoutOngkir)}');
    buffer.writeln('─────────────────');
    buffer.writeln('TOTAL  : Rp ${_formatNumber(_checkoutTotal)}');
    buffer.writeln();

    // Info tambahan
    buffer.writeln('Alamat Pengiriman:');
    buffer.writeln(_alamatController.text.trim());

    return buffer.toString();
  }

  /// Kirim pesan WhatsApp ke penjual
  Future<void> _sendWhatsApp(String sellerWa) async {
    // Normalisasi nomor WA
    String phone = sellerWa.replaceAll(RegExp(r'[^\d+]'), '');

    // Tambahkan kode negara jika belum ada
    if (!phone.startsWith('0') && !phone.startsWith('62')) {
      if (phone.startsWith('+')) {
        phone = phone.substring(1);
      }
    }

    // Ubah 0 di depan menjadi 62
    if (phone.startsWith('0')) {
      phone = '62' + phone.substring(1);
    }

    // Generate pesan
    final message = _generateWhatsAppMessage();
    final encodedMessage = Uri.encodeComponent(message);

    // Buat URL WhatsApp
    final waUrl = 'https://wa.me/$phone?text=$encodedMessage';

    debugPrint('WhatsApp URL: $waUrl');

    try {
      final uri = Uri.parse(waUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka WhatsApp'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Kirim pesan WA ke semua penjual (jika multi-seller)
  Future<void> _sendWhatsAppToAllSellers() async {
    // Ambil unique sellers dari items
    final uniqueSellerWas = <String>{};
    for (final item in _checkoutItems) {
      if (item.sellerWa.isNotEmpty) {
        uniqueSellerWas.add(item.sellerWa);
      }
    }

    if (uniqueSellerWas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor WhatsApp penjual tidak tersedia'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Jika hanya satu penjual, langsung kirim
    if (uniqueSellerWas.length == 1) {
      await _sendWhatsApp(uniqueSellerWas.first);
      return;
    }

    // Jika multiple sellers, kirim satu per satu
    for (final wa in uniqueSellerWas) {
      await _sendWhatsApp(wa);
      // Small delay antar pengiriman
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
}
