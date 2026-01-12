const String token = '69055b8f56eae7122d0a833f'; 
const String project = 'coopconnect';
const String appid = '6932be5d91d5fb3c91ad6d7b'; 
const String baseUrl = 'https://api.247go.app/v5/';

// Helper URL Gambar
String getFileUrl(String fileName) {
  // 1. Jika fileName kosong, kembalikan string kosong
  if (fileName.isEmpty) return '';
  
  // 2. Jika sudah berupa URL lengkap (misal dari internet), pakai langsung
  if (fileName.startsWith('http')) return fileName;

  // 3. Jika hanya nama file (hasil upload GoCloud), rangkai URL-nya
  // Format: https://files.247go.app/files/down/token/{token}/project/{project}/filename/{filename}
  return 'https://files.247go.app/files/down/token/$token/project/$project/filename/$fileName';
}