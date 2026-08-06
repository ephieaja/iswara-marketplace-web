/// Helper untuk ownership & role check di Marketplace.
/// Clone pattern dari iswara_app `admin_wilayah_dashboard_screen.dart`
/// `_isSuperAdmin` dan `_canModify` logic (commit e9cd539 RBAC, 96f86ff popup).

library;

import 'package:pocketbase/pocketbase.dart';

/// Normalisasi nomor WA: hapus karakter non-digit, awalan 0 -> 62.
String normalizePhone(String phone) {
  var cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
  if (cleaned.startsWith('0')) {
    cleaned = '62${cleaned.substring(1)}';
  }
  return cleaned;
}

/// Apakah user yang login punya role super_admin?
/// Baca dari `users.is_super_admin` field di PB.
/// Field ini akan ditambahkan di Tahap 2 schema marketplace.
bool isSuperAdmin(RecordModel? currentUser) {
  if (currentUser == null) return false;
  final v = currentUser.data['is_super_admin'];
  return v == true;
}

/// Apakah user `currentNowa` adalah owner dari record ini?
/// Cek `created_by_nowa` dulu, fallback ke `created_by` (id).
/// Mirip logika iswara_app admin_wilayah_dashboard_screen.dart line 63-70.
bool isOwnerOf(RecordModel record, String currentNowa, {String? currentUserId}) {
  final createdByNowa = record.data['created_by_nowa']?.toString();
  if (createdByNowa != null && createdByNowa.isNotEmpty) {
    return normalizePhone(createdByNowa) == normalizePhone(currentNowa);
  }
  final createdBy = record.data['created_by']?.toString() ?? '';
  if (currentUserId != null && createdBy.isNotEmpty) {
    return createdBy == currentUserId;
  }
  return false;
}

/// Apakah user boleh modify (edit/hapus) record ini?
/// Aturan:
/// - Super admin: boleh modify SEMUA record
/// - Non-super-admin: hanya record yang dia create sendiri
/// Ini pola yang sama dengan iswara_app `_canModify` di
/// admin_wilayah_dashboard_screen.dart line 160-163.
bool canModify(RecordModel record, RecordModel? currentUser, String currentNowa) {
  if (isSuperAdmin(currentUser)) return true;
  final currentUserId = currentUser?.id;
  return isOwnerOf(record, currentNowa, currentUserId: currentUserId);
}

/// Apakah aksi ini adalah self-registration?
/// Misal admin seller mendaftarkan seller lain dengan nomor WA-nya sendiri.
/// Pakai pola iswara_app `isSelfRegistration` di admin_wilayah_dashboard_screen.dart
/// line 1063-1064. Di marketplace, kasus ini bisa terjadi kalau admin_pendaftaran
/// mendaftarkan diri sendiri jadi seller.
bool isSelfRegistration(String actorNowa, String targetNowa) {
  return normalizePhone(actorNowa) == normalizePhone(targetNowa);
}
