/* ============================================================================
   ĐỒ ÁN CUỐI KỲ - CSDL PHÂN TÁN - QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
   ----------------------------------------------------------------------------
   FILE 06b : DEMO ĐỒNG BỘ DANH MỤC VẬT TƯ   (ảnh minh chứng cho mục 3.6)

   CHẠY TẠI : MIGNON\KHO_A   (bấm F5 một lần, chạy hết từ trên xuống)

   Script chứng minh: sửa danh mục ở Kho Trung tâm thì hai kho kia TỰ ĐỘNG
   cập nhật theo, không cần ai can thiệp - đúng yêu cầu "Đồng bộ danh mục
   vật tư" của đề bài.

   CÁCH CHỤP ẢNH
     Chạy xong, cửa sổ Results sẽ có 3 bảng kết quả xếp chồng nhau:
        Bảng 1 - TRƯỚC khi sửa   (3 site giống nhau)
        Bảng 2 - Lệnh sửa đã chạy tại KHO_A
        Bảng 3 - SAU khi sửa     (3 site ĐỀU đã đổi theo)
     Chụp cả câu lệnh lẫn 3 bảng kết quả -> 1 ảnh là đủ minh chứng.
   ============================================================================ */

SET NOCOUNT ON;
USE KhoA;
GO

/* ----------------------------------------------------------------------------
   BƯỚC 1 - CHỤP TRẠNG THÁI TRƯỚC KHI SỬA (đọc cả 3 site qua Linked Server)
   ---------------------------------------------------------------------------- */
PRINT N'===== BƯỚC 1: TRƯỚC KHI SỬA =====';

SELECT N'KHO_A (Trung tâm)' AS Site, MaVT, TenVT, DonGia, MucTonToiThieu
FROM   KhoA.dbo.VatTu WHERE MaVT IN ('VT001','VT099')
UNION ALL
SELECT N'KHO_B (Miền Bắc)', MaVT, TenVT, DonGia, MucTonToiThieu
FROM   [Mignon\KHO_B].KhoB.dbo.VatTu WHERE MaVT IN ('VT001','VT099')
UNION ALL
SELECT N'KHO_C (Miền Nam)', MaVT, TenVT, DonGia, MucTonToiThieu
FROM   [Mignon\KHO_C].KhoC.dbo.VatTu WHERE MaVT IN ('VT001','VT099')
ORDER BY MaVT, Site;
GO

/* ----------------------------------------------------------------------------
   BƯỚC 2 - SỬA DANH MỤC, CHỈ TẠI KHO TRUNG TÂM

   Ba thao tác để chứng minh cả ba loại lệnh đều được nhân bản:
     UPDATE : đổi giá và tên vật tư VT001
     INSERT : thêm vật tư mới VT099
   (DELETE được kiểm chứng ở bước 5 khi hoàn tác)
   ---------------------------------------------------------------------------- */
PRINT N'';
PRINT N'===== BƯỚC 2: SỬA DANH MỤC TẠI KHO_A =====';

UPDATE VatTu
SET    DonGia = 123456,
       TenVT  = N'Xi măng PCB40 - GIÁ MỚI do Kho Trung tâm cập nhật'
WHERE  MaVT = 'VT001';

IF NOT EXISTS (SELECT 1 FROM VatTu WHERE MaVT = 'VT099')
    INSERT INTO VatTu (MaVT, TenVT, DonViTinh, DonGia, MaNCC, MucTonToiThieu)
    VALUES ('VT099', N'Vật tư MỚI khai báo tại Kho Trung tâm', N'Cái', 777000, 'NCC01', 5);

PRINT N'   Đã UPDATE VT001 và INSERT VT099 tại KHO_A';
PRINT N'   (hai kho còn lại KHÔNG hề được đụng tới)';
GO

/* ----------------------------------------------------------------------------
   BƯỚC 3 - CHỜ DISTRIBUTION AGENT ĐẨY XUỐNG SUBSCRIBER
   ---------------------------------------------------------------------------- */
PRINT N'';
PRINT N'===== BƯỚC 3: CHỜ 20 GIÂY CHO REPLICATION CHẠY =====';
WAITFOR DELAY '00:00:20';
GO

/* ----------------------------------------------------------------------------
   BƯỚC 4 - KIỂM CHỨNG: HAI KHO KIA ĐÃ TỰ ĐỘNG CẬP NHẬT
   ---------------------------------------------------------------------------- */
PRINT N'';
PRINT N'===== BƯỚC 4: SAU KHI ĐỒNG BỘ =====';

SELECT N'KHO_A (Trung tâm)' AS Site, MaVT, TenVT, DonGia
FROM   KhoA.dbo.VatTu WHERE MaVT IN ('VT001','VT099')
UNION ALL
SELECT N'KHO_B (Miền Bắc)', MaVT, TenVT, DonGia
FROM   [Mignon\KHO_B].KhoB.dbo.VatTu WHERE MaVT IN ('VT001','VT099')
UNION ALL
SELECT N'KHO_C (Miền Nam)', MaVT, TenVT, DonGia
FROM   [Mignon\KHO_C].KhoC.dbo.VatTu WHERE MaVT IN ('VT001','VT099')
ORDER BY MaVT, Site;
GO

-- Đếm tổng số vật tư ở 3 site: phải BẰNG NHAU thì mới là đồng bộ đúng
SELECT N'KHO_A' AS Site, COUNT(*) AS SoVatTu FROM KhoA.dbo.VatTu
UNION ALL
SELECT N'KHO_B', COUNT(*) FROM [Mignon\KHO_B].KhoB.dbo.VatTu
UNION ALL
SELECT N'KHO_C', COUNT(*) FROM [Mignon\KHO_C].KhoC.dbo.VatTu;
GO

/* ----------------------------------------------------------------------------
   BƯỚC 5 - HOÀN TÁC, ĐỒNG THỜI KIỂM CHỨNG LỆNH DELETE CŨNG ĐƯỢC NHÂN BẢN

   Bỏ chú thích khối dưới nếu muốn trả dữ liệu về trạng thái gốc.
   ---------------------------------------------------------------------------- */
/*
DELETE FROM VatTu WHERE MaVT = 'VT099';
UPDATE VatTu SET DonGia = 95000, TenVT = N'Xi măng PCB40' WHERE MaVT = 'VT001';
WAITFOR DELAY '00:00:15';

SELECT N'KHO_A' AS Site, COUNT(*) AS SoVatTu FROM KhoA.dbo.VatTu
UNION ALL SELECT N'KHO_B', COUNT(*) FROM [Mignon\KHO_B].KhoB.dbo.VatTu
UNION ALL SELECT N'KHO_C', COUNT(*) FROM [Mignon\KHO_C].KhoC.dbo.VatTu;
-- cả 3 phải cùng quay về 10 vật tư => DELETE đã được nhân bản
*/

/* ----------------------------------------------------------------------------
   BƯỚC 6 - XEM TÌNH TRẠNG CÁC AGENT (ảnh phụ cho báo cáo)
   ---------------------------------------------------------------------------- */
PRINT N'';
PRINT N'===== TÌNH TRẠNG CÁC REPLICATION AGENT =====';

SELECT TOP 10
       LEFT(a.name, 45) AS DistributionAgent,
       CASE h.runstatus WHEN 1 THEN N'Bắt đầu'  WHEN 2 THEN N'Thành công'
                        WHEN 3 THEN N'Đang chạy' WHEN 4 THEN N'Rảnh'
                        WHEN 5 THEN N'Thử lại'   WHEN 6 THEN N'LỖI' END AS TrangThai,
       LEFT(h.comments, 90) AS ThongBao,
       h.time AS ThoiDiem
FROM   distribution.dbo.MSdistribution_history h
JOIN   distribution.dbo.MSdistribution_agents a ON a.id = h.agent_id
ORDER BY h.time DESC;
GO
