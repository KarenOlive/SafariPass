import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class TravelStatsScreen extends StatefulWidget {
  const TravelStatsScreen({super.key});

  @override
  State<TravelStatsScreen> createState() => _TravelStatsScreenState();
}

class _TravelStatsScreenState extends State<TravelStatsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final userId = await DatabaseHelper.instance.getOrCreateDefaultUserId();
    final stats = await DatabaseHelper.instance.getTravelStats(userId);
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOverviewGrid(),
                        const SizedBox(height: 32),
                        _buildSectionHeader('Top Airlines', LucideIcons.plane),
                        const SizedBox(height: 16),
                        _buildAirlinesChart(),
                        const SizedBox(height: 32),
                        _buildSectionHeader('Monthly Trends', LucideIcons.calendar),
                        const SizedBox(height: 16),
                        _buildMonthlyTrends(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF1A2151),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Travel Insights', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2151), Color(0xFF3949AB)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(LucideIcons.globe, size: 200, color: Colors.white.withOpacity(0.05)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Total Trips', _stats?['total_tickets'].toString() ?? '0', LucideIcons.planeTakeoff, Colors.blue),
        _buildStatCard('Destinations', _stats?['unique_destinations'].toString() ?? '0', LucideIcons.mapPin, Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2151))),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1A2151)),
        const SizedBox(height: 8, width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2151))),
      ],
    );
  }

  Widget _buildAirlinesChart() {
    final List<dynamic> carriers = _stats?['carriers'] ?? [];
    if (carriers.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No flight data yet', style: TextStyle(color: Colors.grey)),
      ));
    }

    final int maxCount = carriers.isNotEmpty ? (carriers[0]['count'] as int) : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: carriers.map((c) {
          final double progress = (c['count'] as int) / maxCount;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c['carrier'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${c['count']} flights', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFF27121), Color(0xFFE94057)]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthlyTrends() {
    final List<dynamic> monthly = _stats?['monthly'] ?? [];
    if (monthly.isEmpty) {
      return const Center(child: Text('Add more trips to see trends', style: TextStyle(color: Colors.grey)));
    }

    return Container(
      height: 160,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2151),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: monthly.map((m) {
          final count = m['count'] as int;
          final String monthName = _formatMonth(m['month'] as String);
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 30,
                height: (count * 12).toDouble().clamp(10, 70),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              Text(monthName, style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatMonth(String yyyymm) {
    try {
      final parts = yyyymm.split('-');
      final month = int.parse(parts[1]);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return months[month - 1];
    } catch (e) {
      return yyyymm;
    }
  }
}
