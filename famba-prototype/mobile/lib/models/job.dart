class Job {
  final String id;
  final String status;
  final Map<String, dynamic>? driver;
  Job({required this.id, required this.status, this.driver});
  factory Job.fromJson(Map<String,dynamic> j) => Job(
    id: j['id'], status: j['status'], driver: j['driver']);
}
