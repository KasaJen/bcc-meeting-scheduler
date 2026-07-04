import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .order('nama_dinas', ascending: true);
          
      if (mounted) {
        setState(() {
          _users = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat data user'), backgroundColor: Colors.red)
        );
        setState(() => _isLoading = false);
      }
    }
  }

void _showAddUserDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final namaDinasController = TextEditingController();
    
    String selectedRole = 'dinas'; 
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah User Baru', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: namaDinasController,
                      decoration: const InputDecoration(labelText: 'Nama Dinas / Instansi', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password (Minimal 6 karakter)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'dinas', child: Text('Dinas')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedRole = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (namaDinasController.text.isEmpty || emailController.text.isEmpty || passwordController.text.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Harap isi semua kolom!'), backgroundColor: Colors.red));
                            return;
                          }

                          setDialogState(() => isSaving = true);

                          try {
                            final res = await Supabase.instance.client.auth.admin.createUser(
                              AdminUserAttributes(
                                email: emailController.text.trim(),
                                password: passwordController.text,
                                emailConfirm: true, 
                              ),
                            );

                            final newUserId = res.user?.id;

                            if (newUserId != null) {
                              await Supabase.instance.client.from('profiles').insert({
                                'id': newUserId,
                                'nama_dinas': namaDinasController.text.trim(),
                                'nama_lengkap': namaDinasController.text.trim(),
                                'role': selectedRole, 
                              });

                              if (!context.mounted) return; 
                              
                              Navigator.pop(dialogContext);
                              _fetchUsers();
                              
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User berhasil ditambahkan!'), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Gagal membuat user: $e'), backgroundColor: Colors.red));
                          } finally {
                            if (dialogContext.mounted) setDialogState(() => isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: isSaving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

void _showEditUserDialog(Map<String, dynamic> user) {
    final namaDinasController = TextEditingController(text: user['nama_dinas']);
    final newPasswordController = TextEditingController(); 
    
    String selectedRole = user['role'] ?? 'dinas';
    bool isSaving = false;
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit User', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: namaDinasController,
                      decoration: const InputDecoration(labelText: 'Nama Dinas / Instansi', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'dinas', child: Text('Dinas')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedRole = val);
                      },
                    ),
                    const Divider(height: 30),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Reset Password',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password Baru (Opsional)', 
                        hintText: 'Kosongkan jika tidak diubah',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: isDeleting || isSaving
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: dialogContext,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus User?'),
                              content: const Text('User ini akan dihapus permanen. Jadwal rapat mereka akan tetap tersimpan (tanpa nama pemohon). Lanjutkan?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            setDialogState(() => isDeleting = true);
                            try {
                              await Supabase.instance.client.auth.admin.deleteUser(user['id']);
                              
                              if (!context.mounted) return;
                              Navigator.pop(dialogContext); 
                              _fetchUsers(); 
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User berhasil dihapus permanen!'), backgroundColor: Colors.green));
                            } catch (e) {
                              if (!dialogContext.mounted) return;
                              ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red));
                            } finally {
                              if (dialogContext.mounted) setDialogState(() => isDeleting = false);
                            }
                          }
                        },
                  icon: isDeleting 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                ),
                
                const Spacer(),

                TextButton(
                  onPressed: isSaving || isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                
                ElevatedButton(
                  onPressed: isSaving || isDeleting
                      ? null
                      : () async {
                          if (namaDinasController.text.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Nama Dinas tidak boleh kosong!'), backgroundColor: Colors.red));
                            return;
                          }

                          if (newPasswordController.text.isNotEmpty && newPasswordController.text.length < 6) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Password baru minimal 6 karakter!'), backgroundColor: Colors.red));
                            return;
                          }

                          setDialogState(() => isSaving = true);

                          try {
                            await Supabase.instance.client.from('profiles').update({
                              'nama_dinas': namaDinasController.text.trim(),
                              'nama_lengkap': namaDinasController.text.trim(),
                              'role': selectedRole,
                            }).eq('id', user['id']);

                            if (newPasswordController.text.isNotEmpty) {
                              await Supabase.instance.client.auth.admin.updateUserById(
                                user['id'],
                                attributes: AdminUserAttributes(password: newPasswordController.text),
                              );
                            }

                            if (!context.mounted) return;
                            
                            Navigator.pop(dialogContext);
                            _fetchUsers();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil diperbarui!'), backgroundColor: Colors.green));
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red));
                          } finally {
                            if (dialogContext.mounted) setDialogState(() => isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola User & Dinas', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final isRoleAdmin = user['role'] == 'admin';

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isRoleAdmin ? Colors.blue : Colors.green,
                      child: Icon(
                        isRoleAdmin ? Icons.admin_panel_settings : Icons.business,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(user['nama_dinas'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Role: ${user['role']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () {
                        _showEditUserDialog(user);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddUserDialog();
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}