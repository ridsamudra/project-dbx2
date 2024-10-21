// lib/pages/dashboard/widgets/revenue_by_locations.dart

import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:http/browser_client.dart';

import 'package:frontend/services/auth_service.dart';
import 'package:frontend/components/responsive.dart';

class RevenueByLocations extends StatefulWidget {
  const RevenueByLocations({super.key});

  @override
  _RevenueByLocationsState createState() => _RevenueByLocationsState();
}

class _RevenueByLocationsState extends State<RevenueByLocations> {
  late Future<dynamic> _dataFuture;
  final AuthService authService = AuthService();
  String? selectedLocation;
  String? errorMessage;
  List<String> locations = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = fetchRevenueByLocations();
    _fetchLocations();
  }

  Future<dynamic> fetchRevenueByLocations([String? location]) async {
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

      final uri = Uri.parse(
        location == null
            ? 'http://127.0.0.1:8000/api/revenuebylocations/all'
            : 'http://127.0.0.1:8000/api/revenuebylocations/bylocations',
      ).replace(queryParameters: {
        'session_data': jsonEncode(sessionData),
        if (location != null) 'location': location,
      });

      final response =
          await client.get(uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.isEmpty) {
          throw NoDataException('No data available for the selected location');
        }
        return data;
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } on NoDataException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
      return null;
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred while fetching data: $e';
      });
      return null;
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchLocations() async {
    try {
      final sessionData = await authService.getSessionData();
      if (sessionData == null) {
        throw Exception('No session data available');
      }

      final client = BrowserClient()..withCredentials = true;

      final uri =
          Uri.parse('http://127.0.0.1:8000/api/revenuebylocations/bylocations')
              .replace(queryParameters: {
        'session_data': jsonEncode(sessionData),
      });

      final response =
          await client.get(uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        if (data is Map<String, dynamic>) {
          setState(() {
            locations = ['Semua', ...data.keys];
          });
        }
      } else {
        throw Exception(
            'Failed to load locations: ${response.statusCode}\nBody: ${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to fetch locations: $e';
      });
    }
  }

  void _openFilterDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: Responsive.isMobile(context) ? double.infinity : 400,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pilih Lokasi',
                  style: TextStyle(
                    fontSize: Responsive.getFontSize(context,
                        mobile: 18, tablet: 20, desktop: 22),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: locations.length,
                    itemBuilder: (context, index) {
                      final location = locations[index];
                      return ListTile(
                        title: Text(
                          location,
                          style: TextStyle(
                            fontSize: Responsive.getFontSize(context,
                                mobile: 14, tablet: 16, desktop: 16),
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(location),
                        selected: location == selectedLocation,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        tileColor: location == selectedLocation
                            ? Colors.blue.shade50
                            : null,
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

    if (selected != null && selected != selectedLocation) {
      setState(() {
        selectedLocation = selected == 'Semua' ? null : selected;
        errorMessage = null;
        _dataFuture = fetchRevenueByLocations(selectedLocation);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: Responsive.isMobile(context)
          ? const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0)
          : const EdgeInsets.symmetric(vertical: 8.0),
      color: Colors.white,
      child: Padding(
        padding: Responsive.isMobile(context)
            ? const EdgeInsets.all(12.0)
            : const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pendapatan Tiap Lokasi',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: const Color(0xFF757575),
                    fontSize: Responsive.getFontSize(
                      context,
                      mobile: 10,
                      tablet: 16,
                      desktop: 16,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildFilterButton(),
              ],
            ),
            SizedBox(height: Responsive.isMobile(context) ? 12.0 : 16.0),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              _buildErrorWidget()
            else
              _buildDataWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton() {
    return ElevatedButton.icon(
      icon: Icon(Icons.location_on,
          size: Responsive.getFontSize(context,
              mobile: 12, tablet: 16, desktop: 18)),
      label: Text(
        selectedLocation ?? 'Pilih Lokasi',
        style: TextStyle(
          fontSize: Responsive.getFontSize(context,
              mobile: 10, tablet: 14, desktop: 14),
          fontFamily: 'Montserrat',
        ),
      ),
      onPressed: _openFilterDialog,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black87,
        backgroundColor: Colors.white,
        elevation: 2,
        padding: Responsive.getPadding(
          context,
          mobile: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          tablet: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: Responsive.isMobile(context)
          ? const EdgeInsets.all(12.0)
          : const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade700,
            size: Responsive.isMobile(context) ? 20 : 24,
          ),
          SizedBox(width: Responsive.isMobile(context) ? 12.0 : 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.red.shade700,
                    fontSize: Responsive.isMobile(context) ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  errorMessage!,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.red.shade700,
                    fontSize: Responsive.isMobile(context) ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataWidget() {
    return FutureBuilder<dynamic>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorWidget();
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _buildNoDataWidget();
        }

        final data = snapshot.data;
        if (data is List) {
          return _buildTable(data);
        } else if (data is Map<String, dynamic>) {
          if (selectedLocation != null) {
            final locationData = data[selectedLocation];
            if (locationData == null ||
                (locationData is List && locationData.isEmpty)) {
              return _buildNoDataWidget();
            }
            return _buildTable(locationData);
          } else {
            return Column(
              children: data.entries.map((entry) {
                if (entry.value == null ||
                    (entry.value is List && entry.value.isEmpty)) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        color: Color(0xFF757575),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTable(entry.value),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            );
          }
        }

        return const Center(child: Text('Invalid data format'));
      },
    );
  }

  Widget _buildNoDataWidget() {
    return Container(
      padding: Responsive.isMobile(context)
          ? const EdgeInsets.all(12.0)
          : const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue.shade700,
            size: Responsive.isMobile(context) ? 20 : 24,
          ),
          SizedBox(width: Responsive.isMobile(context) ? 12.0 : 16.0),
          Expanded(
            child: Text(
              'Tidak ada data tersedia untuk lokasi ini.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.blue.shade700,
                fontSize: Responsive.isMobile(context) ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<dynamic> data) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: Responsive.isMobile(context)
              ? MediaQuery.of(context).size.width - 32
              : MediaQuery.of(context).size.width - 32,
        ),
        child: DataTable(
          columnSpacing: Responsive.isMobile(context) ? 15 : 20,
          horizontalMargin: Responsive.isMobile(context) ? 10 : 24,
          headingRowHeight: Responsive.isMobile(context) ? 48 : 56,
          dataRowHeight: Responsive.isMobile(context) ? 48 : 52,
          headingRowColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) => Colors.grey[200]),
          dataRowColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) => Colors.white),
          columns: _buildTableColumns(),
          rows: _buildDataRows(data),
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    final textStyle = TextStyle(
      fontFamily: 'Montserrat',
      fontSize: Responsive.isMobile(context) ? 12 : 14,
      fontWeight: FontWeight.bold,
    );

    return [
      DataColumn(label: Text('Waktu Terakhir Update', style: textStyle)),
      DataColumn(label: Text('Titik Lokasi', style: textStyle)),
      DataColumn(label: Text('Total Transaksi', style: textStyle)),
      DataColumn(label: Text('Total Pendapatan', style: textStyle)),
    ];
  }

  List<DataRow> _buildDataRows(List<dynamic> data) {
    final NumberFormat currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final textStyle = TextStyle(
      fontFamily: 'Montserrat',
      fontSize: Responsive.isMobile(context) ? 12 : 14,
      fontWeight: FontWeight.w500,
    );

    return data.map((row) {
      if (row == null) {
        return DataRow(cells: [
          DataCell(Text('-', style: textStyle)),
          DataCell(Text('-', style: textStyle)),
          DataCell(Text('-', style: textStyle)),
          DataCell(Text('-', style: textStyle)),
        ]);
      }

      return DataRow(
        cells: [
          DataCell(Text(
            row['waktu'] != null
                ? DateFormat('dd-MM-yyyy HH:mm:ss')
                    .format(DateTime.parse(row['waktu']))
                : '-',
            style: textStyle,
          )),
          DataCell(Text(row['id_lokasi'] ?? '-', style: textStyle)),
          DataCell(Text(
            row['total_transaksi'] != null
                ? NumberFormat.decimalPattern('id_ID')
                    .format(row['total_transaksi'])
                : '-',
            style: textStyle,
          )),
          DataCell(Text(
            row['total_pendapatan'] != null
                ? currencyFormat.format(row['total_pendapatan'])
                : '-',
            style: textStyle,
          )),
        ],
      );
    }).toList();
  }
}

class NoDataException implements Exception {
  final String message;
  NoDataException(this.message);
}
