/* ============================================================================
   CẤU HÌNH PHẦN MỀM TRẠM
   ----------------------------------------------------------------------------
   Mỗi trạm chạy MỘT bản phần mềm này, nối vào CSDL của chính kho mình.
   Chọn trạm bằng biến môi trường SITE:

        set SITE=KHO_B && node server.js

   Hoặc dùng sẵn ba file  CHAY_KHO_A.bat / CHAY_KHO_B.bat / CHAY_KHO_C.bat

   ----------------------------------------------------------------------------
   KHI BA SITE NẰM TRÊN BA MÁY THẬT

   Đặt thêm biến DIACHI là IP ảo ZeroTier của máy đang chạy, ví dụ:

        set SITE=KHO_B && set DIACHI=10.91.229.51 && node server.js

   Không đặt thì mặc định 'localhost' - đúng cho trường hợp ba thể hiện nằm
   chung một máy.
   ============================================================================ */

const SITE = (process.env.SITE || 'KHO_A').toUpperCase();

const CAC_SITE = {
  KHO_A: { db: 'KhoA', cong: 1440, ten: 'Kho Trung tâm',  mau: '#1f6feb' },
  KHO_B: { db: 'KhoB', cong: 1441, ten: 'Kho Miền Bắc',   mau: '#1a7f37' },
  KHO_C: { db: 'KhoC', cong: 1442, ten: 'Kho Miền Nam',   mau: '#9a6700' },
};

if (!CAC_SITE[SITE]) {
  console.error(`\n  SITE='${SITE}' không hợp lệ. Chỉ nhận KHO_A, KHO_B hoặc KHO_C.\n`);
  process.exit(1);
}

const site = CAC_SITE[SITE];

module.exports = {
  SITE,
  site,
  cong: Number(process.env.PORT) || 3000 + Number(SITE.slice(-1).charCodeAt(0) - 64),
  csdl: {
    server: process.env.DIACHI || 'localhost',
    port: site.cong,
    database: site.db,
    user: process.env.TAIKHOAN || 'sa',
    password: process.env.MATKHAU || '123',
    options: {
      // Lab không có chứng chỉ do CA cấp nên phải chấp nhận chứng chỉ tự ký.
      // Môi trường thật thì dùng chứng chỉ hợp lệ và bỏ dòng trustServerCertificate.
      encrypt: false,
      trustServerCertificate: true,
      enableArithAbort: true,
    },
    pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
    requestTimeout: 60000,   // giao tác phân tán qua mạng ảo có thể chậm
  },
};
