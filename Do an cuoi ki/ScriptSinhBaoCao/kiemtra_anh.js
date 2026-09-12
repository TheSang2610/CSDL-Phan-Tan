/* Đối chiếu ảnh mà báo cáo gọi tới với ảnh thật sự có trên đĩa.
   Chạy:  node kiemtra_anh.js
   Dùng trước mỗi lần dựng lại báo cáo để khỏi phát hiện thiếu ảnh khi đã nộp. */
const fs = require('fs');
const path = require('path');

const A = 'D:\\CSDL PHAN TAN\\Do an cuoi ki\\AnhChup\\';
const I = 'D:\\CSDL PHAN TAN\\ảnh\\';

// Bóc mọi lời gọi fig(...) ra khỏi mã nguồn thay vì chạy thật, để không phải
// cài docx chỉ để kiểm tra.
function bocDuongDan(file) {
  const src = fs.readFileSync(path.join(__dirname, file), 'utf8');
  const out = [];
  const re = /fig\(\s*([AI])\s*\+\s*'((?:[^'\\]|\\.)*)'/g;
  let m;
  while ((m = re.exec(src)) !== null) {
    const goc = m[1] === 'A' ? A : I;
    out.push(goc + m[2].replace(/\\\\/g, '\\'));
  }
  return out;
}

const canCo = [...bocDuongDan('noidung12.js'), ...bocDuongDan('noidung34.js')];

const thieu = canCo.filter(f => !fs.existsSync(f));
const co = canCo.length - thieu.length;

console.log('Bao cao goi toi : ' + canCo.length + ' anh');
console.log('Da co tren dia  : ' + co);
console.log('Con thieu       : ' + thieu.length);
if (thieu.length) {
  console.log('\n--- DANH SACH ANH CON THIEU ---');
  thieu.forEach(f => console.log('  ' + f.replace(A, 'AnhChup\\').replace(I, 'anh\\')));
}

// Chiều ngược lại: ảnh nằm trong AnhChup nhưng không chỗ nào trong báo cáo dùng
const dungRoi = new Set(canCo.map(f => f.toLowerCase()));
const thua = [];
(function quet(d) {
  for (const t of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, t.name);
    if (t.isDirectory()) quet(p);
    else if (/\.png$/i.test(t.name) && !dungRoi.has(p.toLowerCase())) thua.push(p);
  }
})(A.slice(0, -1));

if (thua.length) {
  console.log('\n--- ANH CO TREN DIA NHUNG BAO CAO CHUA DUNG (' + thua.length + ') ---');
  thua.forEach(f => console.log('  ' + f.replace(A, 'AnhChup\\')));
}
