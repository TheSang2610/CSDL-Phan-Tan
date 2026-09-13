/* Chuyển file .md hướng dẫn thành .docx để xuất PDF cho dễ đọc, dễ in.
   Chỉ xử lý đúng những cú pháp mà hai file hướng dẫn thật sự dùng:
   tiêu đề, bảng, khối mã, trích dẫn, danh sách số, danh sách tick, gạch ngang. */
const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  WidthType, AlignmentType, HeadingLevel, ShadingType, BorderStyle,
  PageNumber, Header, Footer, convertInchesToTwip,
} = require('docx');

const FONT = 'Times New Roman';
const MONO = 'Consolas';
const SIZE = 24;        // 12pt
const TOTAL = 11906 - 1134 - 1134;   // A4 trừ hai lề 2cm

/* Thay biểu tượng cảm xúc bằng chữ thường.
   Lý do rất thực tế: Word phải nhúng nguyên phông Segoe UI Emoji (phông màu,
   rất nặng) chỉ vì vài ký tự, khiến file PDF sáu trang phình lên hơn 4 MB.
   Đổi sang chữ thì file còn vài trăm KB và in đen trắng cũng đọc được. */
function bỏEmoji(s) {
  return String(s)
    .replace(/⚠️?\s*/g, 'LƯU Ý: ')
    .replace(/💡\s*/g, 'MẸO: ')
    .replace(/📷\s*/g, '» ');
}

/* --- chữ in đậm / `mã` / *nghiêng* ngay trong dòng --- */
function runs(text, opt = {}) {
  const out = [];
  // `mã` đã đủ nổi bật, nên bỏ cặp ** bọc ngoài nó — nếu không hai dấu sao
  // sẽ lọt ra ngoài và in nguyên si thành **`KHO_B`**
  const src = bỏEmoji(text).replace(/\*\*(`[^`]+`)\*\*/g, '$1');
  for (const part of src.split(/(`[^`]+`|\*\*[^*]+\*\*|\*[^*`]+\*)/g)) {
    if (!part) continue;
    let t = part, bold = false, mono = false, ita = false;
    if (part.startsWith('`') && part.endsWith('`')) { t = part.slice(1, -1); mono = true; }
    else if (part.startsWith('**') && part.endsWith('**')) { t = part.slice(2, -2); bold = true; }
    else if (part.startsWith('*') && part.endsWith('*') && part.length > 2) { t = part.slice(1, -1); ita = true; }
    out.push(new TextRun({
      text: t,
      font: mono ? MONO : FONT,
      size: mono ? SIZE - 4 : (opt.size || SIZE),
      bold: bold || opt.bold || false,
      italics: ita || opt.italics || false,
      color: mono ? '0B5394' : opt.color,
      shading: mono ? { type: ShadingType.CLEAR, fill: 'F0F0F0' } : undefined,
    }));
  }
  return out.length ? out : [new TextRun({ text: ' ', font: FONT, size: SIZE })];
}

function docTuMarkdown(mdPath) {
  const dong = fs.readFileSync(mdPath, 'utf8').split(/\r?\n/);
  const kq = [];
  let i = 0;

  while (i < dong.length) {
    const l = dong[i];

    // ---- khối mã ```...``` ----
    if (/^\s*```/.test(l)) {
      const than = [];
      i++;
      while (i < dong.length && !/^\s*```/.test(dong[i])) { than.push(dong[i]); i++; }
      i++;
      than.forEach((c, k) => kq.push(new Paragraph({
        spacing: { line: 240, after: k === than.length - 1 ? 160 : 0, before: k === 0 ? 80 : 0 },
        indent: { left: convertInchesToTwip(0.15) },
        shading: { type: ShadingType.CLEAR, fill: 'F4F4F4' },
        children: [new TextRun({ text: c.length ? bỏEmoji(c) : ' ', font: MONO, size: 16 })],
      })));
      continue;
    }

    // ---- bảng ----
    if (/^\s*\|/.test(l) && i + 1 < dong.length && /^\s*\|[\s:|-]+\|\s*$/.test(dong[i + 1])) {
      const oCua = r => r.trim().replace(/^\||\|$/g, '').split('|').map(s => s.trim());
      const dau = oCua(l);
      i += 2;
      const than = [];
      while (i < dong.length && /^\s*\|/.test(dong[i])) { than.push(oCua(dong[i])); i++; }
      const w = Math.floor(TOTAL / dau.length);
      const cols = new Array(dau.length).fill(w);
      cols[cols.length - 1] += TOTAL - w * dau.length;
      const o = (txt, k, head) => new TableCell({
        width: { size: cols[k], type: WidthType.DXA },
        shading: head ? { type: ShadingType.CLEAR, fill: 'D9E2F3' } : undefined,
        margins: { top: 60, bottom: 60, left: 80, right: 80 },
        children: [new Paragraph({
          alignment: head ? AlignmentType.CENTER : AlignmentType.LEFT,
          spacing: { line: 260, after: 0 },
          children: runs(txt, { bold: head, size: SIZE - 2 }),
        })],
      });
      kq.push(new Table({
        columnWidths: cols,
        width: { size: TOTAL, type: WidthType.DXA },
        rows: [
          new TableRow({ tableHeader: true, children: dau.map((t, k) => o(t, k, true)) }),
          ...than.map(r => new TableRow({ children: cols.map((_, k) => o(r[k] || '', k, false)) })),
        ],
      }));
      kq.push(new Paragraph({ spacing: { after: 120 }, children: [new TextRun('')] }));
      continue;
    }

    // ---- gạch ngang ----
    if (/^\s*---+\s*$/.test(l)) {
      kq.push(new Paragraph({
        spacing: { before: 120, after: 120 },
        border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: 'BBBBBB' } },
        children: [new TextRun('')],
      }));
      i++; continue;
    }

    // ---- tiêu đề ----
    const h = l.match(/^(#{1,4})\s+(.*)$/);
    if (h) {
      const cap = h[1].length;
      kq.push(new Paragraph({
        heading: [HeadingLevel.HEADING_1, HeadingLevel.HEADING_2,
                  HeadingLevel.HEADING_3, HeadingLevel.HEADING_4][cap - 1],
        spacing: { before: cap === 1 ? 240 : 220, after: 120 },
        children: runs(h[2].replace(/\*\*/g, ''), {
          bold: true, size: [32, 28, 26, 24][cap - 1],
          color: cap <= 2 ? '1F3864' : '000000',
        }),
      }));
      i++; continue;
    }

    // ---- trích dẫn ----
    if (/^\s*>/.test(l)) {
      const than = [];
      while (i < dong.length && /^\s*>/.test(dong[i])) {
        than.push(dong[i].replace(/^\s*>\s?/, '')); i++;
      }
      than.forEach(c => kq.push(new Paragraph({
        spacing: { line: 300, after: 60 },
        indent: { left: convertInchesToTwip(0.25) },
        border: { left: { style: BorderStyle.SINGLE, size: 12, color: 'F0A500', space: 8 } },
        children: runs(c, { italics: true }),
      })));
      kq.push(new Paragraph({ spacing: { after: 100 }, children: [new TextRun('')] }));
      continue;
    }

    // ---- ô tick  - [ ] ----
    const tick = l.match(/^\s*-\s+\[([ xX])\]\s+(.*)$/);
    if (tick) {
      kq.push(new Paragraph({
        spacing: { line: 300, after: 40 },
        indent: { left: convertInchesToTwip(0.3), hanging: convertInchesToTwip(0.22) },
        children: [
          new TextRun({ text: (tick[1] === ' ' ? '[  ]' : '[x]') + '  ', font: FONT, size: SIZE }),
          ...runs(tick[2]),
        ],
      }));
      i++; continue;
    }

    // ---- danh sách số ----
    const so = l.match(/^(\s*)(\d+)\.\s+(.*)$/);
    if (so) {
      const sau = so[1].length >= 3 ? 0.65 : 0.35;
      kq.push(new Paragraph({
        spacing: { line: 300, after: 50 },
        indent: { left: convertInchesToTwip(sau), hanging: convertInchesToTwip(0.25) },
        children: [new TextRun({ text: so[2] + '. ', font: FONT, size: SIZE, bold: true }), ...runs(so[3])],
      }));
      i++; continue;
    }

    // ---- gạch đầu dòng ----
    const gach = l.match(/^(\s*)[-*]\s+(.*)$/);
    if (gach) {
      const sau = gach[1].length >= 3 ? 0.6 : 0.3;
      kq.push(new Paragraph({
        spacing: { line: 300, after: 50 },
        indent: { left: convertInchesToTwip(sau), hanging: convertInchesToTwip(0.2) },
        children: [new TextRun({ text: '•  ', font: FONT, size: SIZE }), ...runs(gach[2])],
      }));
      i++; continue;
    }

    // ---- dòng trắng ----
    if (!l.trim()) {
      kq.push(new Paragraph({ spacing: { after: 60 }, children: [new TextRun('')] }));
      i++; continue;
    }

    // ---- đoạn văn thường ----
    kq.push(new Paragraph({
      alignment: AlignmentType.JUSTIFIED,
      spacing: { line: 300, after: 80 },
      children: runs(l.trim()),
    }));
    i++;
  }
  return kq;
}

async function main() {
  const dsach = process.argv.slice(2);
  for (const f of dsach) {
    const ten = path.basename(f, '.md');
    const doc = new Document({
      styles: { default: { document: { run: { font: FONT, size: SIZE } } } },
      sections: [{
        properties: {
          page: { size: { width: 11906, height: 16838 },
                  margin: { top: 1134, right: 1134, bottom: 1134, left: 1134 } },
        },
        headers: { default: new Header({ children: [new Paragraph({
          alignment: AlignmentType.RIGHT,
          border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CCCCCC' } },
          children: [new TextRun({ text: 'Đồ án CSDL phân tán — Hướng dẫn cài đặt', font: FONT, size: 18, italics: true, color: '666666' })],
        })] }) },
        footers: { default: new Footer({ children: [new Paragraph({
          alignment: AlignmentType.CENTER,
          children: [new TextRun({ children: ['Trang ', PageNumber.CURRENT, ' / ', PageNumber.TOTAL_PAGES], font: FONT, size: 18, color: '666666' })],
        })] }) },
        children: docTuMarkdown(f),
      }],
    });
    const ra = path.join(path.dirname(f), ten + '.docx');
    fs.writeFileSync(ra, await Packer.toBuffer(doc));
    console.log('da tao ' + ra);
  }
}
main();
