import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_vault_offline/core/theme.dart';
import 'package:secure_vault_offline/features/auth/auth_provider.dart';
import 'package:secure_vault_offline/features/asset_entry/add_asset_page.dart';

class TransactionItem {
  final String title;
  final String subtitle;
  final String amount;
  final String value;
  final IconData icon;
  final Color iconBgColor;
  final bool isPositive;

  const TransactionItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.value,
    required this.icon,
    required this.iconBgColor,
    required this.isPositive,
  });
}

class PortfolioDashboard extends ConsumerWidget {
  const PortfolioDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock list of transactions exactly matching the design screen
    final transactions = [
      const TransactionItem(
        title: 'Bought Bitcoin',
        subtitle: 'Nov 14, 2023, 10:32 AM',
        amount: '+ 0.0051 BTC',
        value: '+\$198.50',
        icon: Icons.currency_bitcoin_rounded,
        iconBgColor: Color(0xFFF7931A),
        isPositive: true,
      ),
      const TransactionItem(
        title: 'Sold Apple',
        subtitle: 'Nov 14, 2023, 09:15 AM',
        amount: '- 15 Shares',
        value: '-\$2,640.75',
        icon: Icons.apple_rounded,
        iconBgColor: Color(0xFFFFFFFF),
        isPositive: false,
      ),
      const TransactionItem(
        title: 'Bought Tesla',
        subtitle: 'Nov 13, 2023, 02:48 PM',
        amount: '+ 8 Shares',
        value: '+\$1,980.10',
        icon: Icons.electric_car_rounded,
        iconBgColor: Color(0xFFE82127),
        isPositive: true,
      ),
      const TransactionItem(
        title: 'Received ETH',
        subtitle: 'Nov 13, 2023, 11:05 AM',
        amount: '+ 0.124 ETH',
        value: '+\$255.60',
        icon: Icons.currency_exchange_rounded,
        iconBgColor: Color(0xFF627EEA),
        isPositive: true,
      ),
    ];

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
      body: CustomScrollView(
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
                      const Text(
                        '\$284,750.80',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.arrow_upward_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '\$3,210.45 (+1.15%) Today',
                            style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.9),
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
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.trending_up_rounded,
                                  color: AppColors.primary,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '+12.4%',
                                  style: TextStyle(
                                    color: AppColors.primary,
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
                          _buildDetailColumn('Total Value', '\$284,750.80'),
                          Container(
                            height: 30,
                            width: 1,
                            color: AppColors.borderNormal,
                          ),
                          _buildDetailColumn('Invested Amount', '\$289,750.80'),
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
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = transactions[index];
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
                        // Custom branded circle icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: item.iconBgColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.icon,
                            color: item.iconBgColor == const Color(0xFFFFFFFF)
                                ? AppColors.textPrimary
                                : item.iconBgColor,
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
                                item.title,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
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
                              item.amount,
                              style: TextStyle(
                                color: item.isPositive
                                    ? AppColors.primary
                                    : AppColors.borderError,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.value,
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
              }, childCount: transactions.length),
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
}
