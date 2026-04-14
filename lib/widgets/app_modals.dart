import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

class AppModals {
  /// Standard modern bottom sheet with a drag handle and stacking buttons.
  static Future<T?> showAppBottomSheet<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    Widget? primaryAction,
    Widget? secondaryAction,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.borderLight),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: child,
              ),
            ),
            
            // Stacked Actions
            if (primaryAction != null || secondaryAction != null)
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.borderLight)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    if (primaryAction != null) SizedBox(width: double.infinity, child: primaryAction),
                    if (secondaryAction != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: secondaryAction),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Standard modern centered dialog with stacking buttons.
  static Future<T?> showAppDialog<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    Widget? primaryAction,
    Widget? secondaryAction,
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: child,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actionsOverflowButtonSpacing: 12,
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actions: [
          if (primaryAction != null) SizedBox(width: double.infinity, child: primaryAction),
          if (secondaryAction != null) SizedBox(width: double.infinity, child: secondaryAction),
        ],
      ),
    );
  }
}
