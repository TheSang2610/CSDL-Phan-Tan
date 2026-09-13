/* ============================================================================
   07b - ĐƯA DỮ LIỆU VỀ ĐÚNG TRẠNG THÁI TRƯỚC KHI CHẠY FILE 07
   ----------------------------------------------------------------------------
   DÙNG KHI NÀO
     Chỉ dùng khi cần CHỤP LẠI ảnh minh chứng của mục 3.7. Chạy xong file này
     thì file 07 chạy lại sẽ cho ra ĐÚNG những con số đã có trong báo cáo:

         VT009 tại KHO_A : 800 -> 750
         VT009 tại KHO_B : 150 -> 200
         Phiếu điều chuyển sinh ra mang mã  DCA001

   VÌ SAO CẦN FILE NÀY
     Mã phiếu điều chuyển sinh theo công thức MAX(số thứ tự) + 1. Nếu chạy lại
     file 07 mà không xoá phiếu cũ thì phiếu mới sẽ là DCA002, DCA003... và tồn
     kho tụt tiếp 50 mỗi lần. Ảnh chụp mới sẽ không khớp với ảnh đã nằm trong
     cuốn báo cáo, người chấm nhìn vào thấy mâu thuẫn.

   CHẠY Ở ĐÂU
     Mở cửa sổ truy vấn nối tới  MIGNON\KHO_A , chọn database  KhoA  ở ô dropdown
     trên thanh công cụ, rồi bấm F5. File tự sửa luôn dữ liệu bên KHO_B qua
     Linked Server nên không phải mở thêm cửa sổ nào.

   LƯU Ý
     Chỉ đụng tới VT009 và các phiếu điều chuyển. Không xoá gì khác.
   ============================================================================ */

USE KhoA;
GO

/* RAISERROR chỉ nhận biến hoặc hằng làm tham số thay thế, không nhận lời gọi hàm.
   Đặt DB_NAME() thẳng vào đó sẽ báo lỗi biên dịch 102 và cả khối này bị bỏ qua,
   tức là câu chặn mất tác dụng đúng lúc cần nó nhất.                              */
DECLARE @db SYSNAME = DB_NAME();
IF @db <> 'KhoA'
    RAISERROR (N'>>> ĐANG Ở SAI DATABASE (%s). Chọn KhoA ở ô dropdown SSMS rồi chạy lại. <<<',
               16, 1, @db);
ELSE
    PRINT N'Database hiện tại: ' + @db + N'  -> chạy tiếp được';
GO

PRINT N'--- TRƯỚC KHI RESET ---';
GO

SELECT N'KHO_A' AS Site, MaVT, SoLuong FROM KhoA.dbo.TonKho                      WHERE MaVT = 'VT009'
UNION ALL
SELECT N'KHO_B',        MaVT, SoLuong FROM [Mignon\KHO_B].KhoB.dbo.TonKho        WHERE MaVT = 'VT009';
GO

SELECT N'KHO_A' AS LuuTai, MaDC, MaKhoNguon, MaKhoDich, SoLuong, TrangThai
FROM   KhoA.dbo.PhieuDieuChuyen
UNION ALL
SELECT N'KHO_B', MaDC, MaKhoNguon, MaKhoDich, SoLuong, TrangThai
FROM   [Mignon\KHO_B].KhoB.dbo.PhieuDieuChuyen
ORDER  BY MaDC, LuuTai;
GO


/* ---- 1. Xoá các phiếu điều chuyển do KHO_A phát hành, ở CẢ HAI site --------
   Xoá ở kho đích trước, vì phiếu bên đó là bản sao của phiếu bên nguồn.       */
DELETE FROM [Mignon\KHO_B].KhoB.dbo.PhieuDieuChuyen WHERE MaDC LIKE 'DCA%';
DELETE FROM KhoA.dbo.PhieuDieuChuyen                WHERE MaDC LIKE 'DCA%';
GO

/* ---- 2. Đặt lại tồn kho VT009 về đúng con số bối cảnh của kịch bản T1 ------
   Kho B tồn 150, dưới mức tối thiểu 200, thiếu đúng 50 - đó là lý do nghiệp vụ
   khiến Kho Trung tâm phải điều chuyển sang 50 đơn vị.                        */
UPDATE KhoA.dbo.TonKho
SET    SoLuong = 800, NgayCapNhat = SYSDATETIME()
WHERE  MaKho = 'KHO_A' AND MaVT = 'VT009';

UPDATE [Mignon\KHO_B].KhoB.dbo.TonKho
SET    SoLuong = 150, NgayCapNhat = SYSDATETIME()
WHERE  MaKho = 'KHO_B' AND MaVT = 'VT009';
GO


PRINT N'';
PRINT N'--- SAU KHI RESET (phải là 800 / 150 và không còn phiếu DCA nào) ---';
GO

SELECT N'KHO_A' AS Site, MaVT, SoLuong FROM KhoA.dbo.TonKho                      WHERE MaVT = 'VT009'
UNION ALL
SELECT N'KHO_B',        MaVT, SoLuong FROM [Mignon\KHO_B].KhoB.dbo.TonKho        WHERE MaVT = 'VT009';
GO

SELECT COUNT(*) AS SoPhieuDieuChuyenConLai
FROM   KhoA.dbo.PhieuDieuChuyen
WHERE  MaDC LIKE 'DCA%';
GO

PRINT N'';
PRINT N'>>> Xong. Giờ mở file 07, chạy PHẦN 3, 4, 5 rồi chụp lại ảnh. <<<';
GO
