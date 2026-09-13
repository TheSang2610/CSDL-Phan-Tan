/* Giao diện phần mềm trạm. Không dùng thư viện ngoài — tải nhanh và chạy được
   cả khi máy không có Internet, điều rất hay gặp trong phòng thực hành.      */

let SITE = {};          // thông tin site đang nối
let DS_VATTU = [];      // danh mục, dùng chung cho nhiều ô chọn

const $ = (id) => document.getElementById(id);
const so = (n) => Number(n).toLocaleString('vi-VN');

async function goi(duongDan, tuyChon) {
  const r = await fetch(duongDan, tuyChon);
  const d = await r.json();
  if (!r.ok) throw new Error(d.loi || 'Lỗi không rõ');
  return d;
}

function bao(o, loai, tieuDe, noiDung) {
  $(o).innerHTML = `<div class="bao ${loai}"><b>${tieuDe}</b>${noiDung || ''}</div>`;
}

/* --------------------------- dựng bảng HTML ------------------------------- */
function dungBang(cot, dong, tuyChon = {}) {
  if (!dong.length) return '<div class="bao tin"><b>Chưa có dữ liệu</b></div>';
  const th = cot.map(c => `<th class="${c.so ? 'so' : ''}">${c.ten}</th>`).join('');
  const tr = dong.map(d => {
    const lop = tuyChon.lopDong ? tuyChon.lopDong(d) : '';
    const td = cot.map(c => {
      const v = c.hien ? c.hien(d) : (d[c.khoa] ?? '');
      return `<td class="${c.so ? 'so' : ''}">${v}</td>`;
    }).join('');
    return `<tr class="${lop}">${td}</tr>`;
  }).join('');
  return `<div class="bang-boc"><table><thead><tr>${th}</tr></thead><tbody>${tr}</tbody></table></div>`;
}

const ngay = (v) => v ? new Date(v).toLocaleString('vi-VN', {
  day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit',
}) : '';

/* ------------------------------ khởi động --------------------------------- */
async function khoiDong() {
  SITE = await goi('/api/site');
  document.documentElement.style.setProperty('--mau-site', SITE.tenMau);
  $('tenKho').textContent = `${SITE.TenKho}  ·  ${SITE.MaKho}`;
  $('diaChi').textContent = SITE.DiaChi;
  $('thongSo').innerHTML = `
    <div><span>Máy chủ</span><b>${SITE.MayChu}</b></div>
    <div><span>Cơ sở dữ liệu</span><b>${SITE.CSDL}</b></div>
    <div><span>Giao thức</span><b>${SITE.GiaoThuc}${SITE.Cong ? ' : ' + SITE.Cong : ''}</b></div>
    <div><span>Dòng tồn kho</span><b>${SITE.SoDongTonKho}</b></div>`;
  document.title = `${SITE.MaKho} — Phần mềm trạm`;

  await Promise.all([taiTonKho(), taiDanhMuc(), taiKhoKhac()]);
  themDong('dongNhap', true);
  themDong('dongXuat', false);
}

/* ------------------------------- tổng quan -------------------------------- */
async function taiTonKho() {
  const [ds, cb] = await Promise.all([goi('/api/tonkho'), goi('/api/canhbao')]);

  $('canhBao').innerHTML = cb.length
    ? `<div class="bao loi"><b>${cb.length} vật tư đang dưới mức tồn tối thiểu</b>
       ${cb.map(x => `${x.MaVT} ${x.TenVT}: còn ${so(x.TonHienCo)}, cần ${so(x.MucTonToiThieu)}
         (thiếu ${so(x.ThieuHut)})`).join(' · ')}</div>`
    : '<div class="bao ok"><b>Mọi vật tư đều trên mức tồn tối thiểu</b></div>';

  $('bangTonKho').innerHTML = dungBang([
    { ten: 'Mã', khoa: 'MaVT' },
    { ten: 'Tên vật tư', khoa: 'TenVT' },
    { ten: 'ĐVT', khoa: 'DonViTinh' },
    { ten: 'Tồn', so: true, hien: d => so(d.SoLuong) },
    { ten: 'Tối thiểu', so: true, hien: d => so(d.MucTonToiThieu) },
    { ten: 'Đơn giá', so: true, hien: d => so(d.DonGia) },
    { ten: 'Giá trị tồn', so: true, hien: d => so(d.GiaTriTon) },
    { ten: 'Cập nhật', hien: d => ngay(d.NgayCapNhat) },
  ], ds, { lopDong: d => d.ThieuHang ? 'thieu' : '' });
}

/* --------------------------- toàn hệ thống -------------------------------- */
async function taiToanHeThong() {
  $('bangToanHeThong').innerHTML = '<div class="bao tin"><b>Đang gộp dữ liệu ba site…</b></div>';
  try {
    const ds = await goi('/api/tonkho-toanhethong');
    const tong = ds.reduce((a, b) => a + Number(b.GiaTriTon || 0), 0);
    $('bangToanHeThong').innerHTML = dungBang([
      { ten: 'Kho', khoa: 'TenKho' },
      { ten: 'Mã kho', khoa: 'MaKho' },
      { ten: 'Mã VT', khoa: 'MaVT' },
      { ten: 'Tên vật tư', khoa: 'TenVT' },
      { ten: 'Tồn', so: true, hien: d => so(d.SoLuong) },
      { ten: 'Tối thiểu', so: true, hien: d => so(d.MucTonToiThieu) },
      { ten: 'Giá trị tồn', so: true, hien: d => so(d.GiaTriTon) },
      { ten: 'Tình trạng', hien: d => d.ThieuHang
          ? '<span class="the-nho the-do">Thiếu hàng</span>'
          : '<span class="the-nho the-xanh">Đủ</span>' },
    ], ds, { lopDong: d => d.MaKho === SITE.MaKho ? 'site-nay' : '' })
    + `<p class="ghichu">${ds.length} dòng từ ba site · tổng giá trị tồn
       <b>${so(tong)}</b> đồng · dòng nền xanh là dữ liệu của chính trạm này.</p>`;
  } catch (e) {
    bao('bangToanHeThong', 'loi', 'Không gộp được dữ liệu ba site', e.message
      + '<br>Kiểm tra Linked Server và xem hai site kia có đang chạy không.');
  }
}

/* ------------------------------ danh mục ---------------------------------- */
async function taiDanhMuc() {
  const [vt, ncc] = await Promise.all([goi('/api/vattu'), goi('/api/nhacungcap')]);
  DS_VATTU = vt;

  $('danDanhMuc').innerHTML = SITE.MaKho === 'KHO_A'
    ? `Trạm này là <b>Publisher</b>. Danh mục sửa ở đây sẽ được nhân bản xuống hai
       kho còn lại sau khoảng 15–20 giây.`
    : `Trạm này là <b>Subscriber</b>. Danh mục ở đây là <b>bản sao chỉ đọc</b> —
       trigger sẽ chặn nếu cố sửa. Muốn đổi thì phải sửa tại Kho Trung tâm.`;

  $('bangVatTu').innerHTML = dungBang([
    { ten: 'Mã', khoa: 'MaVT' },
    { ten: 'Tên vật tư', khoa: 'TenVT' },
    { ten: 'ĐVT', khoa: 'DonViTinh' },
    { ten: 'Đơn giá', so: true, hien: d => so(d.DonGia) },
    { ten: 'Tồn tối thiểu', so: true, hien: d => so(d.MucTonToiThieu) },
    { ten: 'Nhà cung cấp', khoa: 'TenNCC' },
  ], vt);

  $('bangNCC').innerHTML = dungBang([
    { ten: 'Mã', khoa: 'MaNCC' },
    { ten: 'Tên nhà cung cấp', khoa: 'TenNCC' },
    { ten: 'Địa chỉ', khoa: 'DiaChi' },
    { ten: 'Điện thoại', khoa: 'DienThoai' },
  ], ncc);

  $('nhapNCC').innerHTML = ncc.map(n =>
    `<option value="${n.MaNCC}">${n.MaNCC} — ${n.TenNCC}</option>`).join('');
  $('chuyenVT').innerHTML = vt.map(v =>
    `<option value="${v.MaVT}">${v.MaVT} — ${v.TenVT}</option>`).join('');
}

async function taiKhoKhac() {
  const ds = await goi('/api/khokhac');
  $('chuyenKho').innerHTML = ds.map(k =>
    `<option value="${k.MaKho}">${k.TenKho} (${k.MaKho})</option>`).join('');
}

/* ------------------------- dòng chi tiết phiếu ---------------------------- */
function themDong(oChua, coDonGia) {
  const d = document.createElement('div');
  d.className = 'dong-ct';
  const chon = DS_VATTU.map(v =>
    `<option value="${v.MaVT}" data-gia="${v.DonGia}">${v.MaVT} — ${v.TenVT}</option>`).join('');
  d.innerHTML = `
    <label>Vật tư<select class="ct-vt">${chon}</select></label>
    <label>Số lượng<input class="ct-sl" type="number" min="1" value="10"></label>
    <label>Đơn giá<input class="ct-gia" type="number" min="0" value="${DS_VATTU[0]?.DonGia || 0}"
      ${coDonGia ? '' : 'readonly'}></label>
    <button type="button" class="xoa" title="Xoá dòng">✕</button>`;
  d.querySelector('.xoa').onclick = () => d.remove();
  // đổi vật tư thì đơn giá nhảy theo danh mục, đỡ phải gõ tay
  d.querySelector('.ct-vt').onchange = (e) => {
    d.querySelector('.ct-gia').value =
      e.target.selectedOptions[0].dataset.gia;
  };
  $(oChua).appendChild(d);
}

function docDong(oChua) {
  return [...$(oChua).querySelectorAll('.dong-ct')].map(d => ({
    maVT:    d.querySelector('.ct-vt').value,
    soLuong: d.querySelector('.ct-sl').value,
    donGia:  d.querySelector('.ct-gia').value,
  }));
}

/* ------------------------------- nhập kho --------------------------------- */
$('formNhap').onsubmit = async (e) => {
  e.preventDefault();
  bao('kqNhap', 'tin', 'Đang ghi phiếu nhập…');
  try {
    const kq = await goi('/api/nhapkho', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        maNCC: $('nhapNCC').value,
        nguoiLap: $('nhapNguoiLap').value,
        chiTiet: docDong('dongNhap'),
      }),
    });
    bao('kqNhap', 'ok', kq.thongBao, `Mã phiếu <code>${kq.maPhieu}</code> — tồn kho đã được cộng thêm.`);
    taiTonKho();
  } catch (err) {
    bao('kqNhap', 'loi', 'Không ghi được phiếu nhập', err.message);
  }
};

/* ------------------------------- xuất kho --------------------------------- */
$('formXuat').onsubmit = async (e) => {
  e.preventDefault();
  bao('kqXuat', 'tin', 'Đang ghi phiếu xuất…');
  try {
    const kq = await goi('/api/xuatkho', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        nguoiNhan: $('xuatNguoiNhan').value,
        nguoiLap: $('xuatNguoiLap').value,
        chiTiet: docDong('dongXuat'),
      }),
    });
    bao('kqXuat', 'ok', kq.thongBao, `Mã phiếu <code>${kq.maPhieu}</code> — tồn kho đã được trừ.`);
    taiTonKho();
  } catch (err) {
    bao('kqXuat', 'loi', 'Phiếu xuất bị từ chối', err.message
      + '<br>Tồn kho giữ nguyên, giao tác đã được quay lui hoàn toàn.');
  }
};

/* ------------------------------ điều chuyển ------------------------------- */
async function chupTruocSau(maVT, nhan) {
  const ds = await goi('/api/anhchup/' + maVT);
  return `<h3 style="font-size:15px;margin:16px 0 6px">${nhan}</h3>` + dungBang([
    { ten: 'Kho', khoa: 'TenKho' },
    { ten: 'Mã kho', khoa: 'MaKho' },
    { ten: 'Vật tư', khoa: 'MaVT' },
    { ten: 'Tồn', so: true, hien: d => so(d.SoLuong) },
  ], ds, { lopDong: d => d.MaKho === SITE.MaKho ? 'site-nay' : '' });
}

async function chuyen(gayLoi) {
  const maVT = $('chuyenVT').value;
  const than = { o: 'kqChuyen', ss: 'soSanh' };
  $(than.ss).innerHTML = await chupTruocSau(maVT, 'Tồn kho TRƯỚC khi điều chuyển');
  bao(than.o, 'tin', gayLoi ? 'Đang chạy giao tác sẽ hỏng giữa chừng…' : 'Đang chạy giao tác phân tán…');

  try {
    const kq = await goi('/api/dieuchuyen', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        maKhoDich: $('chuyenKho').value,
        maVT,
        soLuong: $('chuyenSL').value,
        ghiChu: $('chuyenGhiChu').value,
        gayLoi,
      }),
    });
    bao(than.o, 'ok', kq.thongBao,
      `Phiếu <code>${kq.maPhieu}</code> được ghi ở <b>cả hai site</b>.
       Tổng số hàng toàn hệ thống không đổi — rời kho nguồn bao nhiêu thì tới kho đích bấy nhiêu.`);
  } catch (err) {
    bao(than.o, gayLoi ? 'tin' : 'loi',
      gayLoi ? 'Giao tác đã hỏng giữa chừng — đúng như mong đợi' : 'Điều chuyển bị từ chối',
      `<code>${err.message}</code><br><br>Kho nguồn đã bị trừ và phiếu đã được ghi `
      + `trước khi lỗi xảy ra, nhưng <b>MS DTC đã quay lui cả hai máy chủ</b>. `
      + `Hai bảng dưới chứng minh điều đó: tồn kho trước và sau y hệt nhau, `
      + `không một đơn vị hàng nào bị mất.`);
  }

  $(than.ss).innerHTML += await chupTruocSau(maVT, 'Tồn kho SAU khi điều chuyển');
  taiTonKho();
}

$('formChuyen').onsubmit = (e) => { e.preventDefault(); chuyen(false); };
function chuyenLoi() { chuyen(true); }

/* -------------------------------- lịch sử --------------------------------- */
async function taiLichSu() {
  const ds = await goi('/api/lichsu');
  $('bangLichSu').innerHTML = dungBang([
    { ten: 'Loại', khoa: 'Loai' },
    { ten: 'Mã chứng từ', khoa: 'MaChungTu' },
    { ten: 'Thời điểm', hien: d => ngay(d.ThoiDiem) },
    { ten: 'Số lượng', so: true, hien: d => so(d.SoLuong || 0) },
    { ten: 'Người lập', khoa: 'NguoiLap' },
    { ten: 'Trạng thái', khoa: 'TrangThai' },
    { ten: 'Ghi chú', khoa: 'GhiChu' },
  ], ds);
}

/* --------------------------------- tab ------------------------------------ */
document.querySelectorAll('.tab').forEach(t => {
  t.onclick = () => {
    document.querySelectorAll('.tab').forEach(x => x.classList.remove('hoatdong'));
    document.querySelectorAll('.muc').forEach(x => x.classList.remove('hien'));
    t.classList.add('hoatdong');
    $(t.dataset.muc).classList.add('hien');
    if (t.dataset.muc === 'toanhethong') taiToanHeThong();
    if (t.dataset.muc === 'lichsu') taiLichSu();
  };
});

khoiDong().catch(e => {
  document.body.innerHTML =
    `<div style="padding:40px;font:15px/1.6 'Segoe UI',sans-serif">
       <h2 style="color:#b42318">Không nối được cơ sở dữ liệu</h2>
       <p>${e.message}</p>
       <p>Xem thông báo trong cửa sổ dòng lệnh đang chạy máy chủ ứng dụng.</p>
     </div>`;
});
