import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManageRequestsPage extends StatefulWidget {
  const ManageRequestsPage({super.key});

  @override
  State<ManageRequestsPage> createState() => _ManageRequestsPageState();
}

class _ManageRequestsPageState extends State<ManageRequestsPage> {
  List<dynamic> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingRequests();
  }

  Future<void> _fetchPendingRequests() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('meetings')
          .select('*, locations(nama_lokasi), profiles!meetings_requested_by_fkey(nama_dinas)')
          .eq('status', 'pending')
          .isFilter('deleted_at', null)
          .order('created_at');

      if (mounted) {
        setState(() {
          _pendingRequests = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memuat daftar pengajuan'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> req, String newStatus) async {
    try {
      final adminId = Supabase.instance.client.auth.currentUser!.id;
      
      final updateData = {
        'status': newStatus,
      };

      if (newStatus == 'approved') {
        updateData['approved_by'] = adminId;
      }

      await Supabase.instance.client.from('meetings').update(updateData).eq('id', req['id']);
      
      final statusTeks = newStatus == 'approved' ? 'disetujui' : 'ditolak';
      await Supabase.instance.client.from('notifications').insert({
        'user_id': req['requested_by'], // ID Dinas pembuat request
        'judul': newStatus == 'approved' ? 'Jadwal Disetujui' : 'Jadwal Ditolak',
        'pesan': 'Pengajuan jadwal "${req['judul']}" Anda telah $statusTeks oleh Admin.',
      });
      
      _fetchPendingRequests(); 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'approved' ? 'Jadwal Diterima!' : 'Jadwal Ditolak!'),
            backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terjadi kesalahan'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Persetujuan Jadwal'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRequests.isEmpty
              ? const Center(child: Text('Tidak ada pengajuan jadwal baru.', style: TextStyle(fontSize: 16, color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _pendingRequests.length,
                  itemBuilder: (context, index) {
                    final req = _pendingRequests[index];
                    final namaRuangan = req['locations'] != null ? req['locations']['nama_lokasi'] : 'Lokasi Dihapus';
                    final namaDinas = req['profiles'] != null ? req['profiles']['nama_dinas'] : 'User Tidak Diketahui';
                    
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(req['judul'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                                  child: const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const Divider(),
                            Text('Pengaju: $namaDinas', style: const TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text('Lokasi: $namaRuangan'),
                            const SizedBox(height: 4),
                            Text('Mulai: ${dateFormat.format(DateTime.parse(req['waktu_mulai']).toLocal())}'),
                            Text('Selesai: ${dateFormat.format(DateTime.parse(req['waktu_selesai']).toLocal())}'),
                            const SizedBox(height: 4),
                            Text('Catatan: ${req['deskripsi'] ?? "-"}'),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _updateStatus(req, 'rejected'),
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  label: const Text('Tolak', style: TextStyle(color: Colors.red)),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _updateStatus(req, 'approved'),
                                  icon: const Icon(Icons.check, color: Colors.white),
                                  label: const Text('Terima'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}