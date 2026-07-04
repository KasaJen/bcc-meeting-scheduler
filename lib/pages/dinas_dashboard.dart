import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; 
import 'login_page.dart';
import 'request_meeting_page.dart';
import 'notifications_page.dart';

class DinasDashboard extends StatefulWidget {
  const DinasDashboard({super.key});

  @override
  State<DinasDashboard> createState() => _DinasDashboardState();
}

class _DinasDashboardState extends State<DinasDashboard> {
  List<Appointment> _meetings = [];
  List<Map<String, dynamic>> _rawMeetings = [];
  bool _isLoading = true;
  String _namaDinas = 'Memuat...';

  final TextEditingController _searchController = TextEditingController();
  String? _selectedLocation;
  List<dynamic> _locations = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchLocations();
    _fetchMeetings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('profiles')
          .select('nama_dinas')
          .eq('id', userId)
          .single();
          
      if (mounted) {
        setState(() {
          _namaDinas = response['nama_dinas'] ?? 'User Dinas';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _namaDinas = 'User Dinas');
    }
  }

  Future<void> _fetchLocations() async {
    try {
      final response = await Supabase.instance.client
          .from('locations')
          .select('id, nama_lokasi')
          .isFilter('deleted_at', null);
      if (mounted) {
        setState(() {
          _locations = response;
        });
      }
    } catch (e) {
      debugPrint('Error fetching locations: $e');
    }
  }

  Future<void> _fetchMeetings() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('meetings')
          .select('*, locations(nama_lokasi), profiles!requested_by(nama_dinas)')
          .eq('status', 'approved')
          .isFilter('deleted_at', null);

      if (mounted) {
        _rawMeetings = List<Map<String, dynamic>>.from(response);
        _applyFilter(); 
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    final List<Appointment> filteredAppointments = [];

    for (var item in _rawMeetings) {
      final String judul = (item['judul'] ?? '').toString().toLowerCase();
      final String lokasiId = item['lokasi_id']?.toString() ?? '';
      final String namaRuangan = item['locations'] != null ? item['locations']['nama_lokasi'] : 'Lokasi Tidak Diketahui';

      bool matchQuery = query.isEmpty || judul.contains(query);
      bool matchLocation = _selectedLocation == null || lokasiId == _selectedLocation;

      if (matchQuery && matchLocation) {
        filteredAppointments.add(Appointment(
          id: item, 
          startTime: DateTime.parse(item['waktu_mulai']).toLocal(),
          endTime: DateTime.parse(item['waktu_selesai']).toLocal(),
          subject: '${item['judul']} ($namaRuangan)',
          notes: item['deskripsi'],
          color: Colors.green,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _meetings = filteredAppointments;
        _isLoading = false;
      });
    }
  }

  void _showMeetingDetailsDinas(Map<String, dynamic> meetingData) {
    final dateFormat = DateFormat('EEEE, dd MMM yyyy', 'id_ID');
    final timeFormat = DateFormat('HH:mm');

    final String namaDinasTampil = (meetingData['nama_instansi_manual'] != null && meetingData['nama_instansi_manual'] != "")
        ? meetingData['nama_instansi_manual'] 
        : (meetingData['profiles']?['nama_dinas'] ?? 'Tidak diketahui');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.green, size: 30),
                  const SizedBox(width: 10),
                  Expanded(child: Text(meetingData['judul'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                ],
              ),
              const Divider(height: 30),
              
              _infoRow(Icons.location_on, 'Lokasi', meetingData['locations']?['nama_lokasi'] ?? 'Tidak diketahui'),
              const SizedBox(height: 12),
              _infoRow(Icons.business, 'Dinas/Instansi', namaDinasTampil),
              const SizedBox(height: 12),
              _infoRow(Icons.calendar_today, 'Tanggal', dateFormat.format(DateTime.parse(meetingData['waktu_mulai']).toLocal())),
              const SizedBox(height: 12),
              _infoRow(Icons.access_time, 'Waktu', 
                '${timeFormat.format(DateTime.parse(meetingData['waktu_mulai']).toLocal())} - ${timeFormat.format(DateTime.parse(meetingData['waktu_selesai']).toLocal())} WIB'
              ),
              const SizedBox(height: 12),
              _infoRow(Icons.check_circle_outline, 'Status', meetingData['status'].toString().toUpperCase()),
              const SizedBox(height: 12),
              _infoRow(Icons.notes, 'Deskripsi', meetingData['deskripsi'] ?? '-', isMultiline: true),
              
              const SizedBox(height: 30),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _infoRow(IconData icon, String label, String value, {bool isMultiline = false}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: Colors.grey),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
            Text(
              value, 
              style: const TextStyle(fontSize: 15), 
              maxLines: isMultiline ? null : 1, 
              overflow: isMultiline ? null : TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );
}

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard $_namaDinas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.green, 
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.green),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.business, size: 50, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(_namaDinas, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_send),
              title: const Text('Ajukan Jadwal Meeting'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const RequestMeetingPage()));
                _fetchMeetings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifikasi'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Cari Judul...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          ),
                          onChanged: (value) => _applyFilter(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          ),
                          hint: const Text('Semua Lokasi'),
                          initialValue: _selectedLocation,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Semua Lokasi')),
                            ..._locations.map((loc) {
                              return DropdownMenuItem<String>(
                                value: loc['id'].toString(),
                                child: Text(loc['nama_lokasi'].toString()),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            _selectedLocation = value;
                            _applyFilter();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: SfCalendar(
                    view: CalendarView.month,
                    showNavigationArrow: true,
                    appointmentTextStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    dataSource: _MeetingDataSource(_meetings),
                    monthViewSettings: const MonthViewSettings(
                      appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
                      showAgenda: true,
                      monthCellStyle: MonthCellStyle(
                        textStyle: TextStyle(fontSize: 20, color: Colors.black87),
                      ),
                    ),
                    onTap: (CalendarTapDetails details) {
                      if (details.appointments != null && details.appointments!.isNotEmpty) {
                        final Appointment tappedMeeting = details.appointments!.first;
                        final Map<String, dynamic> rawData = tappedMeeting.id as Map<String, dynamic>;
                        _showMeetingDetailsDinas(rawData);
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _MeetingDataSource extends CalendarDataSource {
  _MeetingDataSource(List<Appointment> source) {
    appointments = source;
  }
}