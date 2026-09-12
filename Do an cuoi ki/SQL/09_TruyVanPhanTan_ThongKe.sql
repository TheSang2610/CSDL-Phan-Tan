/* ============================================================================
   ĐỒ ÁN CUỐI KỲ - CSDL PHÂN TÁN - QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
   ----------------------------------------------------------------------------
   FILE 09 : TRUY VẤN PHÂN TÁN - HIỂN THỊ DỮ LIỆU - THỐNG KÊ

   Đáp ứng:
     · Yêu cầu chung  A10 : ít nhất 1 distributed query
     · Yêu cầu đề tài B9  : "Kiểm tra tồn kho toàn hệ thống"
     · Mục báo cáo  3.7b  : Hiển thị dữ liệu - kiểm tra đồng bộ / nhân bản /
                            phân mảnh / linkserver
     · Mục báo cáo  3.7c  : Thống kê - kiểm tra đồng bộ / nhân bản /
                            phân mảnh / linkserver

   CHẠY TẠI : MIGNON\KHO_A   (Kho Trung tâm - nơi ban giám đốc xem toàn cảnh)

   ----------------------------------------------------------------------------
   CÁCH CHỤP ẢNH
     File này chia làm 7 PHẦN, mỗi phần là một ảnh. ĐỪNG bấm F5 chạy cả file
     (ra hơn 20 bảng, chụp không nổi). Hãy BÔI ĐEN từng phần rồi bấm F5 —
     SSMS chỉ chạy đúng phần được bôi đen.

        PHẦN 2  ->  09_HienThi_TonKhoToanHeThong.png
        PHẦN 3  ->  10_ThongKe_ToanHeThong.png
        PHẦN 4  ->  11_CanhBao_ThieuHang_GoiYDieuChuyen.png
        PHẦN 5  ->  12_KiemTra_PhanManh.png
        PHẦN 6  ->  13_KiemTra_NhanBan_DongBo.png
        PHẦN 7  ->  14_KiemTra_LinkedServer.png
        PHẦN 8  ->  15_SoSanh_LinkedServer_vs_OpenQuery.png

     Lưu hết vào  AnhChup\3.7_KetQua_GiaoTac\
   ============================================================================ */


/* ############################################################################
   PHẦN 1 - TẠO CÁC KHUNG NHÌN PHÂN TÁN       (chạy 1 lần, không cần chụp ảnh)

   Ý NGHĨA LÝ THUYẾT - TRONG SUỐT PHÂN MẢNH (Fragmentation Transparency)

   Quan hệ toàn cục TonKho bị cắt thành 3 mảnh nằm ở 3 máy khác nhau:

        TonKho_A = σ(MaKho='KHO_A')(TonKho)   nằm tại Mignon\KHO_A
        TonKho_B = σ(MaKho='KHO_B')(TonKho)   nằm tại Mignon\KHO_B
        TonKho_C = σ(MaKho='KHO_C')(TonKho)   nằm tại Mignon\KHO_C

   Phép TÁI THIẾT (reconstruction) của phân mảnh ngang là hợp:

        TonKho = TonKho_A ∪ TonKho_B ∪ TonKho_C

   View dưới đây hiện thực hoá đúng phép hợp đó. Nhờ nó, người dùng viết
   "SELECT * FROM v_TonKho_ToanHeThong" y như đang làm việc với MỘT bảng duy
   nhất, KHÔNG cần biết dữ liệu nằm ở ba máy - đó chính là trong suốt phân mảnh.
   ############################################################################ */
USE KhoA;
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.v_TonKho_ToanHeThong', 'V') IS NOT NULL
    DROP VIEW dbo.v_TonKho_ToanHeThong;
GO
CREATE VIEW dbo.v_TonKho_ToanHeThong AS
    SELECT MaKho, MaVT, SoLuong, NgayCapNhat FROM KhoA.dbo.TonKho
    UNION ALL
    SELECT MaKho, MaVT, SoLuong, NgayCapNhat FROM [Mignon\KHO_B].KhoB.dbo.TonKho
    UNION ALL
    SELECT MaKho, MaVT, SoLuong, NgayCapNhat FROM [Mignon\KHO_C].KhoC.dbo.TonKho;
GO

/* Khung nhìn thứ hai: ghép tồn kho với DANH MỤC vật tư.
   Danh mục được NHÂN BẢN về cả 3 site nên ở đây chỉ cần đọc bản địa phương
   -> phép JOIN chạy TẠI CHỖ, không tốn thêm một vòng qua mạng nào.
   Đây là lợi ích trực tiếp của việc nhân bản danh mục.                       */
IF OBJECT_ID('dbo.v_TonKho_ChiTiet', 'V') IS NOT NULL
    DROP VIEW dbo.v_TonKho_ChiTiet;
GO
CREATE VIEW dbo.v_TonKho_ChiTiet AS
    SELECT  t.MaKho,
            k.TenKho,
            t.MaVT,
            v.TenVT,
            v.DonViTinh,
            t.SoLuong,
            v.DonGia,
            t.SoLuong * v.DonGia AS GiaTriTon,
            v.MucTonToiThieu,
            t.NgayCapNhat
    FROM    dbo.v_TonKho_ToanHeThong t
    JOIN    KhoA.dbo.VatTu v ON v.MaVT  = t.MaVT      -- bảng nhân bản, đọc tại chỗ
    JOIN    KhoA.dbo.Kho   k ON k.MaKho = t.MaKho;    -- bảng nhân bản, đọc tại chỗ
GO

PRINT N'✔ Đã tạo v_TonKho_ToanHeThong và v_TonKho_ChiTiet tại KHO_A';
GO


/* ############################################################################
   PHẦN 2 - HIỂN THỊ DỮ LIỆU : TỒN KHO TOÀN HỆ THỐNG      📷 ẢNH 09
            (yêu cầu B9 của đề tài - "Kiểm tra tồn kho toàn hệ thống")
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  PHẦN 2 - TỒN KHO TOÀN HỆ THỐNG (dữ liệu lấy từ CẢ BA MÁY)       ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

-- 2.1  Toàn bộ tồn kho của 3 site, gộp thành MỘT bảng duy nhất
SELECT  MaKho, TenKho, MaVT, TenVT, DonViTinh, SoLuong,
        FORMAT(GiaTriTon, 'N0') AS GiaTriTon_VND
FROM    dbo.v_TonKho_ChiTiet
ORDER BY MaKho, MaVT;
GO

-- 2.2  Tra cứu MỘT vật tư trên toàn hệ thống: nó đang nằm ở đâu, còn bao nhiêu
DECLARE @VatTuCanTim CHAR(5) = 'VT009';

SELECT  MaKho, TenKho, TenVT, SoLuong, MucTonToiThieu,
        CASE WHEN SoLuong < MucTonToiThieu
             THEN N'⚠ DƯỚI MỨC TỐI THIỂU'
             ELSE N'đủ' END AS TinhTrang
FROM    dbo.v_TonKho_ChiTiet
WHERE   MaVT = @VatTuCanTim
ORDER BY MaKho;

SELECT  N'TỔNG TOÀN HỆ THỐNG' AS Muc,
        @VatTuCanTim          AS MaVT,
        SUM(SoLuong)          AS TongSoLuong,
        COUNT(*)              AS SoKhoDangGiu
FROM    dbo.v_TonKho_ChiTiet
WHERE   MaVT = @VatTuCanTim;
GO

/*  Ý nghĩa của truy vấn 2.2 cho báo cáo:
    Một câu SELECT duy nhất, nhưng bộ tối ưu đã phải mở 2 kết nối qua Linked
    Server, lấy dữ liệu từ Mignon\KHO_B và Mignon\KHO_C, gộp với dữ liệu tại
    chỗ rồi mới tính SUM. Người dùng hoàn toàn không thấy điều đó.
    -> ĐÂY LÀ DISTRIBUTED QUERY theo đúng nghĩa của môn học.                  */


/* ############################################################################
   PHẦN 3 - THỐNG KÊ TOÀN HỆ THỐNG                         📷 ẢNH 10
            (mục báo cáo 3.7c)
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  PHẦN 3 - THỐNG KÊ TOÀN HỆ THỐNG                                 ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

-- 3.1  Thống kê theo TỪNG KHO: quy mô và giá trị hàng hoá mỗi chi nhánh đang giữ
SELECT  MaKho,
        TenKho,
        COUNT(*)                        AS SoMatHang,
        SUM(SoLuong)                    AS TongSoLuong,
        FORMAT(SUM(GiaTriTon), 'N0')    AS TongGiaTri_VND,
        SUM(CASE WHEN SoLuong < MucTonToiThieu THEN 1 ELSE 0 END) AS SoMatHangThieu
FROM    dbo.v_TonKho_ChiTiet
GROUP BY MaKho, TenKho

UNION ALL

SELECT  N'  *  ', N'>>> CỘNG TOÀN HỆ THỐNG',
        COUNT(*), SUM(SoLuong), FORMAT(SUM(GiaTriTon), 'N0'),
        SUM(CASE WHEN SoLuong < MucTonToiThieu THEN 1 ELSE 0 END)
FROM    dbo.v_TonKho_ChiTiet
ORDER BY MaKho;
GO

-- 3.2  Thống kê theo TỪNG VẬT TƯ: mặt hàng nào đang nhiều nhất toàn công ty
SELECT  MaVT,
        TenVT,
        DonViTinh,
        SUM(SoLuong)                                  AS TongToanHeThong,
        SUM(CASE WHEN MaKho='KHO_A' THEN SoLuong END) AS Tai_KHO_A,
        SUM(CASE WHEN MaKho='KHO_B' THEN SoLuong END) AS Tai_KHO_B,
        SUM(CASE WHEN MaKho='KHO_C' THEN SoLuong END) AS Tai_KHO_C,
        COUNT(*)                                      AS SoKhoDangGiu
FROM    dbo.v_TonKho_ChiTiet
GROUP BY MaVT, TenVT, DonViTinh
ORDER BY TongToanHeThong DESC;
GO

-- 3.3  Năm mặt hàng chiếm nhiều vốn nhất - phục vụ ra quyết định của giám đốc
SELECT  TOP 5
        MaVT, TenVT,
        SUM(SoLuong)                 AS TongSoLuong,
        FORMAT(SUM(GiaTriTon),'N0')  AS TongGiaTri_VND,
        FORMAT(100.0 * SUM(GiaTriTon)
               / (SELECT SUM(GiaTriTon) FROM dbo.v_TonKho_ChiTiet), 'N2') + N' %'
                                     AS TyTrongVon
FROM    dbo.v_TonKho_ChiTiet
GROUP BY MaVT, TenVT
ORDER BY SUM(GiaTriTon) DESC;
GO

-- 3.4  Thống kê CHỨNG TỪ đã phát sinh ở cả 3 site (phiếu nhập / xuất / điều chuyển)
SELECT  N'KHO_A' AS Site,
        (SELECT COUNT(*) FROM KhoA.dbo.PhieuNhap)        AS SoPhieuNhap,
        (SELECT COUNT(*) FROM KhoA.dbo.PhieuXuat)        AS SoPhieuXuat,
        (SELECT COUNT(*) FROM KhoA.dbo.PhieuDieuChuyen)  AS SoPhieuDieuChuyen
UNION ALL
SELECT  N'KHO_B',
        (SELECT COUNT(*) FROM [Mignon\KHO_B].KhoB.dbo.PhieuNhap),
        (SELECT COUNT(*) FROM [Mignon\KHO_B].KhoB.dbo.PhieuXuat),
        (SELECT COUNT(*) FROM [Mignon\KHO_B].KhoB.dbo.PhieuDieuChuyen)
UNION ALL
SELECT  N'KHO_C',
        (SELECT COUNT(*) FROM [Mignon\KHO_C].KhoC.dbo.PhieuNhap),
        (SELECT COUNT(*) FROM [Mignon\KHO_C].KhoC.dbo.PhieuXuat),
        (SELECT COUNT(*) FROM [Mignon\KHO_C].KhoC.dbo.PhieuDieuChuyen);
GO


/* ############################################################################
   PHẦN 4 - CẢNH BÁO THIẾU HÀNG + GỢI Ý ĐIỀU CHUYỂN        📷 ẢNH 11

   Đây là truy vấn phân tán CÓ GIÁ TRỊ NGHIỆP VỤ THẬT, không chỉ để minh hoạ:
   nó tìm mặt hàng đang dưới mức tối thiểu ở kho này, đồng thời chỉ ra kho nào
   đang dư để điều chuyển sang. Kết quả của nó chính là đầu vào cho thủ tục
   sp_DieuChuyenVatTu ở file 07.
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  PHẦN 4 - CẢNH BÁO THIẾU HÀNG VÀ GỢI Ý KHO CẤP BÙ                ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

WITH Thieu AS (          -- kho nào đang dưới mức tối thiểu
    SELECT MaKho, TenKho, MaVT, TenVT, SoLuong, MucTonToiThieu,
           MucTonToiThieu - SoLuong AS SoLuongCanBu
    FROM   dbo.v_TonKho_ChiTiet
    WHERE  SoLuong < MucTonToiThieu
),
Du AS (                  -- kho nào còn dư trên mức tối thiểu
    SELECT MaKho, TenKho, MaVT, SoLuong - MucTonToiThieu AS SoLuongCoTheCho
    FROM   dbo.v_TonKho_ChiTiet
    WHERE  SoLuong > MucTonToiThieu
)
SELECT  t.MaKho          AS KhoThieu,
        t.TenKho         AS TenKhoThieu,
        t.MaVT, t.TenVT,
        t.SoLuong        AS TonHienCo,
        t.MucTonToiThieu AS MucToiThieu,
        t.SoLuongCanBu   AS CanBoSung,
        d.MaKho          AS KhoCoTheCapBu,
        d.SoLuongCoTheCho,
        CASE WHEN d.MaKho IS NULL
             THEN N'✘ Không kho nào dư - phải MUA THÊM từ nhà cung cấp'
             WHEN d.SoLuongCoTheCho >= t.SoLuongCanBu
             THEN N'✔ Điều chuyển ' + CAST(t.SoLuongCanBu AS NVARCHAR(10))
                  + N' đơn vị từ ' + d.MaKho + N' sang ' + t.MaKho
             ELSE N'⚠ Chỉ bù được một phần'
        END              AS DeXuatXuLy
FROM    Thieu t
LEFT JOIN Du d ON d.MaVT = t.MaVT
ORDER BY t.MaKho, t.MaVT;
GO


/* ############################################################################
   PHẦN 5 - KIỂM TRA PHÂN MẢNH                             📷 ẢNH 12
            (mục 3.7b - "kiểm tra phân mảnh")

   Lý thuyết yêu cầu một phép phân mảnh phải thoả BA TÍNH CHẤT.
   Ba truy vấn dưới đây kiểm chứng đúng ba tính chất đó bằng số liệu thật.
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  PHẦN 5 - KIỂM TRA 3 TÍNH CHẤT CỦA PHÂN MẢNH NGANG               ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

/* 5.1  TÍNH TÁCH RỜI (Disjointness)
        Mỗi mảnh chỉ được chứa ĐÚNG MỘT mã kho, và các mảnh không giao nhau.
        Ràng buộc CHECK (MaKho='KHO_x') ở mỗi site cưỡng chế điều này ngay
        tại tầng CSDL, không phụ thuộc vào lập trình viên có nhớ hay không.  */
SELECT  N'5.1 TÁCH RỜI' AS PhepKiemTra, N'KHO_A' AS Site,
        COUNT(DISTINCT MaKho) AS SoMaKhoKhacNhau,
        MIN(MaKho) AS MaKhoDuyNhat, COUNT(*) AS SoDong
FROM    KhoA.dbo.TonKho
UNION ALL
SELECT  N'5.1 TÁCH RỜI', N'KHO_B', COUNT(DISTINCT MaKho), MIN(MaKho), COUNT(*)
FROM    [Mignon\KHO_B].KhoB.dbo.TonKho
UNION ALL
SELECT  N'5.1 TÁCH RỜI', N'KHO_C', COUNT(DISTINCT MaKho), MIN(MaKho), COUNT(*)
FROM    [Mignon\KHO_C].KhoC.dbo.TonKho;
GO

-- Không một cặp (MaKho, MaVT) nào được xuất hiện ở hai site khác nhau
SELECT  N'5.1 TÁCH RỜI - TÌM DÒNG TRÙNG GIỮA CÁC MẢNH' AS PhepKiemTra,
        COUNT(*) AS SoDongBiTrung,
        CASE WHEN COUNT(*) = 0 THEN N'✔ ĐẠT - các mảnh hoàn toàn rời nhau'
             ELSE N'✘ HỎNG - có dữ liệu bị lặp giữa hai site' END AS KetLuan
FROM (  SELECT MaKho, MaVT FROM dbo.v_TonKho_ToanHeThong
        GROUP BY MaKho, MaVT HAVING COUNT(*) > 1 ) x;
GO

/* 5.2  TÍNH ĐẦY ĐỦ (Completeness)
        Mọi dòng của quan hệ toàn cục phải nằm trong ít nhất một mảnh.
        Kiểm chứng: mỗi kho trong danh mục Kho đều phải có mảnh tương ứng,
        và mọi vật tư có tồn đều phải thuộc danh mục.                        */
SELECT  N'5.2 ĐẦY ĐỦ' AS PhepKiemTra,
        (SELECT COUNT(*) FROM KhoA.dbo.Kho)                     AS SoKhoTrongDanhMuc,
        (SELECT COUNT(DISTINCT MaKho) FROM dbo.v_TonKho_ToanHeThong) AS SoMangCoDuLieu,
        CASE WHEN (SELECT COUNT(*) FROM KhoA.dbo.Kho)
                = (SELECT COUNT(DISTINCT MaKho) FROM dbo.v_TonKho_ToanHeThong)
             THEN N'✔ ĐẠT - không kho nào bị bỏ sót'
             ELSE N'✘ THIẾU MẢNH' END AS KetLuan;
GO

/* 5.3  TÍNH TÁI THIẾT (Reconstruction)
        TonKho = TonKho_A ∪ TonKho_B ∪ TonKho_C
        Tổng số dòng của ba mảnh phải bằng số dòng của quan hệ toàn cục.     */
SELECT  N'5.3 TÁI THIẾT' AS PhepKiemTra,
        (SELECT COUNT(*) FROM KhoA.dbo.TonKho)                       AS Manh_A,
        (SELECT COUNT(*) FROM [Mignon\KHO_B].KhoB.dbo.TonKho)        AS Manh_B,
        (SELECT COUNT(*) FROM [Mignon\KHO_C].KhoC.dbo.TonKho)        AS Manh_C,
        (SELECT COUNT(*) FROM KhoA.dbo.TonKho)
      + (SELECT COUNT(*) FROM [Mignon\KHO_B].KhoB.dbo.TonKho)
      + (SELECT COUNT(*) FROM [Mignon\KHO_C].KhoC.dbo.TonKho)        AS CongBaManh,
        (SELECT COUNT(*) FROM dbo.v_TonKho_ToanHeThong)              AS QuanHeToanCuc,
        N'✔ ĐẠT nếu hai cột cuối bằng nhau'                          AS KetLuan;
GO

/* 5.4  PHÂN MẢNH NGANG DẪN XUẤT (Derived Horizontal Fragmentation)
        ChiTietNhap_i = ChiTietNhap ⋉ PhieuNhap_i   (nửa nối - semijoin)
        Nghĩa là: chi tiết phiếu phải đi theo đúng phiếu của site mình,
        không được có dòng chi tiết "mồ côi" thuộc phiếu của site khác.      */
SELECT  N'5.4 DẪN XUẤT - KHO_A' AS PhepKiemTra,
        (SELECT COUNT(*) FROM KhoA.dbo.ChiTietNhap)  AS SoDongChiTietNhap,
        (SELECT COUNT(*) FROM KhoA.dbo.ChiTietNhap c
          JOIN KhoA.dbo.PhieuNhap p ON p.MaPN = c.MaPN
         WHERE p.MaKho = 'KHO_A')                    AS SoDongThuocDungManh,
        (SELECT COUNT(*) FROM KhoA.dbo.ChiTietXuat)  AS SoDongChiTietXuat,
        (SELECT COUNT(*) FROM KhoA.dbo.ChiTietXuat c
          JOIN KhoA.dbo.PhieuXuat p ON p.MaPX = c.MaPX
         WHERE p.MaKho = 'KHO_A')                    AS SoDongXuatDungManh,
        N'✔ ĐẠT nếu cột 1 = cột 2 và cột 3 = cột 4'  AS KetLuan;
GO

/* 5.5  THỬ VI PHẠM PHÂN MẢNH - ràng buộc phải CHẶN LẠI
        Cố tình ghi một dòng của KHO_B vào mảnh của KHO_A.
        Hệ thống phải từ chối bằng lỗi ràng buộc CK_TonKho_Manh.             */
BEGIN TRY
    INSERT INTO KhoA.dbo.TonKho (MaKho, MaVT, SoLuong) VALUES ('KHO_B', 'VT005', 1);
    SELECT N'5.5 THỬ VI PHẠM' AS PhepKiemTra,
           N'✘ NGUY HIỂM - ghi được dữ liệu sai mảnh!' AS KetLuan;
    DELETE FROM KhoA.dbo.TonKho WHERE MaKho = 'KHO_B';   -- dọn nếu lỡ ghi được
END TRY
BEGIN CATCH
    SELECT N'5.5 THỬ VI PHẠM' AS PhepKiemTra,
           ERROR_NUMBER()     AS SoHieuLoi,
           N'✔ ĐẠT - ràng buộc CK_TonKho_Manh đã CHẶN dữ liệu sai mảnh' AS KetLuan,
           LEFT(ERROR_MESSAGE(), 120) AS ThongBaoLoi;
END CATCH
GO


/* ############################################################################
   PHẦN 6 - KIỂM TRA NHÂN BẢN / ĐỒNG BỘ                    📷 ẢNH 13
            (mục 3.7b - "kiểm tra đồng bộ, nhân bản")

   Bảng TonKho thì PHÂN MẢNH (mỗi site một phần khác nhau).
   Bảng danh mục VatTu, NhaCungCap, Kho thì NHÂN BẢN (ba site phải GIỐNG HỆT).
   Phần này chứng minh ba bản sao đang khớp nhau từng dòng, từng cột.
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  PHẦN 6 - KIỂM TRA BA BẢN SAO DANH MỤC CÓ KHỚP NHAU KHÔNG        ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

/* 6.1  So khớp bằng CHECKSUM_AGG - "vân tay" của toàn bộ bảng.
        Chỉ cần MỘT ô dữ liệu lệch nhau là vân tay đổi ngay.                 */
SELECT  N'KHO_A (Publisher)' AS Site,
        COUNT(*)                                                  AS SoVatTu,
        SUM(CAST(DonGia AS BIGINT))                               AS TongDonGia,
        CHECKSUM_AGG(CHECKSUM(MaVT, TenVT, DonViTinh, DonGia, MaNCC, MucTonToiThieu)) AS VanTayBang
FROM    KhoA.dbo.VatTu
UNION ALL
SELECT  N'KHO_B (Subscriber)',
        COUNT(*), SUM(CAST(DonGia AS BIGINT)),
        CHECKSUM_AGG(CHECKSUM(MaVT, TenVT, DonViTinh, DonGia, MaNCC, MucTonToiThieu))
FROM    [Mignon\KHO_B].KhoB.dbo.VatTu
UNION ALL
SELECT  N'KHO_C (Subscriber)',
        COUNT(*), SUM(CAST(DonGia AS BIGINT)),
        CHECKSUM_AGG(CHECKSUM(MaVT, TenVT, DonViTinh, DonGia, MaNCC, MucTonToiThieu))
FROM    [Mignon\KHO_C].KhoC.dbo.VatTu;
GO

-- Kết luận tự động: ba vân tay phải bằng nhau
WITH VT AS (
    SELECT CHECKSUM_AGG(CHECKSUM(MaVT,TenVT,DonViTinh,DonGia,MaNCC,MucTonToiThieu)) AS V
    FROM KhoA.dbo.VatTu
    UNION ALL
    SELECT CHECKSUM_AGG(CHECKSUM(MaVT,TenVT,DonViTinh,DonGia,MaNCC,MucTonToiThieu))
    FROM [Mignon\KHO_B].KhoB.dbo.VatTu
    UNION ALL
    SELECT CHECKSUM_AGG(CHECKSUM(MaVT,TenVT,DonViTinh,DonGia,MaNCC,MucTonToiThieu))
    FROM [Mignon\KHO_C].KhoC.dbo.VatTu
)
SELECT  N'6.1 SO KHỚP VÂN TAY BẢNG VatTu' AS PhepKiemTra,
        COUNT(DISTINCT V)                 AS SoVanTayKhacNhau,
        CASE WHEN COUNT(DISTINCT V) = 1
             THEN N'✔ ĐẠT - ba bản sao GIỐNG HỆT nhau, replication đang khoẻ'
             ELSE N'✘ LỆCH - có site chưa nhận được dữ liệu mới' END AS KetLuan
FROM    VT;
GO

/* 6.2  Nếu có lệch thì lệch ở dòng nào - dùng EXCEPT để chỉ mặt đặt tên.
        Không ra dòng nào = hoàn toàn đồng bộ.                               */
SELECT N'Có ở KHO_A, THIẾU ở KHO_B' AS TinhTrang, MaVT, TenVT, DonGia
FROM   ( SELECT MaVT, TenVT, DonGia FROM KhoA.dbo.VatTu
         EXCEPT
         SELECT MaVT, TenVT, DonGia FROM [Mignon\KHO_B].KhoB.dbo.VatTu ) a
UNION ALL
SELECT N'Có ở KHO_A, THIẾU ở KHO_C', MaVT, TenVT, DonGia
FROM   ( SELECT MaVT, TenVT, DonGia FROM KhoA.dbo.VatTu
         EXCEPT
         SELECT MaVT, TenVT, DonGia FROM [Mignon\KHO_C].KhoC.dbo.VatTu ) b
UNION ALL
SELECT N'Có ở KHO_B, KHÔNG có ở KHO_A (dữ liệu lạ)', MaVT, TenVT, DonGia
FROM   ( SELECT MaVT, TenVT, DonGia FROM [Mignon\KHO_B].KhoB.dbo.VatTu
         EXCEPT
         SELECT MaVT, TenVT, DonGia FROM KhoA.dbo.VatTu ) c;
GO

-- 6.3  Kiểm tra nốt hai bảng danh mục còn lại
SELECT  N'NhaCungCap' AS Bang,
        (SELECT COUNT(*) FROM KhoA.dbo.NhaCungCap)                  AS Tai_A,
        (SELECT COUNT(*) FROM [Mignon\KHO_B].KhoB.dbo.NhaCungCap)   AS Tai_B,
        (SELECT COUNT(*) FROM [Mignon\KHO_C].KhoC.dbo.NhaCungCap)   AS Tai_C
UNION ALL
SELECT  N'Kho',
        (SELECT COUNT(*) FROM KhoA.dbo.Kho),
        (SELECT COUNT(*) FROM [Mignon\KHO_B].KhoB.dbo.Kho),
        (SELECT COUNT(*) FROM [Mignon\KHO_C].KhoC.dbo.Kho)
UNION ALL
SELECT  N'VatTu',
        (SELECT COUNT(*) FROM KhoA.dbo.VatTu),
        (SELECT COUNT(*) FROM [Mignon\KHO_B].KhoB.dbo.VatTu),
        (SELECT COUNT(*) FROM [Mignon\KHO_C].KhoC.dbo.VatTu);
GO

-- 6.4  Tình trạng Publication và các Subscription đang chạy
SELECT  p.name                 AS TenPublication,
        p.description          AS MoTa,
        CASE p.status WHEN 1 THEN N'Đang hoạt động' ELSE N'Không hoạt động' END AS TrangThai,
        (SELECT COUNT(*) FROM KhoA.dbo.sysarticles a WHERE a.pubid = p.pubid) AS SoBangDuocNhanBan
FROM    KhoA.dbo.syspublications p;

-- Mỗi Subscriber nhận đủ 3 bảng nên gom DISTINCT cho gọn
SELECT DISTINCT
        s.srvname              AS Subscriber,
        s.dest_db              AS CSDL_Dich,
        CASE s.status WHEN 0 THEN N'Không hoạt động'
                      WHEN 1 THEN N'Đã đăng ký'
                      WHEN 2 THEN N'Đang hoạt động' END AS TrangThai,
        CASE s.sync_type WHEN 1 THEN N'Tự động (có snapshot)'
                         WHEN 2 THEN N'Không snapshot'
                         ELSE N'Chỉ hỗ trợ replication' END AS KieuDongBo,
        COUNT(*) OVER (PARTITION BY s.srvname) AS SoBangNhanDuoc
FROM    KhoA.dbo.syssubscriptions s
WHERE   s.srvname <> @@SERVERNAME;
GO


/* ############################################################################
   PHẦN 7 - KIỂM TRA LINKED SERVER                         📷 ẢNH 14
            (mục 3.7b - "kiểm tra linkserver")
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  PHẦN 7 - KIỂM TRA CÁC ĐƯỜNG LIÊN KẾT GIỮA BA MÁY CHỦ            ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

-- 7.1  Danh sách Linked Server và các tuỳ chọn quan trọng
SELECT  s.name                    AS LinkedServer,
        s.product                 AS SanPham,
        s.provider                AS TrinhCungCap,
        s.data_source             AS NguonDuLieu,
        s.is_data_access_enabled  AS ChoDocDuLieu,
        s.is_rpc_out_enabled      AS ChoGoiThuTucTuXa,
        s.is_remote_proc_transaction_promotion_enabled AS NangLenGiaoTacPhanTan
FROM    sys.servers s
WHERE   s.is_linked = 1;
GO

-- 7.2  Ánh xạ đăng nhập của từng đường liên kết
SELECT  s.name          AS LinkedServer,
        l.remote_name   AS TaiKhoanDangNhapTuXa,
        CASE WHEN l.uses_self_credential = 1
             THEN N'Dùng chính tài khoản người gọi'
             ELSE N'Ánh xạ sang tài khoản cố định' END AS KieuAnhXa
FROM    sys.linked_logins l
JOIN    sys.servers s ON s.server_id = l.server_id
WHERE   s.is_linked = 1;
GO

-- 7.3  Bấm thử từng đường liên kết xem có THÔNG không
DECLARE @Link NVARCHAR(128), @Loi NVARCHAR(400);
DECLARE @KetQua TABLE (LinkedServer NVARCHAR(128), TrangThai NVARCHAR(400));

DECLARE cur CURSOR FOR
    SELECT name FROM sys.servers WHERE is_linked = 1 ORDER BY name;
OPEN cur;
FETCH NEXT FROM cur INTO @Link;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC sys.sp_testlinkedserver @Link;
        INSERT INTO @KetQua VALUES (@Link, N'✔ THÔNG');
    END TRY
    BEGIN CATCH
        SET @Loi = LEFT(ERROR_MESSAGE(), 200);
        INSERT INTO @KetQua VALUES (@Link, N'✘ KHÔNG THÔNG: ' + @Loi);
    END CATCH
    FETCH NEXT FROM cur INTO @Link;
END
CLOSE cur; DEALLOCATE cur;

SELECT N'7.3 THỬ KẾT NỐI' AS PhepKiemTra, * FROM @KetQua;
GO

-- 7.4  Đọc ngược thông tin phiên bản của hai máy kia qua đường liên kết
--      -> bằng chứng rõ nhất là link đang hoạt động THẬT
SELECT  N'KHO_A' AS Site, @@SERVERNAME AS TenMayChu,
        CAST(SERVERPROPERTY('Edition') AS NVARCHAR(60)) AS PhienBan
UNION ALL
SELECT  N'KHO_B', srv.SrvName, srv.Ed
FROM   OPENQUERY([Mignon\KHO_B],
       'SELECT SrvName = @@SERVERNAME, Ed = CAST(SERVERPROPERTY(''Edition'') AS NVARCHAR(60))') srv
UNION ALL
SELECT  N'KHO_C', srv.SrvName, srv.Ed
FROM   OPENQUERY([Mignon\KHO_C],
       'SELECT SrvName = @@SERVERNAME, Ed = CAST(SERVERPROPERTY(''Edition'') AS NVARCHAR(60))') srv;
GO


/* ############################################################################
   PHẦN 8 - SO SÁNH HAI CÁCH VIẾT TRUY VẤN PHÂN TÁN         📷 ẢNH 15
            (mục 3.7c - phần đánh giá hiệu năng)

   Cùng một nhu cầu "đếm tồn kho của KHO_B", có hai cách viết:

   CÁCH 1 - Bốn phần tên (four-part name):
        SELECT ... FROM [Mignon\KHO_B].KhoB.dbo.TonKho GROUP BY ...
        Máy KHO_A phải KÉO TOÀN BỘ các dòng về rồi mới tự gom nhóm.
        Tốn băng thông, nhưng viết dễ đọc.

   CÁCH 2 - OPENQUERY (pass-through):
        SELECT * FROM OPENQUERY([Mignon\KHO_B], 'SELECT ... GROUP BY ...')
        Câu lệnh được GỬI NGUYÊN VĂN sang máy KHO_B, máy đó tự gom nhóm rồi
        chỉ trả về KẾT QUẢ ĐÃ TÓM TẮT. Ít dữ liệu chạy trên đường truyền hơn.

   Trong CSDL phân tán, chi phí lớn nhất là TRUYỀN DỮ LIỆU QUA MẠNG, nên với
   bảng lớn cách 2 luôn thắng. Bảng demo của nhóm chỉ vài dòng nên chênh lệch
   chưa rõ, nhưng nguyên tắc thiết kế thì phải nêu trong báo cáo.
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  PHẦN 8 - LINKED SERVER (4 PHẦN TÊN)  SO VỚI  OPENQUERY          ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

SET STATISTICS IO   ON;
SET STATISTICS TIME ON;
GO

PRINT N'--- CÁCH 1: bốn phần tên - kéo dữ liệu thô về rồi mới gom nhóm ---';
SELECT  N'CÁCH 1 - Linked Server' AS CachViet,
        MaKho, COUNT(*) AS SoDong, SUM(SoLuong) AS TongSoLuong
FROM    [Mignon\KHO_B].KhoB.dbo.TonKho
GROUP BY MaKho;
GO

PRINT N'--- CÁCH 2: OPENQUERY - máy từ xa gom nhóm sẵn, chỉ trả về kết quả ---';
SELECT  N'CÁCH 2 - OPENQUERY' AS CachViet, *
FROM    OPENQUERY([Mignon\KHO_B],
        'SELECT MaKho, SoDong = COUNT(*), TongSoLuong = SUM(SoLuong)
           FROM KhoB.dbo.TonKho GROUP BY MaKho');
GO

SET STATISTICS IO   OFF;
SET STATISTICS TIME OFF;
GO

/*  📷 Chụp tab MESSAGES của phần 8: ở đó SQL Server in ra
       "SQL Server Execution Times: CPU time = ... ms, elapsed time = ... ms"
    cho cả hai cách -> đưa hai con số đó vào bảng so sánh trong báo cáo.
    ------------------------------------------------------------------------ */


/* ############################################################################
   PHẦN 9 - THỦ TỤC TRA CỨU TOÀN HỆ THỐNG   (trong suốt VỊ TRÍ)

   Ba PHẦN trên đều viết cứng tên máy [Mignon\KHO_B], [Mignon\KHO_C] trong câu
   lệnh. Nếu mai mốt công ty mở thêm KHO_D, hoặc dời máy sang địa chỉ khác,
   thì phải sửa lại toàn bộ các câu truy vấn - rất dễ sót.

   Thủ tục dưới đây đọc tên máy chủ từ CỘT ServerName CỦA BẢNG Kho rồi mới
   dựng câu lệnh. Thêm kho mới chỉ cần INSERT thêm một dòng vào bảng Kho,
   không phải sửa một dòng mã nào. Đó là TRONG SUỐT VỊ TRÍ (Location
   Transparency) - lược đồ ánh xạ tầng 3 trong file thiết kế.
   ############################################################################ */
IF OBJECT_ID('dbo.sp_TonKhoToanHeThong', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TonKhoToanHeThong;
GO
CREATE PROCEDURE dbo.sp_TonKhoToanHeThong
    @MaVT CHAR(5) = NULL          -- NULL = xem tất cả vật tư
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX) = N'';
    DECLARE @MaKho CHAR(5), @TenKho NVARCHAR(50), @Server NVARCHAR(128), @DB SYSNAME;

    DECLARE cur CURSOR FOR
        SELECT MaKho, TenKho, ServerName FROM KhoA.dbo.Kho ORDER BY MaKho;
    OPEN cur;
    FETCH NEXT FROM cur INTO @MaKho, @TenKho, @Server;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- CSDL của mỗi site đặt tên theo quy ước KhoA / KhoB / KhoC
        SET @DB = N'Kho' + UPPER(RIGHT(RTRIM(@MaKho), 1));

        IF @SQL <> N'' SET @SQL += N' UNION ALL ';

        /* CHÚ Ý: phải có tiền tố N trước chuỗi tên kho khi dựng câu lệnh động.
           Thiếu chữ N thì SQL Server hiểu 'Kho Miền Bắc' là kiểu VARCHAR, dấu
           tiếng Việt bị rơi mất và kết quả in ra thành 'Kho Mi?n B?c'.
           Lỗi này đã gặp thật lúc chạy thử, ghi lại đây để không tái phạm.   */
        /* So sánh theo MÃ KHO chứ KHÔNG theo tên máy chủ.

           Lý do: cột Kho.ServerName chứa TÊN LINKED SERVER, không nhất thiết
           trùng với @@SERVERNAME của máy đang chạy. Khi hệ thống được đem đặt
           lên ba máy vật lý khác nhau, mỗi máy có tên riêng (LAPTOP-A\KHO_B...)
           trong khi tên Linked Server vẫn giữ nguyên để mọi script chạy được
           mà không phải sửa. Nếu so theo @@SERVERNAME thì site tại chỗ sẽ bị
           hiểu nhầm là site từ xa và câu lệnh sẽ hỏng.                        */
        IF @MaKho = dbo.fn_MaKhoHienTai()   -- site tại chỗ: KHÔNG đi vòng qua mạng
            SET @SQL += N'SELECT N' + QUOTENAME(@TenKho, '''') + N' AS TenKho,
                                 MaKho, MaVT, SoLuong
                          FROM ' + QUOTENAME(@DB) + N'.dbo.TonKho';
        ELSE                            -- site từ xa: đi qua Linked Server
            SET @SQL += N'SELECT N' + QUOTENAME(@TenKho, '''') + N' AS TenKho,
                                 MaKho, MaVT, SoLuong
                          FROM ' + QUOTENAME(@Server) + N'.' + QUOTENAME(@DB)
                       + N'.dbo.TonKho';

        IF @MaVT IS NOT NULL
            SET @SQL += N' WHERE MaVT = ' + QUOTENAME(@MaVT, '''');

        FETCH NEXT FROM cur INTO @MaKho, @TenKho, @Server;
    END
    CLOSE cur; DEALLOCATE cur;

    SET @SQL = N'SELECT * FROM ( ' + @SQL + N' ) AS ToanHeThong ORDER BY MaVT, MaKho;';

    PRINT N'--- Câu lệnh được DỰNG TỰ ĐỘNG từ bảng Kho ---';
    PRINT @SQL;

    EXEC sys.sp_executesql @SQL;
END
GO

-- Thử: chỉ cần gọi tên vật tư, không cần biết nó nằm ở máy nào
EXEC dbo.sp_TonKhoToanHeThong @MaVT = 'VT009';
GO

EXEC dbo.sp_TonKhoToanHeThong;          -- xem toàn bộ
GO


/* ============================================================================
   TỔNG KẾT PHỤC VỤ VIẾT BÁO CÁO

   Mục 3.7b - HIỂN THỊ DỮ LIỆU
     · Tồn kho toàn hệ thống gộp từ 3 máy .................. PHẦN 2
     · Kiểm tra phân mảnh (3 tính chất + dẫn xuất) ......... PHẦN 5
     · Kiểm tra nhân bản / đồng bộ (vân tay + EXCEPT) ...... PHẦN 6
     · Kiểm tra Linked Server (danh sách + test + đọc ngược) PHẦN 7

   Mục 3.7c - THỐNG KÊ
     · Thống kê theo kho, theo vật tư, top 5 chiếm vốn ..... PHẦN 3
     · Thống kê chứng từ 3 site ............................ PHẦN 3.4
     · Cảnh báo thiếu hàng + gợi ý điều chuyển ............. PHẦN 4
     · So sánh hiệu năng 2 cách viết truy vấn phân tán ..... PHẦN 8

   Ý chính cần nhấn mạnh khi thuyết trình
     1. Một câu SELECT chạm tới ba máy chủ khác nhau mà người dùng không hề
        biết -> TRONG SUỐT PHÂN MẢNH.
     2. Thêm kho mới chỉ cần INSERT vào bảng Kho, không sửa mã nguồn
        -> TRONG SUỐT VỊ TRÍ (thủ tục sp_TonKhoToanHeThong, PHẦN 9).
     3. Bảng phân mảnh và bảng nhân bản được kiểm chứng bằng HAI phép khác
        nhau: phân mảnh kiểm "rời nhau", nhân bản kiểm "giống hệt nhau".
   ============================================================================ */
