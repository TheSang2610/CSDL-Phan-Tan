// Bộ hàm dựng sẵn cho báo cáo đồ án — dùng chung cho toàn bộ tài liệu
const fs = require('fs');
const path = require('path');
const {
  Paragraph, TextRun, ImageRun, Table, TableRow, TableCell,
  WidthType, AlignmentType, HeadingLevel, ShadingType, BorderStyle,
  PageBreak, convertInchesToTwip,
} = require('docx');

const FONT = 'Times New Roman';
const SIZE = 26;          // 13pt  (nửa-point)
const SIZE_SMALL = 22;    // 11pt
const CONTENT_PX = 600;   // bề rộng tối đa của ảnh (vùng nội dung ~605px)

// ---------- đoạn văn ----------
function p(text, opt = {}) {
  return new Paragraph({
    alignment: opt.align || AlignmentType.JUSTIFIED,
    spacing: { line: 360, after: opt.after === undefined ? 120 : opt.after },
    indent: opt.indent ? { firstLine: convertInchesToTwip(0.3) } : undefined,
    children: runs(text, opt),
  });
}

/* Cho phép đánh dấu **in đậm**, `tên kỹ thuật` và *in nghiêng* ngay trong chuỗi.

   Theo yêu cầu định dạng của cuốn báo cáo, phần thân bài KHÔNG in đậm — chỉ tên
   chương và tên mục mới in đậm. Nên các dấu ** trong nội dung được gỡ bỏ mà
   không tô đậm chữ. Giữ nguyên cú pháp ** trong mã nguồn để sau này muốn bật
   lại chỉ cần đổi hằng số dưới đây.                                            */
const IN_DAM_THAN_BAI = false;

function runs(text, opt = {}) {
  const out = [];
  const parts = String(text).split(/(\*\*[^*]+\*\*|`[^`]+`|\*[^*`]+\*)/g);
  for (const part of parts) {
    if (!part) continue;
    let t = part, bold = false, mono = false, ita = false;
    if (part.startsWith('**') && part.endsWith('**')) { t = part.slice(2, -2); bold = IN_DAM_THAN_BAI; }
    else if (part.startsWith('`') && part.endsWith('`')) { t = part.slice(1, -1); mono = true; }
    else if (part.startsWith('*') && part.endsWith('*') && part.length > 2) { t = part.slice(1, -1); ita = true; }
    out.push(new TextRun({
      text: t,
      font: (mono || opt.mono) ? 'Consolas' : FONT,
      size: mono ? SIZE_SMALL : (opt.size || (opt.mono ? SIZE_SMALL : SIZE)),
      bold: bold || opt.bold || false,
      italics: ita || opt.italics || false,
      color: opt.color,
    }));
  }
  return out;
}

// ---------- tiêu đề ----------
function h1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    alignment: AlignmentType.CENTER,
    spacing: { before: 240, after: 240 },
    children: [new TextRun({ text, font: FONT, size: 32, bold: true, color: '000000' })],
  });
}
function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 240, after: 120 },
    children: [new TextRun({ text, font: FONT, size: 28, bold: true, color: '000000' })],
  });
}
function h3(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3,
    spacing: { before: 180, after: 100 },
    children: [new TextRun({ text, font: FONT, size: 26, bold: true, italics: true, color: '000000' })],
  });
}

// ---------- gạch đầu dòng ----------
function li(text, level = 0) {
  return new Paragraph({
    numbering: { reference: 'cham-tron', level },
    alignment: AlignmentType.JUSTIFIED,
    spacing: { line: 340, after: 60 },
    children: runs(text),
  });
}
/* Danh sách đánh số — tự đánh số bằng TAY thay vì dùng numbering của Word.
   Lý do: mọi danh sách trong tài liệu dùng chung một numbering reference thì
   Word đếm tiếp tục từ danh sách trước, khiến danh sách thứ hai bắt đầu bằng
   số 11 thay vì số 1. Đánh số bằng tay tránh hẳn lỗi đó.                     */
function no(num, text) {
  return new Paragraph({
    alignment: AlignmentType.JUSTIFIED,
    spacing: { line: 340, after: 60 },
    indent: { left: convertInchesToTwip(0.45), hanging: convertInchesToTwip(0.28) },
    children: [
      new TextRun({ text: num + '. ', font: FONT, size: SIZE }),
      ...runs(text),
    ],
  });
}

// ---------- khối mã / sơ đồ ASCII ----------
function code(lines, opt = {}) {
  const arr = Array.isArray(lines) ? lines : String(lines).split('\n');
  return arr.map((l, i) => new Paragraph({
    spacing: { line: 240, after: i === arr.length - 1 ? 120 : 0 },
    indent: { left: convertInchesToTwip(0.2) },
    shading: { type: ShadingType.CLEAR, fill: 'F4F4F4' },
    children: [new TextRun({
      text: l.length ? l : ' ',
      font: 'Consolas',
      size: opt.size || 18,
    })],
  }));
}

// ---------- chú thích hình / bảng ----------
/* Hình và bảng đánh số liên tục từ 1 cho cả cuốn, không kèm số La Mã của
   chương. "Hình 33" ngắn và dễ tra hơn "Hình III.33", nhất là khi danh sách
   hình nằm ở đầu sách và người đọc phải lần ngược lại.
   Tham số chương ở các lời gọi vẫn giữ để khỏi phải sửa hàng trăm chỗ.        */
let figCount = 0;
let tabCount = 0;
const figList = [];
const tabList = [];

// Đánh dấu đoạn chú thích bảng, để lát nữa đẩy nó xuống dưới bảng
const CHU_THICH_BANG = Symbol('chuThichBang');

const anhThieu = [];
function fig(imgPath, caption, chuong, opt = {}) {
  if (!fs.existsSync(imgPath)) {      // ảnh chưa chụp -> bỏ qua, ghi lại để báo
    anhThieu.push(path.basename(imgPath));
    return [];
  }
  const dim = pngSize(imgPath);
  const maxW = opt.width || CONTENT_PX;
  const scale = Math.min(1, maxW / dim.w);
  const w = Math.round(dim.w * scale);
  const h = Math.round(dim.h * scale);

  const label = `Hình ${++figCount}: ${caption}`;
  figList.push(label);

  return [
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 120, after: 60 },
      children: [new ImageRun({
        type: 'png',
        data: fs.readFileSync(imgPath),
        transformation: { width: w, height: h },
      })],
    }),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { after: 200 },
      children: [new TextRun({ text: label, font: FONT, size: 22, italics: true })],
    }),
  ];
}

/* Ghi chú tạm cho mục chưa chụp được ảnh. Khi ảnh đã có trên đĩa thì câu ghi
   chú tự biến mất, khỏi phải nhớ đi xoá bằng tay rồi để sót lại trong bản nộp. */
function ghiChuAnh(imgPath) {
  if (fs.existsSync(imgPath)) return [];
  return [new Paragraph({
    alignment: AlignmentType.JUSTIFIED,
    spacing: { line: 360, after: 120 },
    children: [new TextRun({
      text: '(Ghi chú: phần ảnh chụp minh chứng cho mục này được bổ sung khi ba máy vật lý của nhóm cùng tham gia mạng ảo.)',
      font: FONT, size: SIZE, italics: true,
    })],
  })];
}

function tabCap(caption, chuong) {
  const label = `Bảng ${++tabCount}: ${caption}`;
  tabList.push(label);
  // khoảng cách đặt theo vị trí cuối cùng: chú thích nằm DƯỚI bảng
  const para = new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 60, after: 200 },
    children: [new TextRun({ text: label, font: FONT, size: 22, italics: true })],
  });
  para[CHU_THICH_BANG] = true;
  return para;
}

/* Trong mã nguồn, chú thích được viết TRƯỚC bảng cho dễ đọc. Quy cách trình bày
   lại đòi tên bảng nằm DƯỚI bảng, nên đổi chỗ hai phần tử ngay trước khi dựng
   tài liệu. Làm ở đây gọn hơn nhiều so với sửa tay 29 chỗ gọi.                 */
function dayChuThichXuongDuoi(mang) {
  const out = mang.slice();
  for (let i = 0; i < out.length - 1; i++) {
    if (out[i] && out[i][CHU_THICH_BANG] && out[i + 1] instanceof Table) {
      const tam = out[i]; out[i] = out[i + 1]; out[i + 1] = tam;
      i++;   // bỏ qua phần tử vừa đổi chỗ
    }
  }
  return out;
}

// đọc kích thước PNG từ phần đầu tệp
function pngSize(file) {
  const b = fs.readFileSync(file);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

// ---------- bảng ----------
// Bề rộng vùng nội dung: khổ A4 11906 twip, trừ lề trái 1701 và lề phải 1134.
// Đặt sai con số này thì bảng sẽ tràn ra ngoài lề khi in.
const TOTAL = 11906 - 1701 - 1134;   // = 9071 DXA

function table(header, rows, widths) {
  const cols = widths
    ? widths.map(x => Math.round(TOTAL * x / widths.reduce((a, b) => a + b, 0)))
    : new Array(header.length).fill(Math.round(TOTAL / header.length));
  // bù sai số làm tròn vào cột cuối
  const diff = TOTAL - cols.reduce((a, b) => a + b, 0);
  cols[cols.length - 1] += diff;

  const cell = (txt, i, isHead) => new TableCell({
    width: { size: cols[i], type: WidthType.DXA },
    shading: isHead ? { type: ShadingType.CLEAR, fill: 'D9E2F3' } : undefined,
    margins: { top: 60, bottom: 60, left: 80, right: 80 },
    children: [new Paragraph({
      alignment: isHead ? AlignmentType.CENTER : AlignmentType.LEFT,
      spacing: { line: 260, after: 0 },
      children: runs(txt, { size: SIZE_SMALL, bold: isHead }),
    })],
  });

  return new Table({
    columnWidths: cols,
    width: { size: TOTAL, type: WidthType.DXA },
    rows: [
      new TableRow({
        tableHeader: true,
        children: header.map((t, i) => cell(t, i, true)),
      }),
      ...rows.map(r => new TableRow({ children: r.map((t, i) => cell(t, i, false)) })),
    ],
  });
}

function pageBreak() {
  return new Paragraph({ children: [new PageBreak()] });
}

function blank(n = 1) {
  return Array.from({ length: n }, () => new Paragraph({ children: [new TextRun('')] }));
}

module.exports = {
  p, h1, h2, h3, li, no, code, fig, ghiChuAnh, tabCap, table, pageBreak, blank, runs,
  dayChuThichXuongDuoi,
  figList, tabList, anhThieu, FONT, SIZE, SIZE_SMALL,
};
