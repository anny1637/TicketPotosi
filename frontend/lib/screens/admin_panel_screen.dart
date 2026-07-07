import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../main.dart' show AppColors;
import 'admin/admin_events_screen.dart';
import 'admin/admin_users_screen.dart';
import 'admin/admin_promotions_screen.dart';
import 'admin/admin_reports_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _userPhoto = '';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final photo = prefs.getString('user_photo') ?? '';
      final data = await ApiService.getDashboard();
      if (mounted) {
        setState(() {
          _userPhoto = photo;
          _stats = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF0294E3).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0294E3), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildAdminAvatarImage(),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Panel Admin',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualizar',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(Icons.analytics_rounded, 'Resumen General'),
                        const SizedBox(height: 8),

                        // Tarjetas de estadísticas
                        _buildStatsGrid(),
                        const SizedBox(height: 20),

                        // Gráfico de ventas
                        _buildSalesChart(),
                        const SizedBox(height: 24),

                        _buildSectionHeader(Icons.handyman_rounded, 'Gestión del Sistema'),
                        const SizedBox(height: 8),
                        _buildManagementGrid(),
                        const SizedBox(height: 24),

                        // Eventos recientes
                        if (_stats['recent_events'] != null &&
                            (_stats['recent_events'] as List).isNotEmpty) ...[
                          _buildSectionHeader(Icons.confirmation_number_rounded, 'Eventos Recientes'),
                          const SizedBox(height: 8),
                          _buildRecentEvents(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {
        'label': 'Tickets Vendidos',
        'value': '${_stats['total_tickets_sold'] ?? _stats['total_tickets'] ?? 0}',
        'icon': Icons.confirmation_number_rounded,
        'iconColor': const Color(0xFF0294E3),
        'iconBg': const Color(0xFF13233C),
      },
      {
        'label': 'Tickets Usados',
        'value': '${_stats['used_tickets'] ?? 0}',
        'icon': Icons.check_circle_rounded,
        'iconColor': const Color(0xFF00C853),
        'iconBg': const Color(0xFF132D2F),
      },
      {
        'label': 'Eventos Activos',
        'value': '${_stats['total_events'] ?? 0}',
        'icon': Icons.calendar_month_rounded,
        'iconColor': const Color(0xFFFFB300),
        'iconBg': const Color(0xFF2C241E),
      },
      {
        'label': 'Usuarios Registrados',
        'value': '${_stats['total_users'] ?? 0}',
        'icon': Icons.people_rounded,
        'iconColor': const Color(0xFF00B0FF),
        'iconBg': const Color(0xFF13233C),
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: stats.map((s) {
        final iconColor = s['iconColor'] as Color;
        final iconBg = s['iconBg'] as Color;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(s['icon'] as IconData, color: iconColor, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['value'] as String,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s['label'] as String,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildManagementGrid() {
    final options = [
      {
        'label': 'Eventos',
        'subtitle': 'Crear, editar, eliminar',
        'icon': Icons.calendar_today_rounded,
        'borderColor': const Color(0xFF0294E3),
        'iconColor': const Color(0xFF0294E3),
        'screen': const AdminEventsScreen(),
      },
      {
        'label': 'Usuarios',
        'subtitle': 'Gestionar cuentas',
        'icon': Icons.people_rounded,
        'borderColor': const Color(0xFF00B0FF),
        'iconColor': const Color(0xFF00B0FF),
        'screen': const AdminUsersScreen(),
      },
      {
        'label': 'Promociones',
        'subtitle': 'Descuentos y ofertas',
        'icon': Icons.local_offer_rounded,
        'borderColor': const Color(0xFFFFB300),
        'iconColor': const Color(0xFFFFB300),
        'screen': const AdminPromotionsScreen(),
      },
      {
        'label': 'Reportes',
        'subtitle': 'Ventas y asistencia',
        'icon': Icons.bar_chart_rounded,
        'borderColor': const Color(0xFF00E676),
        'iconColor': const Color(0xFF00E676),
        'screen': const AdminReportsScreen(),
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: options.map((opt) {
        final borderColor = opt['borderColor'] as Color;
        final iconColor = opt['iconColor'] as Color;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => opt['screen'] as Widget),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(opt['icon'] as IconData, color: iconColor, size: 28),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opt['label'] as String,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(opt['subtitle'] as String,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0294E3), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEvents() {
    final events = (_stats['recent_events'] as List?) ?? [];
    return Column(
      children: events.map((event) {
        final sold = event['tickets_sold'] ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'] ?? 'Evento',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${event['location'] ?? ''} · $sold tickets vendidos',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$sold',
                  style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSalesChart() {
    final salesData = _stats['sales_by_day'] as List? ?? [];
    if (salesData.isEmpty) return const SizedBox.shrink();

    List<BarChartGroupData> barGroups = [];
    double maxVal = 5.0;

    for (int i = 0; i < salesData.length; i++) {
      final item = salesData[i];
      final double val = double.tryParse(item['total']?.toString() ?? '0') ?? 0.0;
      if (val > maxVal) {
        maxVal = val;
      }
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: const Color(0xFF0294E3),
              width: 14,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxVal + 1,
                color: const Color(0xFF132038),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: Color(0xFF0294E3), size: 20),
              SizedBox(width: 8),
              Text(
                'Ventas de Entradas (Últimos 7 días)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal + 1,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => AppColors.surface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final date = salesData[group.x]['date'] ?? '';
                      final shortDate = date.length > 5 ? date.substring(date.length - 5) : date;
                      return BarTooltipItem(
                        '$shortDate\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toInt()} tickets',
                            style: const TextStyle(color: Color(0xFF0294E3), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < salesData.length) {
                          final dateStr = salesData[index]['date']?.toString() ?? '';
                          final shortDate = dateStr.length > 5 ? dateStr.substring(dateStr.length - 5) : dateStr;
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              shortDate,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            '${value.toInt()}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                          ),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.cardBorder.withOpacity(0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAvatarImage() {
    if (kIsWeb) {
      if (_userPhoto.isNotEmpty) {
        return Image.network(
          _userPhoto == 'local_mock_photo.png'
              ? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=250&q=80'
              : _userPhoto,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultIcon(),
        );
      }
      return _buildDefaultIcon();
    }

    if (_userPhoto.isNotEmpty) {
      final file = io.File(_userPhoto);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
      return FutureBuilder<String>(
        future: ApiService.getBaseUrl(),
        builder: (context, snap) {
          if (!snap.hasData) return _buildDefaultIcon();
          final baseUrl = snap.data!.replaceAll('/api', '');
          final fullUrl = _userPhoto == 'local_mock_photo.png'
              ? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=250&q=80'
              : '$baseUrl/storage/$_userPhoto';
          return Image.network(
            fullUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDefaultIcon(),
          );
        },
      );
    }
    return _buildDefaultIcon();
  }

  Widget _buildDefaultIcon() {
    return const Icon(Icons.admin_panel_settings_rounded,
        color: Color(0xFF0294E3), size: 18);
  }
}
