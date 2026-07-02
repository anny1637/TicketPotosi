import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../main.dart' show AppColors;

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedEventReport;
  bool _isLoadingReport = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getGeneralReport();
      if (mounted) setState(() { _events = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEventReport(int eventId) async {
    setState(() => _isLoadingReport = true);
    try {
      final data = await ApiService.getEventReport(eventId);
      if (mounted) setState(() { _selectedEventReport = data; _isLoadingReport = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Reportes',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (_selectedEventReport != null) {
              setState(() => _selectedEventReport = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            onPressed: _loadReport,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _selectedEventReport != null
              ? _buildEventReport()
              : _buildGeneralReport(),
    );
  }

  Widget _buildGeneralReport() {
    // Total general
    final totalSold = _events.fold<int>(0,
        (sum, e) => sum + ((e['tickets_sold'] ?? 0) as int));
    final totalRevenue = _events.fold<double>(0,
        (sum, e) => sum + ((e['revenue'] ?? 0) as num).toDouble());

    return Column(
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('$totalSold',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    Text('Tickets Vendidos',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
              Expanded(
                child: Column(
                  children: [
                    Text('Bs. ${totalRevenue.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    Text('Ingresos Totales',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Lista de eventos
        Expanded(
          child: _events.isEmpty
              ? Center(
                  child: Text('No hay datos',
                      style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _events.length,
                  itemBuilder: (ctx, i) {
                    final e = _events[i] as Map<String, dynamic>;
                    final sold    = (e['tickets_sold'] ?? 0) as int;
                    final used    = (e['tickets_used'] ?? 0) as int;
                    final revenue = ((e['revenue'] ?? 0) as num).toDouble();

                    return GestureDetector(
                      onTap: () => _loadEventReport(e['id']),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(e['title'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppColors.textMuted),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _statChip('Vendidos', '$sold', AppColors.primary),
                                const SizedBox(width: 8),
                                _statChip('Usados', '$used', AppColors.success),
                                const SizedBox(width: 8),
                                _statChip('Ingresos',
                                    'Bs ${revenue.toStringAsFixed(0)}', AppColors.warning),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEventReport() {
    if (_isLoadingReport) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final report  = _selectedEventReport!;
    final summary = report['summary'] as Map<String, dynamic>? ?? {};
    final tickets = (report['tickets'] as List?) ?? [];
    final event   = report['event'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        // Título evento
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Text(event['title'] ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryItem('Vendidos',
                      '${summary['total_sold'] ?? 0}', AppColors.primary),
                  _summaryItem('Usados',
                      '${summary['total_used'] ?? 0}', AppColors.success),
                  _summaryItem('Ingresos',
                      'Bs ${((summary['total_revenue'] ?? 0) as num).toStringAsFixed(2)}',
                      AppColors.warning),
                ],
              ),
            ],
          ),
        ),

        // Lista de tickets
        Expanded(
          child: tickets.isEmpty
              ? Center(
                  child: Text('No hay tickets vendidos',
                      style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: tickets.length,
                  itemBuilder: (ctx, i) {
                    final t    = tickets[i] as Map<String, dynamic>;
                    final used = t['status'] == 'used';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            used
                                ? Icons.check_circle_rounded
                                : Icons.confirmation_number_rounded,
                            color: used ? AppColors.success : AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t['user']?['name'] ?? 'Sin nombre',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                Text(
                                  '${t['ticket_type']?['name'] ?? ''} · ${t['ticket_code'] ?? ''}',
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (used ? AppColors.success : AppColors.primary)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              used ? 'Usado' : 'Pagado',
                              style: TextStyle(
                                  color: used ? AppColors.success : AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label,
                style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}
