const fs = require('fs');
const {
  Document, Packer, Paragraph, TextRun, PageBreak, AlignmentType, HeadingLevel,
  TableOfContents, Header, Footer, PageNumber, LevelFormat, convertInchesToTwip,
  BorderStyle, NumberFormat,
} = require('docx');

const H = require('./helper');
const { p, h1, h2, h3, li, no, code, table, pageBreak, blank } = H;
const { chuongI, chuongII } = require('./noidung12');
const { chuongIII, chuongIV } = require('./noidung34');

const FONT = 'Times New Roman';

// ============================ THÔNG TIN CẦN ĐIỀN ============================
const TT = {
  truong1: 'BỘ THÔNG TIN VÀ TRUYỀN THÔNG',
  truong2: 'HỌC VIỆN CÔNG NGHỆ BƯU CHÍNH VIỄN THÔNG',
  detai: 'QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH',
  detaiPhu: 'HỆ CƠ SỞ DỮ LIỆU PHÂN TÁN TRÊN BA SITE',
  monhoc: 'Cơ sở dữ liệu phân tán',
  giangvien: 'Phan Nghĩa Hiệp',
  nhom: 'Nhóm 2',
  thanhvien: [
    ['1.', 'Nguyễn Thế Sang',   'N23DVCN050', 'Trưởng nhóm'],
    ['2.', 'Nguyễn Thanh Sang', 'N23DVCN051', 'Thành viên'],
    ['3.', 'Thái Thanh Vũ',     'N23DVCN064', 'Thành viên'],
    ['4.', 'Hoàng Gia Bình',    'N23DVCN007', 'Thành viên'],
    ['5.', 'Nguyễn Minh Khoa',  'N23DVCN030', 'Thành viên'],
  ],
  diadiem: 'TP.HCM, tháng 9 / 2026',
};
// ===========================================================================

function txt(t, o = {}) {
  return new Paragraph({
    alignment: o.align || AlignmentType.CENTER,
    spacing: { before: o.before || 0, after: o.after === undefined ? 100 : o.after, line: o.line || 300 },
    children: [new TextRun({
      text: t, font: FONT, size: o.size || 26,
      bold: o.bold || false, italics: o.italics || false,
    })],
  });
}

// ---------------------------- TRANG BÌA ----------------------------
function trangBia() {
  const out = [];
  out.push(txt(TT.truong1, { bold: true, size: 26 }));
  out.push(txt(TT.truong2, { bold: true, size: 28 }));
  out.push(txt('-----------------------------', { after: 300 }));
  out.push(...blank(3));
  out.push(txt('BÁO CÁO', { bold: true, size: 56, after: 60 }));
  out.push(txt('ĐỒ ÁN MÔN HỌC', { bold: true, size: 56, after: 400 }));
  out.push(...blank(2));
  out.push(txt('ĐỀ TÀI: ' + TT.detai, { bold: true, size: 32, after: 60 }));
  out.push(txt(TT.detaiPhu, { bold: true, size: 28, after: 200 }));
  out.push(...blank(4));

  const line = (nhan, giatri) => new Paragraph({
    alignment: AlignmentType.LEFT,
    spacing: { after: 120, line: 300 },
    children: [
      new TextRun({ text: nhan + ' ', font: FONT, size: 26, bold: true }),
      new TextRun({ text: giatri, font: FONT, size: 26 }),
    ],
  });
  out.push(line('Môn học:', TT.monhoc));
  out.push(line('Giảng viên hướng dẫn:', TT.giangvien));
  out.push(line('Nhóm thực hiện:', TT.nhom));
  out.push(new Paragraph({
    alignment: AlignmentType.LEFT,
    spacing: { after: 120 },
    children: [new TextRun({ text: 'Thực hiện bởi nhóm sinh viên, bao gồm:', font: FONT, size: 26, bold: true })],
  }));

  for (const [stt, ten, mssv, vaitro] of TT.thanhvien) {
    out.push(new Paragraph({
      alignment: AlignmentType.LEFT,
      indent: { left: convertInchesToTwip(0.4) },
      spacing: { after: 80, line: 300 },
      tabStops: [
        { type: 'left', position: convertInchesToTwip(2.9) },
        { type: 'left', position: convertInchesToTwip(4.3) },
      ],
      children: [new TextRun({
        text: `${stt} ${ten}\t${mssv}\t${vaitro}`,
        font: FONT, size: 26,
      })],
    }));
  }

  out.push(...blank(3));
  out.push(txt(TT.diadiem, { bold: true, after: 0 }));
  out.push(pageBreak());
  return out;
}

// ---------------------------- MỤC LỤC ----------------------------
function mucLuc() {
  return [
    txt('MỤC LỤC', { bold: true, size: 32, after: 300 }),
    new TableOfContents('Muc luc', {
      hyperlink: false,   // mục lục in đen, không tô màu liên kết
      headingStyleRange: '1-3',
    }),
    pageBreak(),
  ];
}

// ------------------ DANH SÁCH HÌNH, BẢNG ------------------
function danhSach() {
  // dùng h1/h2 thay cho đoạn văn thường để hai mục này hiện ra trong mục lục
  const out = [h1('DANH SÁCH HÌNH, BẢNG')];
  out.push(h2('DANH SÁCH HÌNH'));
  for (const f of H.figList) {
    out.push(new Paragraph({
      spacing: { after: 40, line: 280 },
      indent: { left: convertInchesToTwip(0.2) },
      children: [new TextRun({ text: f, font: FONT, size: 24 })],
    }));
  }
  out.push(h2('DANH SÁCH BẢNG'));
  for (const t of H.tabList) {
    out.push(new Paragraph({
      spacing: { after: 40, line: 280 },
      indent: { left: convertInchesToTwip(0.2) },
      children: [new TextRun({ text: t, font: FONT, size: 24 })],
    }));
  }
  out.push(pageBreak());
  return out;
}

// ---------------------------- TÓM TẮT ----------------------------
function tomTat() {
  return [
    h1('TÓM TẮT'),
    p('Báo cáo trình bày quá trình phân tích, thiết kế và triển khai một **hệ cơ sở dữ liệu phân tán quản lý kho vật tư đa chi nhánh**, thực hiện trên ba site SQL Server độc lập.'),
    p('Xuất phát từ khảo sát tần suất truy cập cho thấy **89% nghiệp vụ hằng ngày chỉ đụng tới dữ liệu của chính kho đó**, nhóm quyết định **phân mảnh ngang** bảng tồn kho và chứng từ theo mã kho, đồng thời **nhân bản** ba bảng danh mục vì chúng có tỷ lệ đọc trên ghi rất cao. Bảng chi tiết chứng từ không chứa mã kho nên được **phân mảnh ngang dẫn xuất** bằng phép nửa nối theo phiếu.'),
    p('Hệ thống cài đặt đầy đủ các kỹ thuật cốt lõi của môn học: sáu **Linked Server** nối ba site thành đồ thị hai chiều; **Transactional Replication** đồng bộ danh mục với độ trễ đo được 15–20 giây; **giao tác phân tán hai pha** qua MS DTC cho nghiệp vụ điều chuyển vật tư; bốn kịch bản **điều khiển tương tranh**; và các **truy vấn phân tán** gộp dữ liệu từ cả ba máy chủ.'),
    p('Yêu cầu trọng tâm của đề tài — *điều chuyển 50 sản phẩm từ Kho A sang Kho B, nếu thất bại giữa chừng thì dữ liệu phải nhất quán* — được kiểm chứng bằng ba kịch bản chạy thật. Trong kịch bản gây lỗi cố ý **sau khi kho nguồn đã bị trừ hàng**, giao thức hai pha đã quay lui toàn bộ ở cả hai máy chủ, tồn kho và số chứng từ trở về đúng trạng thái ban đầu, **không một đơn vị hàng nào bị mất**.'),
    p('Dữ liệu được bảo vệ bằng **ba lớp chồng nhau**: ràng buộc kiểm tra ở tầng dữ liệu, sáu trigger cho những luật mà ràng buộc không diễn tả nổi, và hệ thống bốn vai trò buộc mọi thay đổi tồn kho phải đi qua thủ tục đã kiểm soát.'),
    pageBreak(),
  ];
}

// ---------------------------- DỰNG TÀI LIỆU ----------------------------
// Chương I, II, III, IV phải dựng TRƯỚC để H.figList và H.tabList có dữ liệu
// dayChuThichXuongDuoi: tên bảng viết trước bảng trong mã, nhưng phải in dưới bảng
const c1 = H.dayChuThichXuongDuoi(chuongI());
const c2 = H.dayChuThichXuongDuoi(chuongII());
const c3 = H.dayChuThichXuongDuoi(chuongIII());
const c4 = H.dayChuThichXuongDuoi(chuongIV());

const taiLieu = [
  h1('TÀI LIỆU THAM KHẢO'),
  ...[
    'M. Tamer Özsu, Patrick Valduriez. *Principles of Distributed Database Systems*, 4th Edition. Springer, 2020.',
    'Microsoft. *SQL Server Replication Documentation*. learn.microsoft.com/en-us/sql/relational-databases/replication',
    'Microsoft. *Distributed Transactions and Microsoft Distributed Transaction Coordinator*. learn.microsoft.com/en-us/sql/relational-databases/native-client-ole-db-transactions',
    'Microsoft. *Linked Servers (Database Engine)*. learn.microsoft.com/en-us/sql/relational-databases/linked-servers',
    'Microsoft. *Transaction Locking and Row Versioning Guide*. learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide',
    'Microsoft. *DML Triggers*. learn.microsoft.com/en-us/sql/relational-databases/triggers/dml-triggers',
    'ZeroTier Inc. *ZeroTier Manual*. docs.zerotier.com',
    'Slide bài giảng môn Cơ sở dữ liệu phân tán, Học viện Công nghệ Bưu chính Viễn thông.',
  ].map((t, i) => new Paragraph({
    alignment: AlignmentType.JUSTIFIED,
    spacing: { after: 120, line: 320 },
    indent: { left: convertInchesToTwip(0.35), hanging: convertInchesToTwip(0.35) },
    children: H.runs(`[${i + 1}]  ${t.replace(/\*/g, '')}`),
  })),
];

const doc = new Document({
  creator: 'Nhom do an CSDL Phan tan',
  title: 'Bao cao do an - Quan ly kho vat tu da chi nhanh',
  description: 'He co so du lieu phan tan tren ba site SQL Server',
  styles: {
    default: {
      document: { run: { font: FONT, size: 26 } },
      heading1: { run: { font: FONT, size: 32, bold: true, color: '000000' } },
      heading2: { run: { font: FONT, size: 28, bold: true, color: '000000' } },
      heading3: { run: { font: FONT, size: 26, bold: true, color: '000000' } },
    },
  },
  numbering: {
    config: [
      {
        reference: 'cham-tron',
        levels: [
          { level: 0, format: LevelFormat.BULLET, text: '\u2022', alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: convertInchesToTwip(0.45), hanging: convertInchesToTwip(0.22) } } } },
          { level: 1, format: LevelFormat.BULLET, text: '\u25E6', alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: convertInchesToTwip(0.8), hanging: convertInchesToTwip(0.22) } } } },
        ],
      },
      {
        reference: 'danh-so',
        levels: [
          { level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: convertInchesToTwip(0.45), hanging: convertInchesToTwip(0.25) } } } },
        ],
      },
    ],
  },
  features: { updateFields: true },
  sections: [
    // Trang bìa — không đánh số trang
    {
      properties: {
        page: {
          size: { width: 11906, height: 16838 },
          margin: { top: 1134, right: 1134, bottom: 1134, left: 1701 },
        },
      },
      children: trangBia(),
    },
    // Phần còn lại — có header và số trang
    {
      properties: {
        page: {
          size: { width: 11906, height: 16838 },
          margin: { top: 1134, right: 1134, bottom: 1134, left: 1701 },
          pageNumbers: { start: 2, formatType: NumberFormat.DECIMAL },
        },
      },
      headers: {
        default: new Header({
          children: [new Paragraph({
            alignment: AlignmentType.LEFT,
            border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: '888888', space: 4 } },
            children: [new TextRun({
              text: 'Báo cáo Đồ án môn học — Cơ sở dữ liệu phân tán',
              font: FONT, size: 20, italics: true,
            })],
          })],
        }),
      },
      footers: {
        default: new Footer({
          children: [new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 22 })],
          })],
        }),
      },
      children: [
        ...mucLuc(),
        ...danhSach(),
        ...tomTat(),
        ...c1, pageBreak(),
        ...c2, pageBreak(),
        ...c3, pageBreak(),
        ...c4, pageBreak(),
        ...taiLieu,
      ],
    },
  ],
});

const OUT = 'D:\\CSDL PHAN TAN\\Do an cuoi ki\\BaoCao_DoAn_CSDLPhanTan.docx';
Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync(OUT, buf);
  console.log('Da tao: ' + OUT);
  console.log('  So hinh : ' + H.figList.length);
  console.log('  So bang : ' + H.tabList.length);
  console.log('  Dung luong: ' + (buf.length / 1024 / 1024).toFixed(2) + ' MB');
});

if (H.anhThieu.length) console.log('  Anh chua co (da bo qua): ' + H.anhThieu.join(', '));
