import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'login_page.dart';
import 'manage_locations_page.dart';
import 'add_meeting_page.dart';
import 'manage_requests_page.dart';
import 'notifications_page.dart';
import 'manage_users_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Appointment> _meetings = [];
  bool _isLoading = true;

  // Variabel Filter
  final TextEditingController _searchController = TextEditingController();
  String? _selectedLocationId;
  List<dynamic> _locations = [];

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _fetchMeetings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Mengambil data lokasi untuk dropdown
  Future<void> _fetchLocations() async {
    try {
      final response = await Supabase.instance.client
          .from('locations')
          .select('id, nama_lokasi')
          .isFilter('deleted_at', null);
      if (mounted) setState(() => _locations = response);
    } catch (e) {
      debugPrint("Gagal memuat lokasi: $e");
    }
  }

  // Fetch data dengan logika Filter & Search
  Future<void> _fetchMeetings() async {
    setState(() => _isLoading = true);
    try {
      var query = Supabase.instance.client
          .from('meetings')
          .select('*, locations(nama_lokasi), profiles!requested_by(nama_dinas)')
          .eq('status', 'approved')
          .isFilter('deleted_at', null);

      // Filter Pencarian (Judul)
      if (_searchController.text.isNotEmpty) {
        query = query.ilike('judul', '%${_searchController.text}%');
      }

      // Filter Lokasi
      if (_selectedLocationId != null) {
        query = query.eq('lokasi_id', _selectedLocationId!);
      }

      final response = await query;
      final List<Appointment> loadedAppointments = [];

      for (var item in response) {
        final String namaRuangan = item['locations'] != null ? item['locations']['nama_lokasi'] : 'Lokasi Tidak Diketahui';

        loadedAppointments.add(Appointment(
          id: item,
          startTime: DateTime.parse(item['waktu_mulai']).toLocal(),
          endTime: DateTime.parse(item['waktu_selesai']).toLocal(),
          subject: '${item['judul']} ($namaRuangan)',
          notes: item['deskripsi'],
          color: Colors.blue,
        ));
      }

      if (mounted) {
        setState(() {
          _meetings = loadedAppointments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMeeting(String meetingId) async {
    try {
      await Supabase.instance.client.from('meetings').update({
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', meetingId);

      _fetchMeetings();

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jadwal dihapus!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus jadwal'), backgroundColor: Colors.red));
    }
  }

void _showMeetingDetails(Map<String, dynamic> meetingData) {
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
              // Header
              Row(
                children: [
                  const Icon(Icons.event_note, color: Colors.blue, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      meetingData['judul'],
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              
              _infoRow(Icons.location_on, 'Lokasi', meetingData['locations']?['nama_lokasi'] ?? 'Tidak diketahui'),

              _infoRow(Icons.business, 'Dinas/Instansi', namaDinasTampil),
              
              const SizedBox(height: 12),
              _infoRow(Icons.calendar_today, 'Tanggal', dateFormat.format(DateTime.parse(meetingData['waktu_mulai']).toLocal())),
              const SizedBox(height: 12),
              _infoRow(Icons.access_time, 'Waktu', 
                '${timeFormat.format(DateTime.parse(meetingData['waktu_mulai']).toLocal())} - ${timeFormat.format(DateTime.parse(meetingData['waktu_selesai']).toLocal())} WIB'
              ),
              const SizedBox(height: 12),
              _infoRow(Icons.notes, 'Deskripsi', meetingData['deskripsi'] ?? '-', isMultiline: true),
              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (context) => AddMeetingPage(existingMeeting: meetingData),
                      ));
                      _fetchMeetings();
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteMeeting(meetingData['id']);
                    },
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Hapus'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // KODE BARU
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
        title: const Text('Dashboard Admin BCC', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.admin_panel_settings, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text('Admin Command Center', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_task),
              title: const Text('Tambah Meeting'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddMeetingPage()));
                _fetchMeetings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Kelola Lokasi Meeting'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageLocationsPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.fact_check),
              title: const Text('Persetujuan Jadwal'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageRequestsPage()));
                _fetchMeetings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Tambah User'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageUsersPage()));
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
      body: Column(
        children: [
          // Bar Filter & Pencarian
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Cari Judul...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    ),
                    onChanged: (val) => _fetchMeetings(),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                  child: DropdownButton<String>(
                    hint: const Text('Lokasi'),
                    value: _selectedLocationId,
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Semua Lokasi')),
                      ..._locations.map((loc) => DropdownMenuItem(value: loc['id'].toString(), child: Text(loc['nama_lokasi']))),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedLocationId = val);
                      _fetchMeetings();
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Kalender
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SfCalendar(
                    view: CalendarView.month,
                    showNavigationArrow: true,
                    appointmentTextStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    dataSource: MeetingDataSource(_meetings),
                    monthViewSettings: const MonthViewSettings(
                      appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
                      showAgenda: true,
                      agendaItemHeight: 50,
                      monthCellStyle: MonthCellStyle(
                        textStyle: TextStyle(fontSize: 20, color: Colors.black87),
                      ),
                    ),
                    onTap: (CalendarTapDetails details) {
                      if (details.appointments != null && details.appointments!.isNotEmpty) {
                        final Appointment tappedMeeting = details.appointments!.first;
                        final Map<String, dynamic> rawData = tappedMeeting.id as Map<String, dynamic>;
                        _showMeetingDetails(rawData);
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Appointment> source) {
    appointments = source;
  }
}