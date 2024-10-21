// lib/pages/dashboard/dashboard.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../components/sidebar.dart';
import 'widgets/summary_cards.dart';
import 'widgets/revenue_realtime_percentage.dart';
import 'widgets/post_status.dart';
import 'widgets/revenue_by_locations.dart';
import 'widgets/combined_widget.dart';
import 'widgets/traffic_hours.dart';
import '../../components/responsive.dart';


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Timer _timer;
  late DateTime _currentTime;
  bool _localeInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeLocale();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('id_ID', null);
    setState(() {
      _localeInitialized = true;
      _currentTime = DateTime.now();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    final dayFormat = DateFormat('EEEE', 'id_ID');
    final dateFormat = DateFormat('d MMMM y', 'id_ID');
    final timeFormat = DateFormat('HH:mm:ss');

    return '${dayFormat.format(dateTime)}, ${dateFormat.format(dateTime)} - ${timeFormat.format(dateTime)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Halaman Utama',
          style: TextStyle(
            fontSize: Responsive.getFontSize(
              context,
              mobile: 12,
              tablet: 20,
              desktop: 20, // adjust sesuai kebutuhan
            ),
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: _localeInitialized
                  ? Text(
                      _formatDateTime(_currentTime),
                      style: TextStyle(
                        fontSize: Responsive.getFontSize(
                          context,
                          mobile: 12,
                          tablet: 14,
                          desktop: 20,
                        ),
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ],
      ),
      drawer: const Sidebar(),
      body: _localeInitialized
          ? SingleChildScrollView(
              child: Padding(
                padding: Responsive.getPadding(context),
                child: Column(
                  children: [
                    _buildSummaryCardsGrid(context),
                    SizedBox(height: Responsive.isMobile(context) ? 8 : 16),
                    _buildMainContent(context),
                  ],
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSummaryCardsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = Responsive.getGridColumns(context);
        double childAspectRatio = Responsive.getAspectRatio(context);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          mainAxisSpacing: Responsive.isMobile(context) ? 8.0 : 16.0,
          crossAxisSpacing: Responsive.isMobile(context) ? 8.0 : 16.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: _buildSummaryCards(),
        );
      },
    );
  }

  Widget _buildMainContent(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: 300,
                  child: RevenueRealtimePercentage(),
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: SizedBox(
                  height: 300,
                  child: PostStatus(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const RevenueByLocations(),
          const SizedBox(height: 16),
          const TrafficHours(),
          const SizedBox(height: 16),
          const CombinedRevenueWidget(),
        ],
      );
    } else {
      // Mobile and Tablet layout
      return Column(
        children: [
          SizedBox(
            height: Responsive.isMobile(context) ? 300 : 400,
            child: const RevenueRealtimePercentage(),
          ),
          SizedBox(height: Responsive.isMobile(context) ? 8 : 16),
          SizedBox(
            height: Responsive.isMobile(context) ? 300 : 400,
            child: const PostStatus(),
          ),
          SizedBox(height: Responsive.isMobile(context) ? 8 : 16),
          const RevenueByLocations(),
          SizedBox(height: Responsive.isMobile(context) ? 8 : 16),
          const TrafficHours(),
          SizedBox(height: Responsive.isMobile(context) ? 8 : 16),
          const CombinedRevenueWidget(),
        ],
      );
    }
  }

  List<Widget> _buildSummaryCards() {
    return const [
      SummaryCards(
        title: 'Pendapatan 7 Hari Terakhir',
        apiUrl: 'http://127.0.0.1:8000/api/summarycards/',
      ),
      SummaryCards(
        title: 'Pendapatan Hari Ini',
        apiUrl: 'http://127.0.0.1:8000/api/summarycards/',
      ),
      SummaryCards(
        title: 'Transaksi 7 Hari Terakhir',
        apiUrl: 'http://127.0.0.1:8000/api/summarycards/',
      ),
      SummaryCards(
        title: 'Transaksi Hari Ini',
        apiUrl: 'http://127.0.0.1:8000/api/summarycards/',
      ),
    ];
  }
}