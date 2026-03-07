// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../services/receipt_service.dart';

class SavedReceiptsScreen extends StatefulWidget {
  const SavedReceiptsScreen({super.key});

  @override
  State<SavedReceiptsScreen> createState() => _SavedReceiptsScreenState();
}

class _SavedReceiptsScreenState extends State<SavedReceiptsScreen> {
  final _receiptService = ReceiptService();
  List<File> _files = [];
  bool _loading = true;
  String _dirPath = '';

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    final files = await _receiptService.listReceiptFiles();
    final path  = await _receiptService.getReceiptsDirPath();
    if (mounted) setState(() { _files = files; _dirPath = path; _loading = false; });
  }

  Future<void> _delete(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Receipt?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('This cannot be undone.', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _receiptService.deleteFile(file);
      _loadFiles();
    }
  }

  Future<void> _share(File file) async {
    await _receiptService.shareReceipt(file);
  }

  Future<void> _reprintWifi(File file) async {
    try {
      await _receiptService.reprintWifi(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: Text('Saved Receipts',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            tooltip: 'Refresh',
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: Column(
        children: [
          // Path banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.primarySurface,
            child: Row(children: [
              const Icon(LucideIcons.folderOpen, size: 15, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dirPath.isEmpty ? 'Loading…' : _dirPath,
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _files.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _loadFiles,
                        color: AppTheme.primaryColor,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _files.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _receiptTile(_files[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _receiptTile(File file) {
    final name = file.path.split('/').last.split('\\').last;
    final stat = file.statSync();
    final date = DateFormat('dd MMM yyyy  HH:mm').format(stat.modified);
    final sizeKb = (stat.size / 1024).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(10)),
          child: const Icon(LucideIcons.fileText, color: AppTheme.primaryColor, size: 22),
        ),
        title: Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        subtitle: Text('$date  ·  $sizeKb KB', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
        trailing: PopupMenuButton<String>(
          icon: const Icon(LucideIcons.moreVertical, size: 18, color: AppTheme.textSecondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (action) {
            switch (action) {
              case 'share':  _share(file);       break;
              case 'print':  _reprintWifi(file); break;
              case 'delete': _delete(file);      break;
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'share',  child: _menuItem(LucideIcons.share2, 'Share / Open')),
            PopupMenuItem(value: 'print',  child: _menuItem(LucideIcons.printer, 'Print (WiFi)')),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'delete', child: _menuItem(LucideIcons.trash2, 'Delete', color: AppTheme.error)),
          ],
        ),
        onTap: () => _share(file),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, {Color? color}) {
    return Row(children: [
      Icon(icon, size: 16, color: color ?? AppTheme.textSecondary),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.inter(fontSize: 14, color: color ?? AppTheme.textPrimary)),
    ]);
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(LucideIcons.inbox, size: 56, color: AppTheme.borderMedium),
        const SizedBox(height: 16),
        Text('No receipts saved yet', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Text('Receipts are saved automatically when you process a payment.', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary), textAlign: TextAlign.center),
      ]),
    );
  }
}
