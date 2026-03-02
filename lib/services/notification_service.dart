import 'package:intl/intl.dart';
import '../models/app_notification.dart';
import 'firestore_service.dart';

/// Checks business conditions and generates in-app notifications.
///
/// Call [checkAndGenerate] when the app opens (dashboard) to create relevant
/// alerts.  Each notification type is created at most once per calendar day so
/// the user never sees duplicates.
class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirestoreService _db = FirestoreService();

  /// Master check — runs every enabled check for the shop's business type.
  Future<void> checkAndGenerate(String shopId) async {
    if (shopId.isEmpty) return;
    try {
      final prefs = await _db.getNotificationPreferences(shopId);
      final config = await _db.getBusinessConfig(shopId);
      final now = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(now);

      // Pull recent notifications to de-duplicate (same type + same day ⇒ skip)
      final recent = await _db.getNotifications(shopId, limit: 40);
      final todayTypes = recent
          .where((n) => DateFormat('yyyy-MM-dd').format(n.createdAt) == todayKey)
          .map((n) => n.type)
          .toSet();

      bool skip(String type) => todayTypes.contains(type);

      // ────────────────────────────────────────────────────────
      // COMMON:  Daily Sales Summary (recap of *yesterday*)
      // ────────────────────────────────────────────────────────
      if (prefs['dailySalesSummary'] == true && !skip('daily_summary')) {
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        final yesterdayEnd = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(seconds: 1));
        final sales = await _db.getSalesInRange(shopId, yesterday, yesterdayEnd);
        if (sales.isNotEmpty) {
          final revenue = sales.fold(0.0, (s, e) => s + e.totalAmount);
          final label = config.hasJobCards ? 'job(s)' : 'order(s)';
          await _db.createNotification(
            shopId,
            AppNotification(
              type: 'daily_summary',
              title: "Yesterday's Sales Summary",
              body:
                  '${sales.length} $label totalling Rs. ${NumberFormat('#,###').format(revenue.toInt())}.',
              createdAt: now,
            ),
          );
        }
      }

      // ────────────────────────────────────────────────────────
      // STOCK:  Low Stock Alert  (Retail, Pharmacy)
      // ────────────────────────────────────────────────────────
      if (prefs['lowStockAlerts'] == true &&
          config.hasStockManagement &&
          !skip('low_stock')) {
        final lowStock = await _db.getLowStockProducts(shopId, threshold: 10);
        if (lowStock.isNotEmpty) {
          final out = lowStock.where((p) => p.stock <= 0).length;
          await _db.createNotification(
            shopId,
            AppNotification(
              type: 'low_stock',
              title: 'Low Stock Alert',
              body:
                  '${lowStock.length} ${config.salesItemLabel.toLowerCase()}(s) running low'
                  '${out > 0 ? ', $out out of stock' : ''}. Review your inventory.',
              createdAt: now,
            ),
          );
        }
      }

      // ────────────────────────────────────────────────────────
      // STOCK:  Restock Reminder  (Retail) — weekly on Mondays
      // ────────────────────────────────────────────────────────
      if (prefs['restockReminder'] == true &&
          config.hasStockManagement &&
          !config.hasExpiryTracking && // pharmacy has its own
          now.weekday == DateTime.monday &&
          !skip('restock_reminder')) {
        await _db.createNotification(
          shopId,
          AppNotification(
            type: 'restock_reminder',
            title: 'Weekly Restock Reminder',
            body:
                "It's Monday! Review your inventory and reorder "
                '${config.salesItemLabel.toLowerCase()}s that are running low.',
            createdAt: now,
          ),
        );
      }

      // ────────────────────────────────────────────────────────
      // PHARMACY:  Expiring Medicine Alert  (≤ 30 days)
      // ────────────────────────────────────────────────────────
      if (prefs['expiringMedicineAlert'] == true &&
          config.hasExpiryTracking &&
          !skip('expiring_stock')) {
        final expiring = await _db.getExpiringProducts(shopId, days: 30);
        if (expiring.isNotEmpty) {
          final alreadyExpired = expiring
              .where((p) =>
                  p.expiryDate != null && p.expiryDate!.isBefore(now))
              .length;
          await _db.createNotification(
            shopId,
            AppNotification(
              type: 'expiring_stock',
              title: 'Expiring Medicine Alert',
              body:
                  '${expiring.length} medicine(s) expiring within 30 days'
                  '${alreadyExpired > 0 ? '. $alreadyExpired already expired!' : '.'}',
              createdAt: now,
            ),
          );
        }
      }

      // ────────────────────────────────────────────────────────
      // PHARMACY:  Expired Stock Alert
      // ────────────────────────────────────────────────────────
      if (prefs['expiredStockAlert'] == true &&
          config.hasExpiryTracking &&
          !skip('expired_stock')) {
        final allExpiring = await _db.getExpiringProducts(shopId, days: 0);
        // Filter to only truly expired ones
        final expired =
            allExpiring.where((p) => p.expiryDate != null && p.expiryDate!.isBefore(now)).toList();
        if (expired.isNotEmpty) {
          await _db.createNotification(
            shopId,
            AppNotification(
              type: 'expired_stock',
              title: 'Expired Stock Found',
              body:
                  '${expired.length} medicine(s) have already expired. '
                  'Remove them from your inventory immediately.',
              createdAt: now,
            ),
          );
        }
      }

      // ────────────────────────────────────────────────────────
      // PHARMACY:  New Product Reminder — weekly on Mondays
      // ────────────────────────────────────────────────────────
      if (prefs['newProductReminder'] == true &&
          config.hasExpiryTracking &&
          now.weekday == DateTime.monday &&
          !skip('new_product_reminder')) {
        await _db.createNotification(
          shopId,
          AppNotification(
            type: 'new_product_reminder',
            title: 'New Medicine Reminder',
            body:
                "Have you received any new medicines this week? "
                "Don't forget to add them to your inventory.",
            createdAt: now,
          ),
        );
      }

      // ────────────────────────────────────────────────────────
      // RESTAURANT:  Daily Menu Reminder
      // ────────────────────────────────────────────────────────
      if (prefs['dailyMenuReminder'] == true &&
          config.hasDineInTakeaway &&
          !skip('daily_menu_reminder')) {
        await _db.createNotification(
          shopId,
          AppNotification(
            type: 'daily_menu_reminder',
            title: 'Daily Menu Reminder',
            body:
                "Good morning! Have you updated today's specials "
                'or marked any unavailable items?',
            createdAt: now,
          ),
        );
      }

      // ────────────────────────────────────────────────────────
      // REPAIR:  Pending Jobs Reminder
      // ────────────────────────────────────────────────────────
      if (prefs['pendingJobsReminder'] == true &&
          config.hasJobCards &&
          !skip('pending_jobs')) {
        final start = DateTime(now.year, now.month - 1, now.day);
        final counts = await _db.getJobStatusCounts(shopId, start, now);
        final pending = counts['pending'] ?? 0;
        if (pending > 0) {
          await _db.createNotification(
            shopId,
            AppNotification(
              type: 'pending_jobs',
              title: 'Pending Jobs Reminder',
              body: 'You have $pending pending job(s) awaiting attention.',
              createdAt: now,
            ),
          );
        }
      }

      // ────────────────────────────────────────────────────────
      // REPAIR:  Overdue Jobs Alert  (pending > 3 days)
      // ────────────────────────────────────────────────────────
      if (prefs['overdueJobsAlert'] == true &&
          config.hasJobCards &&
          !skip('overdue_jobs')) {
        final cutoff = now.subtract(const Duration(days: 3));
        final oldSales =
            await _db.getSalesInRange(shopId, DateTime(now.year - 1), cutoff);
        final overdue = oldSales
            .where((s) => s.jobStatus == 'pending' || s.jobStatus.isEmpty)
            .length;
        if (overdue > 0) {
          await _db.createNotification(
            shopId,
            AppNotification(
              type: 'overdue_jobs',
              title: 'Overdue Jobs Alert',
              body:
                  '$overdue job(s) have been pending for more than 3 days. '
                  'Check on them.',
              createdAt: now,
            ),
          );
        }
      }
    } catch (e) {
      // Notifications are non-critical; fail silently.
      // ignore: avoid_print
      print('NotificationService.checkAndGenerate error: $e');
    }
  }
}
