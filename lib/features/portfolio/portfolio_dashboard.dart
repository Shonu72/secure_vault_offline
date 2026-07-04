import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_vault_offline/core/theme.dart';
import 'package:secure_vault_offline/core/database/secure_database.dart';
import 'package:secure_vault_offline/features/auth/auth_provider.dart';
import 'package:secure_vault_offline/features/asset_entry/add_asset_page.dart';

class PortfolioDashboard extends ConsumerWidget {
  const PortfolioDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch reactive DB streams from Riverpod
    final holdingsAsync = ref.watch(holdingsStreamProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);

    // Show loading spinner if database is initializing
    if (holdingsAsync.isLoading || transactionsAsync.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final holdingsList = holdingsAsync.value ?? [];
    final txList = transactionsAsync.value ?? [];

    // Calculate aggregated metrics from database records
    double totalBalance = 0.0;
    double investedAmount = 0.0;

    for (final h in holdingsList) {
      totalBalance += h.amountHeld * h.currentNav;
      investedAmount += h.purchaseValue;
    }

    double netProfitLoss = totalBalance - investedAmount;
    double profitLossPercentage = investedAmount > 0 
        ? (netProfitLoss / investedAmount) * 100 
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.surface,
        title: const Text(
          'Portfolio',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.primary),
            onPressed: () {
              ref.read(lockScreenProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: holdingsList.isEmpty && txList.isEmpty
          ? _buildEmptyState(context)
          : CustomScrollView(
              slivers: [
                // Total Balance Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL BALANCE',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '\$${totalBalance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  netProfitLoss >= 0
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  color: netProfitLoss >= 0 ? AppColors.primary : AppColors.borderError,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${netProfitLoss >= 0 ? "+" : ""}\$${netProfitLoss.abs().toStringAsFixed(2)} (${profitLossPercentage.toStringAsFixed(2)}%)',
                                  style: TextStyle(
                                    color: netProfitLoss >= 0 ? AppColors.primary : AppColors.borderError,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Annualized Return (XIRR) Info Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Annualized Return (XIRR)',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        netProfitLoss >= 0
                                            ? Icons.trending_up_rounded
                                            : Icons.trending_down_rounded,
                                        color: netProfitLoss >= 0 ? AppColors.primary : AppColors.borderError,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${profitLossPercentage.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          color: netProfitLoss >= 0 ? AppColors.primary : AppColors.borderError,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildDetailColumn('Total Value', '\$${totalBalance.toStringAsFixed(2)}'),
                                Container(
                                  height: 30,
                                  width: 1,
                                  color: AppColors.borderNormal,
                                ),
                                _buildDetailColumn('Invested Amount', '\$${investedAmount.toStringAsFixed(2)}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Section Title
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(left: 20.0, top: 28.0, bottom: 16.0),
                    child: Text(
                      'Recent Transactions',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Transactions List (using SliverList for performance)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tx = txList[index];
                        final isBuy = tx.transactionType == 'buy';
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.borderNormal,
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Custom branded circle icon matching asset type
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _getAssetColor(tx.holdingId, holdingsList).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getAssetIcon(tx.holdingId, holdingsList),
                                    color: _getAssetColor(tx.holdingId, holdingsList),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Transaction Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${isBuy ? "Bought" : "Sold"} ${_getAssetName(tx.holdingId, holdingsList)}',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTimestamp(tx.timestamp),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Amounts
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isBuy ? "+" : "-"} ${tx.amount.toStringAsFixed(4)}',
                                      style: TextStyle(
                                        color: isBuy ? AppColors.primary : AppColors.borderError,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${(tx.amount * tx.price).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: txList.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(canvasColor: AppColors.background),
        child: BottomNavigationBar(
          currentIndex: 1, // 'Portfolio' active
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 22),
              activeIcon: Icon(Icons.home, size: 22),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline_outlined, size: 22),
              activeIcon: Icon(Icons.pie_chart, size: 22),
              label: 'Portfolio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up_outlined, size: 22),
              activeIcon: Icon(Icons.trending_up, size: 22),
              label: 'Trade',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timeline_outlined, size: 22),
              activeIcon: Icon(Icons.timeline, size: 22),
              label: 'Activity',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 22),
              activeIcon: Icon(Icons.person, size: 22),
              label: 'Profile',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddAssetPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderNormal, width: 1.5),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                color: AppColors.textSecondary,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Assets Added Yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your secure offline holdings will appear here once added.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 160,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddAssetPage()),
                  );
                },
                child: const Text('Add First Asset'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Helper resolvers to read dynamic assets details from list mappings

  String _getAssetName(String holdingId, List<HoldingEntity> holdings) {
    final match = holdings.firstWhere((h) => h.id == holdingId, 
        orElse: () => HoldingEntity(
          id: '', assetName: 'Asset', assetSymbol: '', amountHeld: 0, 
          purchaseValue: 0, currentNav: 0, lastUpdatedAt: 0
        ));
    return match.assetName;
  }

  IconData _getAssetIcon(String holdingId, List<HoldingEntity> holdings) {
    final match = holdings.firstWhere((h) => h.id == holdingId, orElse: () => HoldingEntity(
          id: '', assetName: '', assetSymbol: '', amountHeld: 0, 
          purchaseValue: 0, currentNav: 0, lastUpdatedAt: 0
        ));
    final symbol = match.assetSymbol.toLowerCase();
    if (symbol.contains('btc')) return Icons.currency_bitcoin_rounded;
    if (symbol.contains('eth')) return Icons.currency_exchange_rounded;
    return Icons.show_chart_rounded;
  }

  Color _getAssetColor(String holdingId, List<HoldingEntity> holdings) {
    final match = holdings.firstWhere((h) => h.id == holdingId, orElse: () => HoldingEntity(
          id: '', assetName: '', assetSymbol: '', amountHeld: 0, 
          purchaseValue: 0, currentNav: 0, lastUpdatedAt: 0
        ));
    final symbol = match.assetSymbol.toLowerCase();
    if (symbol.contains('btc')) return const Color(0xFFF7931A);
    if (symbol.contains('eth')) return const Color(0xFF627EEA);
    return AppColors.primary;
  }

  String _formatTimestamp(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[date.month - 1];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour == 0 ? 12 : date.hour;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month ${date.day}, ${date.year}, $hour:$minute $ampm';
  }
}
