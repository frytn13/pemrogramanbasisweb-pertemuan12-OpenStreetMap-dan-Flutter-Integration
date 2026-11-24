# Jawaban Pertanyaan Diskusi Pertemuan 12

**Mata Kuliah:** Pemrograman Basis Mobile

**Topik:** Aplikasi Pengiriman Barang Berbasis OpenStreetMap dengan Algoritma Dijkstra pada Flutter Android

**Program Studi:** Informatika

**Universitas:** Universitas Katolik Musi Charitas

---

## 1. Mengapa Dijkstra biasa dari satu source ke semua node belum cukup untuk menentukan urutan kunjungan banyak tujuan?

Algoritma Dijkstra biasa menentukan jalur terpendek dari satu titik awal menuju setiap node. Namun, algoritma tersebut tidak memperhitungkan urutan kunjungan yang harus melewati seluruh tujuan dalam satu perjalanan.

Pada aplikasi Smart Delivery Dijkstra, setiap keputusan kunjungan dapat memengaruhi total waktu perjalanan berikutnya. Mengunjungi tujuan terdekat terlebih dahulu belum tentu menghasilkan total waktu tempuh paling minimum.

Untuk mengatasi masalah tersebut, aplikasi menggunakan Dijkstra pada state graph yang menyimpan currentNode dan visitedMask. Pendekatan ini memungkinkan algoritma mencari urutan kunjungan dengan total waktu tempuh minimum hingga seluruh tujuan dikunjungi.

## 2. Apa fungsi visitedMask pada state graph?

visitedMask berfungsi untuk mencatat tujuan yang telah dikunjungi menggunakan representasi bitmask. Setiap bit mewakili satu titik tujuan. Nilai 0 menunjukkan tujuan belum dikunjungi, sedangkan nilai 1 menunjukkan tujuan sudah dikunjungi.

Sebagai contoh, pada pengiriman dengan tiga tujuan:

| visitedMask | Keterangan                       |
| ----------- | -------------------------------- |
| 000         | Belum ada tujuan yang dikunjungi |
| 001         | Tujuan 1 sudah dikunjungi        |
| 010         | Tujuan 2 sudah dikunjungi        |
| 101         | Tujuan 1 dan 3 sudah dikunjungi  |
| 111         | Seluruh tujuan sudah dikunjungi  |

Algoritma menggunakan visitedMask untuk menghindari pemilihan ulang tujuan yang telah dikunjungi dan menentukan kapan seluruh tujuan berhasil dikunjungi.

## 3. Mengapa bobot yang digunakan adalah duration, bukan sekadar jarak garis lurus?

Jarak garis lurus hanya menghitung jarak langsung antara dua koordinat tanpa mempertimbangkan kondisi jaringan jalan. Kendaraan harus mengikuti jalan yang tersedia, termasuk arah jalan, persimpangan, pembatasan akses, dan karakteristik jalan.

Aplikasi menggunakan duration dari OSRM Table Service karena nilai tersebut memberikan estimasi waktu tempuh berdasarkan jaringan jalan OpenStreetMap.

Dengan menggunakan durasi sebagai bobot, algoritma Dijkstra dapat menentukan urutan pengiriman yang meminimalkan estimasi total waktu perjalanan. Hasil tersebut lebih relevan untuk kebutuhan pengiriman barang dibandingkan perhitungan jarak garis lurus.

Durasi OSRM pada aplikasi ini merupakan estimasi berdasarkan profil routing, bukan informasi kemacetan secara real-time.

## 4. Apa perbedaan peran OpenStreetMap, flutter_map, OSRM, dan Dijkstra pada aplikasi ini?

Keempat komponen memiliki fungsi yang berbeda dan saling terintegrasi dalam aplikasi.

| Komponen      | Peran                                                                                                  |
| ------------- | ------------------------------------------------------------------------------------------------------ |
| OpenStreetMap | Menyediakan data geografis dan jaringan jalan sebagai dasar peta dan routing.                          |
| flutter_map   | Menampilkan peta, marker lokasi, polyline rute, serta mengatur interaksi dan kamera peta pada Flutter. |
| OSRM          | Menyediakan matriks durasi, matriks jarak, dan geometri rute berdasarkan jaringan jalan.               |
| Dijkstra      | Menentukan urutan kunjungan seluruh tujuan dengan total bobot waktu tempuh minimum pada state graph.   |

Alur kerja dimulai ketika pengguna menentukan lokasi awal melalui GPS dan menambahkan titik tujuan pada peta. OSRM menyediakan matriks waktu tempuh antar titik, kemudian Dijkstra menentukan urutan kunjungan optimal.

Setelah urutan diperoleh, aplikasi meminta geometri rute melalui OSRM Route Service. flutter_map menampilkan geometri tersebut sebagai polyline pada peta OpenStreetMap.

## 5. Mengapa kompleksitas meningkat cepat ketika jumlah tujuan bertambah?

Peningkatan kompleksitas terjadi karena setiap state menyimpan posisi saat ini dan kombinasi tujuan yang telah dikunjungi.

Jika terdapat N tujuan, visitedMask memiliki 2^N kemungkinan kombinasi. Sementara itu, currentNode memiliki hingga N + 1 kemungkinan posisi.

Batas atas jumlah state dapat dinyatakan sebagai:

(N + 1) × 2^N

Contoh pertumbuhan jumlah state:

| Jumlah tujuan | Kombinasi visitedMask | Batas atas jumlah state |
| ------------: | --------------------: | ----------------------: |
|             3 |                     8 |                      32 |
|             4 |                    16 |                      80 |
|             5 |                    32 |                     192 |
|             6 |                    64 |                     448 |
|             7 |                   128 |                   1.024 |
|             8 |                   256 |                   2.304 |

Jumlah tersebut merupakan batas atas teoretis. Tidak semua kombinasi state dapat dicapai dalam implementasi algoritma.

Pertumbuhan eksponensial meningkatkan kebutuhan waktu komputasi dan memori. Aplikasi membatasi jumlah tujuan maksimal delapan agar proses optimasi tetap dapat dijalankan dengan baik pada smartphone.

Untuk sistem pengiriman dengan puluhan atau ratusan tujuan, diperlukan algoritma atau solver Vehicle Routing Problem yang dirancang untuk skala lebih besar.

## 6. Apa risiko memakai public tile server atau public routing server untuk aplikasi komersial berskala besar?

Public tile server OpenStreetMap dan public routing server OSRM memiliki keterbatasan sumber daya serta kebijakan penggunaan.

Penggunaan pada aplikasi komersial berskala besar dapat menimbulkan beberapa risiko:

1. Pembatasan atau penolakan permintaan akibat trafik yang terlalu tinggi.
2. Keterlambatan dalam memuat peta dan menghitung rute.
3. Gangguan layanan yang menyebabkan fitur aplikasi tidak dapat digunakan.
4. Tidak adanya jaminan ketersediaan layanan atau Service Level Agreement yang sesuai kebutuhan bisnis.
5. Pelanggaran kebijakan penggunaan apabila aplikasi melakukan permintaan berlebihan atau bulk download yang tidak diizinkan.

Penggunaan server publik pada praktikum sesuai untuk pengujian ringan selama mengikuti kebijakan layanan.

Untuk aplikasi produksi, pengembang sebaiknya menggunakan penyedia layanan peta dan routing yang sesuai dengan kebutuhan, atau membangun infrastruktur tile server dan routing server sendiri.

## 7. Bagaimana aplikasi dapat dikembangkan menjadi sistem kurir real-time dengan backend dan database online?

Aplikasi dapat dikembangkan dengan menambahkan backend sebagai pusat pengelolaan data pengiriman dan database online untuk menyimpan informasi secara terpusat.

Pengembangan tersebut dapat dilakukan melalui beberapa tahapan:

1. Membuat backend REST API menggunakan Laravel atau teknologi backend lainnya.
2. Menggunakan database seperti MySQL atau PostgreSQL untuk menyimpan data pengguna, kurir, penerima, paket, lokasi, dan riwayat pengiriman.
3. Menambahkan autentikasi dan pembagian hak akses antara administrator, kurir, dan pelanggan.
4. Mengirim koordinat GPS kurir secara berkala dari aplikasi Flutter ke backend.
5. Menggunakan WebSocket untuk memperbarui lokasi kurir dan status pengiriman secara real-time.
6. Menyediakan dashboard administrator untuk memantau posisi kurir dan progres pengiriman.
7. Menambahkan notifikasi ketika paket sedang dikirim atau telah diterima.
8. Menggunakan HTTPS, autentikasi API, serta pembatasan hak akses untuk melindungi data pengguna.
9. Mengintegrasikan layanan routing yang sesuai untuk menangani kebutuhan optimasi pengiriman berskala besar.

Pada pengembangan tersebut, local storage tetap dapat digunakan untuk menyimpan data sementara ketika koneksi internet tidak tersedia. Data kemudian disinkronkan kembali dengan backend setelah perangkat terhubung ke internet.

Dengan arsitektur tersebut, administrator dapat memantau aktivitas pengiriman, kurir dapat memperbarui status paket, dan pelanggan dapat mengetahui perkembangan pengiriman secara real-time.

---

## Referensi

Hermawan, L. (2026). Modul Praktikum Pertemuan 12: Aplikasi Pengiriman Barang Berbasis OpenStreetMap dengan Algoritma Dijkstra pada Flutter Android. Program Studi Informatika, Universitas Katolik Musi Charitas.

Bagian modul yang digunakan:

- Bagian 1: Gambaran Umum Praktikum.
- Bagian 4: Arsitektur Sistem.
- Bagian 6: OpenStreetMap, Attribution, dan Penggunaan yang Bertanggung Jawab.
- Bagian 7: Konsep Dijkstra untuk Banyak Tujuan.
- Bagian 22: Kompleksitas dan Batas Jumlah Tujuan.
- Bagian 25: Tugas Mandiri.
- Bagian 27: Pertanyaan Diskusi.
- Bagian 28: Referensi Teknis.
