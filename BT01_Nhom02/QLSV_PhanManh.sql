/* ============================================================
   BÀI TẬP KỸ NĂNG 1 - PHÂN MẢNH NGANG CƠ SỞ QUAN HỆ QLSV
   Kịch bản SQL (SQL Server). Với MySQL: bỏ tiền tố N', đổi
   NVARCHAR -> VARCHAR, GO -> ;
   ============================================================ */

/* ------------------------------------------------------------
   1. QUAN HỆ TOÀN CỤC
   ------------------------------------------------------------ */
IF OBJECT_ID('QLSV', 'U') IS NOT NULL DROP TABLE QLSV;
GO

CREATE TABLE QLSV (
    MA CHAR(6)       NOT NULL PRIMARY KEY,   -- Mã sinh viên
    HT NVARCHAR(50)  NOT NULL,               -- Họ và tên
    QQ NVARCHAR(20)  NOT NULL,               -- Quê quán (Miền Bắc/Trung/Nam)
    NS INT           NOT NULL,               -- Năm sinh
    GT NVARCHAR(5)   NOT NULL,               -- Giới tính
    DT NVARCHAR(20)  NOT NULL,               -- Dân tộc
    TB FLOAT         NOT NULL                -- Điểm trung bình
);
GO

INSERT INTO QLSV (MA, HT, QQ, NS, GT, DT, TB) VALUES
 ('SV01', N'Nguyễn Văn An',   N'Miền Bắc',   2004, N'Nam', N'Kinh',  8.5),
 ('SV02', N'Trần Thị Bình',   N'Miền Bắc',   2004, N'Nữ',  N'Kinh',  7.2),
 ('SV03', N'Lê Văn Cường',    N'Miền Trung', 2003, N'Nam', N'Kinh',  9.0),
 ('SV04', N'Phạm Thị Dung',   N'Miền Trung', 2004, N'Nữ',  N'Kinh',  6.8),
 ('SV05', N'Hoàng Văn Em',    N'Miền Nam',   2005, N'Nam', N'Kinh',  8.2),
 ('SV06', N'Vũ Thị Hoa',      N'Miền Nam',   2004, N'Nữ',  N'Hoa',   7.5),
 ('SV07', N'Đặng Văn Giang',  N'Miền Bắc',   2003, N'Nam', N'Tày',   8.0),
 ('SV08', N'Bùi Thị Hạnh',    N'Miền Trung', 2004, N'Nữ',  N'Mường', 8.9),
 ('SV09', N'Ngô Văn Khoa',    N'Miền Trung', 2003, N'Nam', N'Ê Đê',  6.5),
 ('SV10', N'Đỗ Thị Lan',      N'Miền Nam',   2005, N'Nữ',  N'Khmer', 7.9),
 ('SV11', N'Lý Văn Minh',     N'Miền Bắc',   2004, N'Nam', N'Kinh',  5.5),
 ('SV12', N'Trịnh Thị Nga',   N'Miền Nam',   2003, N'Nữ',  N'Kinh',  9.2);
GO

/* ------------------------------------------------------------
   2. HAI ỨNG DỤNG (nguồn sinh vị từ đơn giản)
   ------------------------------------------------------------ */
-- Ứng dụng 1: Xét học bổng / cảnh báo học vụ  -> vị từ trên TB
SELECT MA, HT, TB FROM QLSV WHERE TB >= 8.0;          -- p1
SELECT MA, HT, TB FROM QLSV WHERE TB <  8.0;          -- p2

-- Ứng dụng 2: Quản lý theo vùng miền          -> vị từ trên QQ
SELECT MA, HT, QQ FROM QLSV WHERE QQ = N'Miền Bắc';   -- p3
SELECT MA, HT, QQ FROM QLSV WHERE QQ = N'Miền Trung'; -- p4
SELECT MA, HT, QQ FROM QLSV WHERE QQ = N'Miền Nam';   -- p5
GO

/* ------------------------------------------------------------
   3. PHÂN MẢNH NGANG THEO 6 HỘI SƠ CẤP
      Pr' = { p1: TB>=8.0 , p3: QQ='Miền Bắc' , p4: QQ='Miền Trung' }
      (p2 = ¬p1 ; p5 = ¬p3 ∧ ¬p4  -> bị COM_MIN loại vì không liên quan)
   ------------------------------------------------------------ */

-- m1 = p1 ∧ p3 ∧ ¬p4
SELECT * INTO QLSV1 FROM QLSV WHERE TB >= 8.0 AND QQ = N'Miền Bắc';
-- m2 = p1 ∧ ¬p3 ∧ p4
SELECT * INTO QLSV2 FROM QLSV WHERE TB >= 8.0 AND QQ = N'Miền Trung';
-- m3 = p1 ∧ ¬p3 ∧ ¬p4  (≡ QQ = 'Miền Nam')
SELECT * INTO QLSV3 FROM QLSV WHERE TB >= 8.0 AND QQ = N'Miền Nam';
-- m4 = ¬p1 ∧ p3 ∧ ¬p4
SELECT * INTO QLSV4 FROM QLSV WHERE TB <  8.0 AND QQ = N'Miền Bắc';
-- m5 = ¬p1 ∧ ¬p3 ∧ p4
SELECT * INTO QLSV5 FROM QLSV WHERE TB <  8.0 AND QQ = N'Miền Trung';
-- m6 = ¬p1 ∧ ¬p3 ∧ ¬p4
SELECT * INTO QLSV6 FROM QLSV WHERE TB <  8.0 AND QQ = N'Miền Nam';
GO

SELECT N'QLSV1 (TB>=8.0, Bắc)'   AS Manh, * FROM QLSV1;
SELECT N'QLSV2 (TB>=8.0, Trung)' AS Manh, * FROM QLSV2;
SELECT N'QLSV3 (TB>=8.0, Nam)'   AS Manh, * FROM QLSV3;
SELECT N'QLSV4 (TB<8.0, Bắc)'    AS Manh, * FROM QLSV4;
SELECT N'QLSV5 (TB<8.0, Trung)'  AS Manh, * FROM QLSV5;
SELECT N'QLSV6 (TB<8.0, Nam)'    AS Manh, * FROM QLSV6;
GO

/* ------------------------------------------------------------
   4. KIỂM TRA TÍNH ĐÚNG ĐẮN
   ------------------------------------------------------------ */

-- 4.1 TÁI THIẾT: QLSV = QLSV1 ∪ ... ∪ QLSV6
SELECT * FROM QLSV1
UNION ALL SELECT * FROM QLSV2
UNION ALL SELECT * FROM QLSV3
UNION ALL SELECT * FROM QLSV4
UNION ALL SELECT * FROM QLSV5
UNION ALL SELECT * FROM QLSV6;
GO

-- 4.2 ĐẦY ĐỦ: tổng số bộ của 6 mảnh phải bằng số bộ quan hệ gốc (= 12)
SELECT (SELECT COUNT(*) FROM QLSV)  AS SoBo_TongThe,
       (SELECT COUNT(*) FROM QLSV1) + (SELECT COUNT(*) FROM QLSV2)
     + (SELECT COUNT(*) FROM QLSV3) + (SELECT COUNT(*) FROM QLSV4)
     + (SELECT COUNT(*) FROM QLSV5) + (SELECT COUNT(*) FROM QLSV6) AS SoBo_CacManh;
GO

-- 4.3 TÁCH BIỆT: không mã sinh viên nào xuất hiện ở 2 mảnh (kết quả rỗng là ĐÚNG)
SELECT MA, COUNT(*) AS SoLanXuatHien
FROM (
    SELECT MA FROM QLSV1 UNION ALL SELECT MA FROM QLSV2
    UNION ALL SELECT MA FROM QLSV3 UNION ALL SELECT MA FROM QLSV4
    UNION ALL SELECT MA FROM QLSV5 UNION ALL SELECT MA FROM QLSV6
) T
GROUP BY MA
HAVING COUNT(*) > 1;
GO
