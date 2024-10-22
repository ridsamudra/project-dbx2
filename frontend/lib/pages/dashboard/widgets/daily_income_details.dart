// lib/pages/dashboard/widgets/daily_income_details.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/components/responsive.dart';
import 'package:http/browser_client.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart' as excel;
import 'package:syncfusion_flutter_charts/charts.dart';

class DailyIncomeDetails extends StatefulWidget {
  final String location;
  const DailyIncomeDetails({super.key, required this.location});

  @override
  // ignore: library_private_types_in_public_api
  _DailyIncomeDetailsState createState() => _DailyIncomeDetailsState();
}

class _DailyIncomeDetailsState extends State<DailyIncomeDetails> {
  List<Map<String, dynamic>> dailyIncomeData = [];
  Map<String, dynamic> summaryData = {};

  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  String? errorMessage;
  bool isLoading = false;
  final AuthService authService = AuthService();

  // Modified chart visibility flags structure
  Map<String, bool> chartVisibility = {
    'Tarif': true,
    'Member': true,
    'Manual': true,
    'Masalah': true,
    'Total': true,
  };

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) => fetchDailyIncomeData());
  }

  Future<void> fetchDailyIncomeData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final sessionData = await authService.getSessionData();
      if (sessionData == null) {
        throw Exception('No session data available');
      }

      final client = BrowserClient()..withCredentials = true;
      final uri =
          Uri.parse('http://127.0.0.1:8000/api/revenuedetails/filterbydays/')
              .replace(queryParameters: {
        'session_data': jsonEncode(sessionData),
        'year': selectedYear.toString(),
        'month': selectedMonth.toString(),
        'location': widget.location,
      });

      final response =
          await client.get(uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data[widget.location] != null) {
          final locationData = data[widget.location] as List<dynamic>;
          setState(() {
            dailyIncomeData = List<Map<String, dynamic>>.from(
                locationData.where((item) => item['tanggal'] != null));
            summaryData = locationData.lastWhere(
                (item) => item['total'] != null,
                orElse: () => {}) as Map<String, dynamic>;
          });
        } else {
          throw NoDataException(
              'No data available for the selected location and period');
        }
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } on NoDataException catch (e) {
      setState(() => errorMessage = e.message);
    } catch (e) {
      setState(
          () => errorMessage = 'An error occurred while fetching data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: Responsive.isMobile(context) ? 8.0 : 16.0),
          _buildDataCard(),
          SizedBox(height: Responsive.isMobile(context) ? 8.0 : 16.0),
          _buildChartCard(),
        ],
      ),
    );
  }

  Widget _buildDataCard() {
    return Card(
      margin: Responsive.getPadding(
        context,
        mobile: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        tablet: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        desktop: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      ),
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: Responsive.getPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: Responsive.isMobile(context) ? 12.0 : 24.0),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              _buildErrorWidget()
            else
              _buildDataTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return Card(
      margin: Responsive.getPadding(
        context,
        mobile: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        tablet: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        desktop: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      ),
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: Responsive.getPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChartHeader(),
            SizedBox(height: Responsive.isMobile(context) ? 12.0 : 24.0),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              _buildErrorWidget()
            else
              SizedBox(
                height: Responsive.isMobile(context) ? 300 : 350,
                child: _buildMultiLineChart(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Grafik Pendapatan Harian',
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: const Color(0xFF757575),
              fontSize: Responsive.getFontSize(context,
                  mobile: 10, tablet: 16, desktop: 16),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton.icon(
          icon: Icon(
            Icons.visibility,
            size: Responsive.isMobile(context) ? 16 : 20,
          ),
          label: Text(
            'Filter Visibilitas',
            style: TextStyle(
              fontSize: Responsive.getFontSize(context,
                  mobile: 10, tablet: 14, desktop: 14),
            ),
          ),
          onPressed: _showVisibilityDialog,
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black87,
            backgroundColor: Colors.white,
            elevation: 2,
            padding: Responsive.getPadding(
              context,
              mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tablet: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              desktop: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
        ),
      ],
    );
  }

  void _showVisibilityDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Container(
                width: Responsive.isMobile(context)
                    ? MediaQuery.of(context).size.width * 0.8
                    : MediaQuery.of(context).size.width * 0.3,
                padding: Responsive.getPadding(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Visibilitas',
                      style: TextStyle(
                        fontSize: Responsive.getFontSize(context,
                            mobile: 16, tablet: 18, desktop: 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...chartVisibility.entries.map(
                      (entry) => CheckboxListTile(
                        title: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: Responsive.getFontSize(context,
                                mobile: 14, tablet: 16, desktop: 16),
                          ),
                        ),
                        value: entry.value,
                        onChanged: (bool? value) {
                          setState(() {
                            chartVisibility[entry.key] = value!;
                          });
                          this.setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Tutup',
                            style: TextStyle(
                              fontSize: Responsive.getFontSize(context,
                                  mobile: 14, tablet: 16, desktop: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMultiLineChart() {
    if (dailyIncomeData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    List<CartesianSeries<Map<String, dynamic>, DateTime>> series = [];

    // Helper function to create series without hover effect
    LineSeries<Map<String, dynamic>, DateTime> createSeries(
      String name,
      Color color,
      num Function(Map<String, dynamic>) valueMapper,
    ) {
      return LineSeries<Map<String, dynamic>, DateTime>(
        name: name,
        dataSource: dailyIncomeData,
        xValueMapper: (Map<String, dynamic> data, _) =>
            DateTime.tryParse(data['tanggal'] ?? '') ?? DateTime.now(),
        yValueMapper: (Map<String, dynamic> data, _) =>
            valueMapper(data).toDouble(),
        color: color,
        width: 2,
        markerSettings: const MarkerSettings(
          isVisible: true,
          height: 8,
          width: 8,
        ),
        dataLabelSettings: const DataLabelSettings(isVisible: false),
        enableTooltip: true,
        animationDuration: 500,
      );
    }

    // Add series with visibility check
    if (chartVisibility['Tarif']!) {
      series.add(createSeries(
        'Tarif',
        Colors.blue,
        (data) =>
            ((data['tarif_tunai'] as num?) ?? 0) +
            ((data['tarif_non_tunai'] as num?) ?? 0),
      ));
    }

    if (chartVisibility['Member']!) {
      series.add(createSeries(
        'Member',
        Colors.green,
        (data) => (data['member'] as num?) ?? 0,
      ));
    }

    if (chartVisibility['Manual']!) {
      series.add(createSeries(
        'Manual',
        Colors.orange,
        (data) => (data['manual'] as num?) ?? 0,
      ));
    }

    if (chartVisibility['Masalah']!) {
      series.add(createSeries(
        'Masalah',
        Colors.red,
        (data) => (data['tiket_masalah'] as num?) ?? 0,
      ));
    }

    if (chartVisibility['Total']!) {
      series.add(createSeries(
        'Total',
        Colors.purple,
        (data) => (data['total_pendapatan'] as num?) ?? 0,
      ));
    }

    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('d MMM'),
        intervalType: DateTimeIntervalType.days,
        interval: Responsive.isMobile(context) ? 5 : 3,
        labelRotation: Responsive.isMobile(context) ? 45 : 0,
        labelStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: Responsive.getFontSize(context,
              mobile: 8, tablet: 10, desktop: 12),
          fontWeight: FontWeight.bold,
        ),
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.decimalPattern(),
        labelFormat: '{value}',
        labelStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: Responsive.getFontSize(context,
              mobile: 8, tablet: 10, desktop: 12),
          fontWeight: FontWeight.bold,
        ),
      ),
      legend: Legend(
        isVisible: true,
        position: LegendPosition.top,
        alignment: ChartAlignment.center,
        overflowMode: LegendItemOverflowMode.wrap,
        padding: 15,
        itemPadding: 10,
        toggleSeriesVisibility: false, // Disabled series visibility toggle
        legendItemBuilder:
            (String name, dynamic series, dynamic point, int index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: Responsive.isMobile(context) ? 8 : 12,
                  height: Responsive.isMobile(context) ? 8 : 12,
                  decoration: BoxDecoration(
                    color: series.color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: Responsive.isMobile(context) ? 3 : 5),
                Text(
                  name,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: Responsive.getFontSize(context,
                        mobile: 10, tablet: 16, desktop: 16),
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        duration: 250, // Reduced tooltip duration
        animationDuration: 250, // Reduced tooltip animation duration
        builder: (dynamic data, dynamic point, dynamic series, int pointIndex,
            int seriesIndex) {
          final value = point.y;
          final formattedValue = NumberFormat('#,###').format(value);
          final seriesName = series.name;
          final seriesColor = series.color;
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 2, spreadRadius: 1)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: seriesColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      seriesName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  DateFormat('d MMM').format(point.x),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Rp $formattedValue',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      series: series,
      zoomPanBehavior: ZoomPanBehavior(
        enablePanning: true,
        enablePinching: true,
        zoomMode: ZoomMode.x,
      ),
    );
  }

  Widget _buildHeader() {
    //remain the same
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'Pendapatan Harian Detail',
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: const Color(0xFF757575),
              fontSize: Responsive.getFontSize(context,
                  mobile: 10, tablet: 16, desktop: 16),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildFilterAndExportButtons(),
      ],
    );
  }

  Widget _buildFilterAndExportButtons() {
    //remain the same
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterButton(
          icon: Icons.filter_list,
          label: 'Filter',
          onPressed: () => _showFilterOptions(context),
        ),
        _buildFilterButton(
          icon: Icons.file_download,
          label: 'Export',
          onPressed: _showExportDialog,
        ),
      ],
    );
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: Responsive.isMobile(context) ? 12 : 18),
      label: Text(
        label,
        style: TextStyle(
          fontSize: Responsive.getFontSize(context,
              mobile: 10, tablet: 14, desktop: 14),
        ),
      ),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black87,
        backgroundColor: Colors.white,
        elevation: 2,
        padding: Responsive.getPadding(
          context,
          mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          tablet: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          desktop: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    //remain the same
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          child: Container(
            width: MediaQuery.of(context).size.width *
                (Responsive.isMobile(context) ? 0.7 : 0.3),
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildFilterOption(
                  context,
                  icon: Icons.event,
                  label: 'Filter Bulan',
                  onTap: () {
                    Navigator.pop(context);
                    _selectMonth(context);
                  },
                ),
                _buildFilterOption(
                  context,
                  icon: Icons.calendar_today,
                  label: 'Filter Tahun',
                  onTap: () {
                    Navigator.pop(context);
                    _selectYear(context);
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Tutup", style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    //remain the same
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: onTap,
    );
  }

  void _showExportDialog() {
    //remain the same
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          child: Container(
            width: Responsive.isMobile(context)
                ? MediaQuery.of(context).size.width * 0.8
                : MediaQuery.of(context).size.width * 0.3,
            padding: Responsive.getPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Export Data',
                  style: TextStyle(
                    fontSize: Responsive.getFontSize(context,
                        mobile: 16, tablet: 18, desktop: 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: Responsive.isMobile(context) ? 12 : 16),
                Text(
                  'Pilih format export:',
                  style: TextStyle(
                    fontSize: Responsive.getFontSize(context,
                        mobile: 14, tablet: 16, desktop: 16),
                  ),
                ),
                SizedBox(height: Responsive.isMobile(context) ? 12 : 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: Text(
                        'PDF',
                        style: TextStyle(
                          fontSize: Responsive.getFontSize(context,
                              mobile: 14, tablet: 16, desktop: 16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _exportToPDF();
                      },
                    ),
                    TextButton(
                      child: Text(
                        'Excel',
                        style: TextStyle(
                          fontSize: Responsive.getFontSize(context,
                              mobile: 14, tablet: 16, desktop: 16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _exportToExcel();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportToPDF() async {
    //remain the same
    final pdf = pw.Document();
    final font =
        await rootBundle.load("assets/fonts/Roboto/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(font);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: _getColumns().map((column) {
                  return pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(column,
                        style: pw.TextStyle(
                            font: ttf, fontWeight: pw.FontWeight.bold)),
                  );
                }).toList(),
              ),
              ..._getDataRows().map((row) {
                return pw.TableRow(
                  children: row.map((cell) {
                    return pw.Container(
                      alignment: pw.Alignment.centerRight,
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(cell, style: pw.TextStyle(font: ttf)),
                    );
                  }).toList(),
                );
              }),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _exportToExcel() async {
    //remain the same
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Sheet1'];

    final headers = _getColumns();
    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = excel.TextCellValue(headers[i]);
    }

    final data = _getDataRows();
    for (var i = 0; i < data.length; i++) {
      for (var j = 0; j < data[i].length; j++) {
        final cellValue = data[i][j];
        sheet
            .cell(excel.CellIndex.indexByColumnRow(
                columnIndex: j, rowIndex: i + 1))
            .value = excel.TextCellValue(cellValue);
      }
    }

    final bytes = excelFile.save();
    final blob = html.Blob([bytes!],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'daily_income_details.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  List<String> _getColumns() {
    return [
      'Tanggal',
      'Tarif Tunai',
      'Tarif Non Tunai',
      'Member',
      'Manual',
      'Tiket Masalah',
      'Total Pendapatan',
      'Qty Casual',
      'Qty Pass',
      'Total Qty',
    ];
  }

  List<List<String>> _getDataRows() {
    final rows = <List<String>>[];
    final filteredData = dailyIncomeData.where((item) {
      return item.values.every((value) => value != null) &&
          item.values.any((value) => value is num && value != 0);
    }).toList();

    for (var item in filteredData) {
      rows.add([
        DateFormat('d MMMM yyyy', 'id_ID')
            .format(DateTime.parse(item['tanggal'])),
        NumberFormat('#,###.##').format(item['tarif_tunai']),
        NumberFormat('#,###.##').format(item['tarif_non_tunai']),
        NumberFormat('#,###.##').format(item['member']),
        NumberFormat('#,###.##').format(item['manual']),
        NumberFormat('#,###.##').format(item['tiket_masalah']),
        NumberFormat('#,###.##').format(item['total_pendapatan']),
        NumberFormat('#,###.##').format(item['qty_casual']),
        NumberFormat('#,###.##').format(item['qty_pass']),
        NumberFormat('#,###.##').format(item['total_qty']),
      ]);
    }

    // Add summary rows
    final summaryData = _calculateSummaryData(filteredData);
    for (var key in ['Total', 'Minimal', 'Maksimal', 'Rata-rata']) {
      final data = summaryData[key]!;
      rows.add([
        key,
        NumberFormat('#,###.##').format(data['tarif_tunai']),
        NumberFormat('#,###.##').format(data['tarif_non_tunai']),
        NumberFormat('#,###.##').format(data['member']),
        NumberFormat('#,###.##').format(data['manual']),
        NumberFormat('#,###.##').format(data['tiket_masalah']),
        NumberFormat('#,###.##').format(data['total_pendapatan']),
        NumberFormat('#,###.##').format(data['qty_casual']),
        NumberFormat('#,###.##').format(data['qty_pass']),
        NumberFormat('#,###.##').format(data['total_qty']),
      ]);
    }

    return rows;
  }

  Future<void> _selectYear(BuildContext context) async {
    final int? picked = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          child: Container(
            width: Responsive.isMobile(context)
                ? MediaQuery.of(context).size.width * 0.8
                : MediaQuery.of(context).size.width * 0.3,
            padding: Responsive.getPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pilih Tahun',
                  style: TextStyle(
                    fontSize: Responsive.getFontSize(context,
                        mobile: 16, tablet: 18, desktop: 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: Responsive.isMobile(context) ? 12 : 16),
                SizedBox(
                  height: Responsive.isMobile(context) ? 200 : 300,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: 5,
                    itemBuilder: (BuildContext context, int index) {
                      final year = DateTime.now().year - 2 + index;
                      return ListTile(
                        title: Text(
                          year.toString(),
                          style: TextStyle(
                            fontSize: Responsive.getFontSize(context,
                                mobile: 14, tablet: 16, desktop: 16),
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(year),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null && picked != selectedYear) {
      setState(() {
        selectedYear = picked;
      });
      fetchDailyIncomeData();
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final int? picked = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          child: Container(
            width: Responsive.isMobile(context)
                ? MediaQuery.of(context).size.width * 0.8
                : MediaQuery.of(context).size.width * 0.3,
            padding: Responsive.getPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pilih Bulan',
                  style: TextStyle(
                    fontSize: Responsive.getFontSize(context,
                        mobile: 16, tablet: 18, desktop: 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: Responsive.isMobile(context) ? 12 : 16),
                SizedBox(
                  height: Responsive.isMobile(context) ? 200 : 300,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: 12,
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                        title: Text(
                          DateFormat('MMMM', 'id_ID')
                              .format(DateTime(2022, index + 1)),
                          style: TextStyle(
                            fontSize: Responsive.getFontSize(context,
                                mobile: 14, tablet: 16, desktop: 16),
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(index + 1),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null && picked != selectedMonth) {
      setState(() {
        selectedMonth = picked;
      });
      fetchDailyIncomeData();
    }
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: Responsive.getPadding(context),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Colors.red.shade700,
              size: Responsive.isMobile(context) ? 16 : 24),
          SizedBox(width: Responsive.isMobile(context) ? 8.0 : 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.red.shade700,
                    fontSize: Responsive.getFontSize(context,
                        mobile: 12, tablet: 14, desktop: 14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: Responsive.isMobile(context) ? 2.0 : 4.0),
                Text(
                  errorMessage!,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.red.shade700,
                    fontSize: Responsive.getFontSize(context,
                        mobile: 12, tablet: 14, desktop: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: Responsive.isMobile(context)
              ? MediaQuery.of(context).size.width
              : MediaQuery.of(context).size.width * 0.95,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.grey[300],
          ),
          child: DataTable(
            columnSpacing: Responsive.isMobile(context) ? 12 : 24,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFECF0F1)),
            dataRowColor: WidgetStateProperty.all(Colors.white),
            border: TableBorder.all(
              color: Colors.grey[300]!,
              width: 1,
              style: BorderStyle.solid,
            ),
            dataRowHeight: Responsive.isMobile(context) ? 48 : 60,
            headingRowHeight: Responsive.isMobile(context) ? 52 : 64,
            horizontalMargin: Responsive.isMobile(context) ? 8 : 16,
            columns: _buildColumns(),
            rows: _buildDataRows(),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    final columns = [
      'Tanggal',
      'Tarif Tunai',
      'Tarif Non Tunai',
      'Member',
      'Manual',
      'Tiket Masalah',
      'Total Pendapatan',
      'Qty Casual',
      'Qty Pass',
      'Total Qty',
    ];

    return columns
        .map((column) => DataColumn(
              label: Expanded(
                child: Text(
                  column,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: Responsive.getFontSize(context,
                        mobile: 10, tablet: 12, desktop: 14),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF34495E),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ))
        .toList();
  }

  List<DataRow> _buildDataRows() {
    final List<DataRow> rows = [];
    final filteredData = dailyIncomeData.where((item) {
      return item.values.every((value) => value != null) &&
          item.values.any((value) => value is num && value != 0);
    }).toList();

    rows.addAll(filteredData.map((item) => _buildRow(item)));

    if (filteredData.isNotEmpty) {
      final summaryData = _calculateSummaryData(filteredData);
      rows.addAll([
        _buildRow(summaryData['Total']!,
            rowName: 'Total', color: const Color(0xFFE8F0FE), isSummary: true),
        _buildRow(summaryData['Minimal']!,
            rowName: 'Minimal',
            color: const Color(0xFFE8F8F5),
            isSummary: true),
        _buildRow(summaryData['Maksimal']!,
            rowName: 'Maksimal',
            color: const Color(0xFFFDF2E9),
            isSummary: true),
        _buildRow(summaryData['Rata-rata']!,
            rowName: 'Rata-rata',
            color: const Color(0xFFF4ECF7),
            isSummary: true),
      ]);
    }

    return rows;
  }

  Map<String, Map<String, dynamic>> _calculateSummaryData(
      List<Map<String, dynamic>> filteredData) {
    final keys = [
      'tarif_tunai',
      'tarif_non_tunai',
      'member',
      'manual',
      'tiket_masalah',
      'total_pendapatan',
      'qty_casual',
      'qty_pass',
      'total_qty'
    ];

    return {
      'Total': Map.fromIterable(keys,
          value: (key) => filteredData.fold<num>(0,
              (sum, item) => sum + (item[key] is num ? item[key] as num : 0))),
      'Minimal': Map.fromIterable(keys, value: (key) {
        final validValues = filteredData
            .where((item) => item[key] is num)
            .map((item) => item[key] as num)
            .toList();
        return validValues.isNotEmpty ? validValues.reduce(min) : 0;
      }),
      'Maksimal': Map.fromIterable(keys, value: (key) {
        final validValues = filteredData
            .where((item) => item[key] is num)
            .map((item) => item[key] as num)
            .toList();
        return validValues.isNotEmpty ? validValues.reduce(max) : 0;
      }),
      'Rata-rata': Map.fromIterable(keys, value: (key) {
        final validValues = filteredData
            .where((item) => item[key] is num)
            .map((item) => item[key] as num)
            .toList();
        return validValues.isNotEmpty
            ? validValues.reduce((a, b) => a + b) / validValues.length
            : 0;
      }),
    };
  }

  num min(num a, num b) => a < b ? a : b;
  num max(num a, num b) => a > b ? a : b;

  DataRow _buildRow(Map<String, dynamic> data,
      {String? rowName, Color? color, bool isSummary = false}) {
    TextStyle cellTextStyle = TextStyle(
      fontFamily: 'Montserrat',
      fontSize:
          Responsive.getFontSize(context, mobile: 10, tablet: 14, desktop: 14),
      fontWeight: rowName != null ? FontWeight.w600 : FontWeight.w500,
      color: const Color(0xFF2C3E50),
    );

    // remain the same untuk cell configurations
    final cells = [
      DataCell(
        Center(
          child: Text(
            rowName ??
                (data['tanggal'] != null
                    ? DateFormat('d MMMM yyyy', 'id_ID')
                        .format(DateTime.parse(data['tanggal']))
                    : '-'),
            style: cellTextStyle,
            textAlign: isSummary ? TextAlign.left : TextAlign.center,
          ),
        ),
      ),
      ...[
        'tarif_tunai',
        'tarif_non_tunai',
        'member',
        'manual',
        'tiket_masalah',
        'total_pendapatan',
        'qty_casual',
        'qty_pass',
        'total_qty'
      ].map((key) {
        final value = data[key];
        return DataCell(
          Container(
            alignment: Alignment.centerRight,
            child: Text(
              value is num ? NumberFormat('#,###.##').format(value) : '-',
              style: cellTextStyle,
            ),
          ),
        );
      }),
    ];

    return DataRow(
      cells: cells,
      color: color != null ? WidgetStateProperty.all(color) : null,
    );
  }
}

class NoDataException implements Exception {
  final String message;
  NoDataException(this.message);
}
