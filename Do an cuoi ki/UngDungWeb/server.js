/* ============================================================================
   PHẦN MỀM ỨNG DỤNG CHO CÁC TRẠM — máy chủ ứng dụng
   ----------------------------------------------------------------------------
   Đây là tầng giữa (back end) trong mô hình ba tầng đã trình bày ở Chương II:

        Trình duyệt  ──HTTP──>  Node.js  ──TDS──>  SQL Server của site này
                                   │
                                   └── Linked Server ──> hai site còn lại

   Mọi thao tác ghi đều gọi THỦ TỤC đã có sẵn trong cơ sở dữ liệu, không viết
   câu INSERT/UPDATE trực tiếp. Lý do: thủ tục mới là nơi đặt giao tác, khoá và
   kiểm tra tồn kho. Nếu ứng dụng ghi thẳng vào bảng thì toàn bộ lớp bảo vệ đó
   bị đi vòng, và vai trò NhanVienKho cũng không có quyền ghi thẳng.
   ============================================================================ */
const express = require('express');
const sql = require('mssql');
const path = require('path');
const { SITE, site, cong, csdl } = require('./cauhinh');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'giaodien')));

let pool;

/* --- gọi thủ tục / câu lệnh, trả về mảng dòng ------------------------------ */
async function truyVan(cauLenh, thamSo = {}) {
  const req = pool.request();
  for (const [ten, gt] of Object.entries(thamSo)) req.input(ten, gt);
  const kq = await req.query(cauLenh);
  return kq.recordset || [];
}

/* Gói các tuyến lại cho gọn: lỗi nào cũng trả JSON, không để Express in ra
   trang HTML mặc định mà giao diện không đọc được.                          */
function tuyen(fn) {
  return async (req, res) => {
    try {
      res.json(await fn(req));
    } catch (e) {
      // Lỗi do thủ tục tự phát ra bằng RAISERROR là lỗi NGHIỆP VỤ, người dùng
      // cần đọc nguyên văn. Lỗi khác là sự cố kỹ thuật.
      res.status(400).json({ loi: e.message, soHieu: e.number || null });
    }
  };
}

/* ---------------------------- TRA CỨU ------------------------------------- */

app.get('/api/site', tuyen(async () => {
  const [tt] = await truyVan('EXEC dbo.sp_ThongTinSite');
  return { ...tt, maSite: SITE, tenMau: site.mau };
}));

app.get('/api/tonkho', tuyen(() =>
  truyVan(`SELECT t.MaVT, v.TenVT, v.DonViTinh, t.SoLuong, v.DonGia,
                  CAST(t.SoLuong * v.DonGia AS DECIMAL(18,0)) AS GiaTriTon,
                  v.MucTonToiThieu, t.NgayCapNhat,
                  CASE WHEN t.SoLuong < v.MucTonToiThieu THEN 1 ELSE 0 END AS ThieuHang
           FROM   dbo.TonKho t JOIN dbo.VatTu v ON v.MaVT = t.MaVT
           ORDER BY t.MaVT`)));

app.get('/api/tonkho-toanhethong', tuyen(() =>
  truyVan('EXEC dbo.sp_TonKhoToanHeThong_Site')));

app.get('/api/vattu', tuyen(() =>
  truyVan(`SELECT v.MaVT, v.TenVT, v.DonViTinh, v.DonGia, v.MucTonToiThieu,
                  v.MaNCC, n.TenNCC
           FROM dbo.VatTu v LEFT JOIN dbo.NhaCungCap n ON n.MaNCC = v.MaNCC
           ORDER BY v.MaVT`)));

app.get('/api/nhacungcap', tuyen(() =>
  truyVan('SELECT MaNCC, TenNCC, DiaChi, DienThoai FROM dbo.NhaCungCap ORDER BY MaNCC')));

app.get('/api/khokhac', tuyen(() => truyVan('EXEC dbo.sp_KhoKhac')));

app.get('/api/canhbao', tuyen(() => truyVan('EXEC dbo.sp_CanhBaoTonToiThieu')));

app.get('/api/lichsu', tuyen(() => truyVan('EXEC dbo.sp_LichSuChungTu @SoDong = 25')));

/* ---------------------------- GHI DỮ LIỆU --------------------------------- */

/* Dựng tham số kiểu bảng cho sp_NhapKho và sp_XuatKho. Kiểu này khai báo ở
   file 04, ứng dụng phải dựng đúng thứ tự cột thì SQL Server mới nhận.       */
function bangChiTiet(chiTiet) {
  const tvp = new sql.Table('dbo.ChiTietVatTu_Type');
  tvp.columns.add('MaVT',    sql.Char(5),        { nullable: false });
  tvp.columns.add('SoLuong', sql.Int,            { nullable: false });
  tvp.columns.add('DonGia',  sql.Decimal(14, 0), { nullable: false });
  for (const d of chiTiet) tvp.rows.add(d.maVT, Number(d.soLuong), Number(d.donGia));
  return tvp;
}

app.post('/api/nhapkho', tuyen(async (req) => {
  const { maNCC, nguoiLap, chiTiet } = req.body;
  if (!chiTiet || !chiTiet.length) throw new Error('Phiếu nhập phải có ít nhất một dòng.');

  const r = pool.request();
  r.input('MaNCC', sql.Char(5), maNCC);
  r.input('NguoiLap', sql.NVarChar(50), nguoiLap || 'Ứng dụng trạm');
  r.input('ChiTiet', bangChiTiet(chiTiet));
  r.output('MaPN', sql.Char(7));
  const kq = await r.execute('dbo.sp_NhapKho');
  return { maPhieu: kq.output.MaPN, thongBao: 'Đã nhập kho thành công' };
}));

app.post('/api/xuatkho', tuyen(async (req) => {
  const { nguoiNhan, nguoiLap, chiTiet } = req.body;
  if (!chiTiet || !chiTiet.length) throw new Error('Phiếu xuất phải có ít nhất một dòng.');

  const r = pool.request();
  r.input('NguoiNhan', sql.NVarChar(100), nguoiNhan);
  r.input('NguoiLap', sql.NVarChar(50), nguoiLap || 'Ứng dụng trạm');
  r.input('ChiTiet', bangChiTiet(chiTiet));
  r.output('MaPX', sql.Char(7));
  const kq = await r.execute('dbo.sp_XuatKho');
  return { maPhieu: kq.output.MaPX, thongBao: 'Đã xuất kho thành công' };
}));

/* Điều chuyển — nghiệp vụ trọng tâm của đề tài.
   Tham số gayLoi=true bật cờ @GayLoiThuNghiem của thủ tục, khiến giao tác hỏng
   NGAY SAU KHI đã trừ kho nguồn nhưng TRƯỚC KHI cộng cho kho đích. Dùng để
   biểu diễn tính nhất quán: MS DTC phải quay lui cả hai máy chủ.             */
app.post('/api/dieuchuyen', tuyen(async (req) => {
  const { maKhoDich, maVT, soLuong, nguoiLap, ghiChu, gayLoi } = req.body;

  const r = pool.request();
  r.input('MaKhoDich', sql.Char(5), maKhoDich);
  r.input('MaVT', sql.Char(5), maVT);
  r.input('SoLuong', sql.Int, Number(soLuong));
  r.input('NguoiLap', sql.NVarChar(50), nguoiLap || 'Ứng dụng trạm');
  r.input('GhiChu', sql.NVarChar(200), ghiChu || null);
  r.input('GayLoiThuNghiem', sql.Bit, gayLoi ? 1 : 0);
  r.output('MaDC', sql.Char(6));
  const kq = await r.execute('dbo.sp_DieuChuyenVatTu');
  return {
    maPhieu: kq.output.MaDC,
    thongBao: `Điều chuyển thành công ${soLuong} đơn vị ${maVT} sang ${maKhoDich}`,
  };
}));

/* Ảnh chụp tồn kho hai site trước/sau khi điều chuyển, để giao diện bày ra
   cạnh nhau cho người xem thấy con số thay đổi.                             */
app.get('/api/anhchup/:maVT', tuyen((req) =>
  truyVan('EXEC dbo.sp_TonKhoToanHeThong_Site @MaVT = @vt', { vt: req.params.maVT })));

/* ---------------------------- KHỞI ĐỘNG ----------------------------------- */
(async () => {
  try {
    pool = await new sql.ConnectionPool(csdl).connect();
    const [tt] = await truyVan('EXEC dbo.sp_ThongTinSite');

    app.listen(cong, () => {
      console.log('');
      console.log('  ============================================================');
      console.log(`   PHẦN MỀM TRẠM — ${tt.TenKho}  (${tt.MaKho})`);
      console.log('  ============================================================');
      console.log(`   Máy chủ CSDL : ${tt.MayChu}   cổng ${csdl.port}`);
      console.log(`   Cơ sở dữ liệu: ${tt.CSDL}`);
      console.log(`   Giao thức    : ${tt.GiaoThuc}`);
      console.log('');
      console.log(`   Mở trình duyệt:  http://localhost:${cong}`);
      console.log('');
    });
  } catch (e) {
    console.error('\n  KHÔNG NỐI ĐƯỢC CƠ SỞ DỮ LIỆU\n');
    console.error('  ' + e.message + '\n');
    console.error(`  Đang thử nối: ${csdl.server},${csdl.port}  →  ${csdl.database}`);
    console.error('  Kiểm tra lần lượt:');
    console.error('    1. Dịch vụ SQL Server của site này đang chạy chưa');
    console.error('    2. Đã chạy BatTCPIP_VaFirewall.ps1 để mở cổng chưa');
    console.error('    3. Mật khẩu sa có đúng là 123 không');
    console.error('    4. Đã chạy SQL\\12_ThuTuc_ChoUngDung.sql trên site này chưa\n');
    process.exit(1);
  }
})();
