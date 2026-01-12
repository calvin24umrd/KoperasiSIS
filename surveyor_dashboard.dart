import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'loan_model.dart';
import 'user_model.dart';
import 'utils.dart';
import 'data_service.dart';
import 'survey_form.dart';

class TaskItem {
  final LoanModel loan;
  final UserModel user;
  TaskItem({required this.loan, required this.user});
}

class SurveyorDashboard extends StatefulWidget {
  const SurveyorDashboard({Key? key}) : super(key: key);
  @override
  State<SurveyorDashboard> createState() => _SurveyorDashboardState();
}

class _SurveyorDashboardState extends State<SurveyorDashboard> {
  List<TaskItem> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    // Ambil semua data loans dan users
    final allLoans = await AppRepository().getAllLoans();
    final allUsers = await AppRepository().getAllUsers();

    // Buat map userId ke UserModel
    final userMap = {for (var u in allUsers) u.id: u};

    if (mounted) {
      setState(() {
        // FILTER: Hanya tampilkan yang statusnya 'surveyed' dan belum ada skor survey (belum disurvey)
        final surveyedLoans = allLoans.where((l) => l.status == 'surveyed' && l.score == 0).toList();
        _tasks = surveyedLoans.map((loan) {
          final user = userMap[loan.userId];
          return user != null ? TaskItem(loan: loan, user: user) : null;
        }).whereType<TaskItem>().toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      appBar: AppBar(
        title: const Text("Tugas Survey Lapangan"),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), 
            onPressed: _loadTasks,
            tooltip: "Refresh Data",
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red), 
            onPressed: () => Utils.confirmLogout(context, auth)
          )
        ]
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _tasks.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 20),
                  const Text("Tidak ada tugas survey saat ini.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ) 
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _tasks.length,
              itemBuilder: (ctx, i) {
                final task = _tasks[i];
                return GestureDetector(
                  onTap: () {
                    // Tampilkan detail member
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Detail Member"),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (task.user.selfieImage != null)
                                Center(
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundImage: NetworkImage(task.user.selfieImage!),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Text("Nama: ${task.user.name}"),
                              Text("NIK: ${task.user.nik}"),
                              Text("Telepon: ${task.user.phone}"),
                              Text("Alamat: ${task.user.address}"),
                              Text("Alamat Kantor: ${task.user.addressOffice}"),
                              Text("Pekerjaan: ${task.user.job}"),
                              Text("Bergabung: ${task.user.joinDate.toLocal().toString().split(' ')[0]}"),
                              if (task.user.ktpImage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Foto KTP:"),
                                      const SizedBox(height: 5),
                                      Image.network(task.user.ktpImage!, height: 100, fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 100,
                                            width: double.infinity,
                                            color: Colors.grey[200],
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: const [
                                                Icon(Icons.broken_image, color: Colors.grey),
                                                Text("Gagal memuat gambar", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                                           
                                    
                                    ],
                                    
                                  ),
                                 ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Tutup"),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 15),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(15),
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundImage: task.user.selfieImage != null ? NetworkImage(task.user.selfieImage!) : null,
                        backgroundColor: task.user.selfieImage == null ? Colors.deepPurple.withOpacity(0.1) : null,
                        child: task.user.selfieImage == null ? const Icon(Icons.person, color: Colors.deepPurple) : null,
                      ),
                      title: Text("Rp ${Utils.formatCurrency(task.loan.amount)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Nama: ${task.user.name}"),
                          Text("NIK: ${task.user.nik}"),
                          Text("Tujuan: ${task.loan.purpose}"),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          // Buka Form Survey
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SurveyForm(loanId: task.loan.id))
                          ).then((_) => _loadTasks()); // Refresh setelah balik
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                        child: const Text("SURVEY", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}