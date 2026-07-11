enum SellerStatus {
  pending,    // Menunggu verifikasi
  approved,   // Disetujui - bisa buka toko
  rejected,   // Ditolak
}

enum OrganizationType {
  muhammadiyah,
  aisyiyah,
  ortom,
}

extension OrganizationTypeExtension on OrganizationType {
  String get displayName {
    switch (this) {
      case OrganizationType.muhammadiyah:
        return 'Muhammadiyah';
      case OrganizationType.aisyiyah:
        return 'Aisyiyah';
      case OrganizationType.ortom:
        return 'ORTOM (Organisasi Otonom)';
    }
  }
}

class UserModel {
  final String username;
  final String namaToko;
  final String namaLengkap;
  final String alamat;
  final String noWa;
  final String daerah;
  final String jabatan;
  final String? jabatanSebagai;

  // New fields for verification
  final String email;
  final String? noTelp;
  final String? organisasi;        // Muhammadiyah / Aisyiyah / ORTOM
  final String? namaOrganisasi;    // PWM, PCA, PW Aisyiyah, dll
  final String? posisi;            // Ketua, Sekretaris, Anggota, dll
  final SellerStatus status;       // pending, approved, rejected
  final String? rejectedReason;    // Alasan penolakan jika ditolak
  final DateTime? registeredAt;
  final DateTime? verifiedAt;
  final String? verifiedBy;       // UID admin yang memverifikasi

  UserModel({
    required this.username,
    required this.namaToko,
    required this.namaLengkap,
    required this.alamat,
    required this.noWa,
    required this.daerah,
    required this.jabatan,
    this.jabatanSebagai,
    required this.email,
    this.noTelp,
    this.organisasi,
    this.namaOrganisasi,
    this.posisi,
    this.status = SellerStatus.pending,
    this.rejectedReason,
    this.registeredAt,
    this.verifiedAt,
    this.verifiedBy,
  });

  String get displayName => namaToko.isNotEmpty ? namaToko : namaLengkap;

  bool get isVerified => status == SellerStatus.approved;
  bool get isPending => status == SellerStatus.pending;
  bool get isRejected => status == SellerStatus.rejected;

  Map<String, dynamic> toJson() => {
        'username': username,
        'namaToko': namaToko,
        'namaLengkap': namaLengkap,
        'alamat': alamat,
        'noWa': noWa,
        'daerah': daerah,
        'jabatan': jabatan,
        'jabatanSebagai': jabatanSebagai,
        'email': email,
        'noTelp': noTelp,
        'organisasi': organisasi,
        'namaOrganisasi': namaOrganisasi,
        'posisi': posisi,
        'status': status.name,
        'rejectedReason': rejectedReason,
        'registeredAt': registeredAt?.toIso8601String(),
        'verifiedAt': verifiedAt?.toIso8601String(),
        'verifiedBy': verifiedBy,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    SellerStatus parseStatus(String? statusStr) {
      if (statusStr == null) return SellerStatus.pending;
      return SellerStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => SellerStatus.pending,
      );
    }

    return UserModel(
      username: json['username'] ?? '',
      namaToko: json['namaToko'] ?? '',
      namaLengkap: json['namaLengkap'] ?? '',
      alamat: json['alamat'] ?? '',
      noWa: json['noWa'] ?? '',
      daerah: json['daerah'] ?? '',
      jabatan: json['jabatan'] ?? '',
      jabatanSebagai: json['jabatanSebagai'],
      email: json['email'] ?? '',
      noTelp: json['noTelp'],
      organisasi: json['organisasi'],
      namaOrganisasi: json['namaOrganisasi'],
      posisi: json['posisi'],
      status: parseStatus(json['status']),
      rejectedReason: json['rejectedReason'],
      registeredAt: json['registeredAt'] != null
          ? DateTime.tryParse(json['registeredAt'])
          : null,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'])
          : null,
      verifiedBy: json['verifiedBy'],
    );
  }

  UserModel copyWith({
    String? username,
    String? namaToko,
    String? namaLengkap,
    String? alamat,
    String? noWa,
    String? daerah,
    String? jabatan,
    String? jabatanSebagai,
    String? email,
    String? noTelp,
    String? organisasi,
    String? namaOrganisasi,
    String? posisi,
    SellerStatus? status,
    String? rejectedReason,
    DateTime? registeredAt,
    DateTime? verifiedAt,
    String? verifiedBy,
  }) {
    return UserModel(
      username: username ?? this.username,
      namaToko: namaToko ?? this.namaToko,
      namaLengkap: namaLengkap ?? this.namaLengkap,
      alamat: alamat ?? this.alamat,
      noWa: noWa ?? this.noWa,
      daerah: daerah ?? this.daerah,
      jabatan: jabatan ?? this.jabatan,
      jabatanSebagai: jabatanSebagai ?? this.jabatanSebagai,
      email: email ?? this.email,
      noTelp: noTelp ?? this.noTelp,
      organisasi: organisasi ?? this.organisasi,
      namaOrganisasi: namaOrganisasi ?? this.namaOrganisasi,
      posisi: posisi ?? this.posisi,
      status: status ?? this.status,
      rejectedReason: rejectedReason ?? this.rejectedReason,
      registeredAt: registeredAt ?? this.registeredAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
    );
  }
}
