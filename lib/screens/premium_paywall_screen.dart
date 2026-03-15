import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import '../services/premium_service.dart';

class PremiumPaywallScreen extends StatefulWidget {
  final VoidCallback? onPremiumUnlocked;

  const PremiumPaywallScreen({super.key, this.onPremiumUnlocked});

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  final PremiumService _premiumService = PremiumService();

  @override
  void initState() {
    super.initState();
    _premiumService.addListener(_onPremiumStateChanged);
  }

  @override
  void dispose() {
    _premiumService.removeListener(_onPremiumStateChanged);
    super.dispose();
  }

  void _onPremiumStateChanged() {
    if (_premiumService.isPremium) {
      if (mounted) {
        widget.onPremiumUnlocked?.call();
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.crown,
                    size: 80,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Upgrade to Premium',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Unlock pro features for your business with a one-time payment. No subscriptions.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Feature List
                _buildFeatureRow(
                  LucideIcons.printer,
                  'Thermal Receipt Printing',
                  'Connect to Bluetooth & WiFi thermal printers and automatically print sleek thermal receipts for customers.',
                ),
                const SizedBox(height: 24),
                _buildFeatureRow(
                  LucideIcons.barChart2,
                  'Advanced Analytics',
                  'Gain deep insights into your revenue, growth, and best-selling products through interactive visual charts.',
                ),
                const SizedBox(height: 24),
                _buildFeatureRow(
                  LucideIcons.download,
                  'Data Export & Reporting',
                  'Export detailed monthly sales reports to professional PDF or Excel files to share with your accountant.',
                ),
                const SizedBox(height: 48),

                // Pricing / Checkout Button
                ListenableBuilder(
                  listenable: _premiumService,
                  builder: (context, child) {
                    if (_premiumService.purchasePending) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryColor),
                      );
                    }

                    if (_premiumService.error != null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _premiumService.error ?? '',
                          style: GoogleFonts.inter(color: AppTheme.error, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (_premiumService.products.isEmpty) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: null,
                        child: Text(
                          'Loading price...',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      );
                    }

                    final product = _premiumService.products.first;

                    return Column(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: AppTheme.primaryColor.withOpacity(0.5),
                          ),
                          onPressed: () {
                            _premiumService.buyPremium();
                          },
                          child: Text(
                            'Unlock for \$${product.price}',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            _premiumService.restorePurchases();
                          },
                          child: Text(
                            'Restore Purchases',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
