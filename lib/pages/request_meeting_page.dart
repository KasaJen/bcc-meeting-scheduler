import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class RequestMeetingPage extends StatefulWidget {
  const RequestMeetingPage({super.key});

  @override
  State<RequestMeetingPage> createState() => _RequestMeetingPageState();
}

class _RequestMeetingPageState extends State<RequestMeetingPage> {
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  
  DateTime? _waktuMulai;
  DateTime? _waktuSelesai;
  String? _selectedLokasiId;
  
  List<dynamic> _lokasiList = [];
  bool _isLoadingLokasi = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchLokasi();
  }

  Future<void> _fetchLokasi() async {
    try {
      final response = await Supabase.instance.client
          .from('locations')
          .select()
          .isFilter('deleted_at', null)
          .order('nama_lokasi');
          
      if (mounted) {
        setState(() {
          _lokasiList = response;
          _isLoadingLokasi = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLokasi = false);
    }
  }

Future<bool> _isCollision(String lokasiId, DateTime mulai, DateTime selesai, {String? excludeMeetingId}) async {
    try {
      final startUtc = mulai.toUtc().toIso8601String();
      final endUtc = selesai.toUtc().toIso8601String();

      var query = Supabase.instance.client
          .from('meetings')
          .select('id')
          .eq('lokasi_id', lokasiId)
          .inFilter('status', ['approved', 'pending']) 
          .isFilter('deleted_at', null)
          .lt('waktu_mulai', endUtc)
          .gt('waktu_selesai', startUtc);

      if (excludeMeetingId != null) {
        query = query.neq('id', excludeMeetingId);
      }

      final response = await query;
      
      return (response as List).isNotEmpty;
    } catch (e) {
      return true; 
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? initialDate) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime.now(), 
      lastDate: DateTime(2100),
    );
    if (date == null) return null;

    if (!mounted) return null;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate ?? DateTime.now()),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

Future<void> _ajukanMeeting() async {
    if (_judulController.text.trim().isEmpty || _waktuMulai == null || _waktuSelesai == null || _selectedLokasiId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap lengkapi semua data wajib!'), backgroundColor: Colors.red));
      return;
    }

    if (_waktuSelesai!.isBefore(_waktuMulai!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Waktu selesai tidak boleh lebih awal dari waktu mulai!'), backgroundColor: Colors.red));
      return;
    }

    //Collision Detection
    final isCollision = await _isCollision(_selectedLokasiId!, _waktuMulai!, _waktuSelesai!);

    if (isCollision) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jadwal bentrok! Ruangan sudah dipesan pada jam tersebut.'), backgroundColor: Colors.red)
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final judulMeeting = _judulController.text.trim();

      //Insert
      await Supabase.instance.client.from('meetings').insert({
        'judul': judulMeeting,
        'deskripsi': _deskripsiController.text.trim(),
        'waktu_mulai': _waktuMulai!.toUtc().toIso8601String(),
        'waktu_selesai': _waktuSelesai!.toUtc().toIso8601String(),
        'lokasi_id': _selectedLokasiId,
        'requested_by': userId,
        'status': 'pending', 
      });

      //Notifikasi ke Admin
      final admins = await Supabase.instance.client.from('profiles').select('id').eq('role', 'admin');
      
      for (var admin in admins) {
        await Supabase.instance.client.from('notifications').insert({
          'user_id': admin['id'],
          'judul': 'Pengajuan Jadwal Baru',
          'pesan': 'Terdapat pengajuan jadwal baru berjudul "$judulMeeting" yang menunggu persetujuan Anda.',
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jadwal berhasil diajukan! Menunggu persetujuan Admin.'), backgroundColor: Colors.green)
      );
      Navigator.pop(context); 
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengajukan jadwal.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajukan Jadwal Meeting'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _judulController,
              decoration: const InputDecoration(labelText: 'Judul Meeting *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deskripsiController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Deskripsi (Opsional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            
            _isLoadingLokasi
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Pilih Lokasi *', border: OutlineInputBorder()),
                    initialValue: _selectedLokasiId,
                    items: _lokasiList.map((lokasi) {
                      return DropdownMenuItem<String>(
                        value: lokasi['id'],
                        child: Text('${lokasi['nama_lokasi']} (Kapasitas: ${lokasi['kapasitas']})'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedLokasiId = val),
                  ),
            const SizedBox(height: 16),

            ListTile(
              shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
              title: const Text('Waktu Mulai *'),
              subtitle: Text(_waktuMulai == null ? 'Belum diatur' : dateFormat.format(_waktuMulai!)),
              trailing: const Icon(Icons.calendar_month, color: Colors.green),
              onTap: () async {
                final dt = await _pickDateTime(_waktuMulai);
                if (dt != null) setState(() => _waktuMulai = dt);
              },
            ),
            const SizedBox(height: 16),

            ListTile(
              shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
              title: const Text('Waktu Selesai *'),
              subtitle: Text(_waktuSelesai == null ? 'Belum diatur' : dateFormat.format(_waktuSelesai!)),
              trailing: const Icon(Icons.calendar_month, color: Colors.green),
              onTap: () async {
                final dt = await _pickDateTime(_waktuSelesai ?? _waktuMulai);
                if (dt != null) setState(() => _waktuSelesai = dt);
              },
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isSaving ? null : _ajukanMeeting,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('AJUKAN JADWAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}