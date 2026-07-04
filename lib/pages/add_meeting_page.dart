import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AddMeetingPage extends StatefulWidget {
  final Map<String, dynamic>? existingMeeting;

  const AddMeetingPage({super.key, this.existingMeeting});

  @override
  State<AddMeetingPage> createState() => _AddMeetingPageState();
}

class _AddMeetingPageState extends State<AddMeetingPage> {
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _instansiController = TextEditingController();
  
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

    if (widget.existingMeeting != null) {
      _judulController.text = widget.existingMeeting!['judul'];
      _deskripsiController.text = widget.existingMeeting!['deskripsi'] ?? '';
      _instansiController.text = widget.existingMeeting!['nama_instansi_manual'] ?? ''; // Load data manual
      _waktuMulai = DateTime.parse(widget.existingMeeting!['waktu_mulai']).toLocal();
      _waktuSelesai = DateTime.parse(widget.existingMeeting!['waktu_selesai']).toLocal();
      _selectedLokasiId = widget.existingMeeting!['lokasi_id'];
    }
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    _instansiController.dispose();
    super.dispose();
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
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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

  Future<void> _simpanMeeting() async {
    if (_judulController.text.trim().isEmpty || _waktuMulai == null || _waktuSelesai == null || _selectedLokasiId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap lengkapi semua data wajib!'), backgroundColor: Colors.red));
      return;
    }

    if (_waktuSelesai!.isBefore(_waktuMulai!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Waktu selesai tidak boleh lebih awal dari waktu mulai!'), backgroundColor: Colors.red));
      return;
    }

    final isCollision = await _isCollision(
      _selectedLokasiId!,
      _waktuMulai!,
      _waktuSelesai!,
      excludeMeetingId: widget.existingMeeting?['id'],
    );

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
      final data = {
        'judul': _judulController.text.trim(),
        'deskripsi': _deskripsiController.text.trim(),
        'nama_instansi_manual': _instansiController.text.trim(),
        'waktu_mulai': _waktuMulai!.toUtc().toIso8601String(),
        'waktu_selesai': _waktuSelesai!.toUtc().toIso8601String(),
        'lokasi_id': _selectedLokasiId,
      };

      if (widget.existingMeeting != null) {
        await Supabase.instance.client.from('meetings').update(data).eq('id', widget.existingMeeting!['id']);
      } else {
        data['requested_by'] = userId;
        data['approved_by'] = userId; 
        data['status'] = 'approved';
        await Supabase.instance.client.from('meetings').insert(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.existingMeeting != null ? 'Jadwal diperbarui!' : 'Jadwal ditambahkan!'), backgroundColor: Colors.green)
      );
      Navigator.pop(context); 
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan jadwal meeting.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy, HH:mm');
    final isEdit = widget.existingMeeting != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Jadwal Meeting' : 'Tambah Jadwal Meeting'),
        backgroundColor: Colors.blue,
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
            // INPUT BARU
            TextField(
              controller: _instansiController,
              decoration: const InputDecoration(
                labelText: 'Nama Dinas/Instansi Terkait (Opsional)', 
                border: OutlineInputBorder(),
              ),
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
              trailing: const Icon(Icons.calendar_month, color: Colors.blue),
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
              trailing: const Icon(Icons.calendar_month, color: Colors.blue),
              onTap: () async {
                final dt = await _pickDateTime(_waktuSelesai ?? _waktuMulai);
                if (dt != null) setState(() => _waktuSelesai = dt);
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _simpanMeeting,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(isEdit ? 'SIMPAN PERUBAHAN' : 'SIMPAN JADWAL', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}