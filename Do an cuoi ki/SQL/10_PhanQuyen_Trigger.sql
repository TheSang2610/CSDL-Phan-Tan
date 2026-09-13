/* ============================================================================
   ĐỒ ÁN CUỐI KỲ - CSDL PHÂN TÁN - QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
   ----------------------------------------------------------------------------
   FILE 10 : PHÂN QUYỀN VÀ TRIGGER BẢO VỆ CÁC BẢNG

   Đáp ứng:
     · Mục báo cáo 2.2.1.c : Phân quyền cho các nhóm đối tượng
     · Mục báo cáo 3.7d    : "Viết trigger để phân quyền bảo vệ cho các bảng"

   ----------------------------------------------------------------------------
   ⚠️  CHẠY TRÊN CẢ BA SITE - KHÔNG SỬA GÌ

       Mignon\KHO_A   ->  USE KhoA  ->  F5
       Mignon\KHO_B   ->  USE KhoB  ->  F5
       Mignon\KHO_C   ->  USE KhoC  ->  F5

   Script tự nhận biết đang chạy ở kho nào nhờ hàm dbo.fn_MaKhoHienTai() đã
   tạo ở file 04, nên ba site dùng CHUNG một file - đúng tinh thần "mã nguồn
   giống nhau, dữ liệu khác nhau" của CSDL phân tán.

   ----------------------------------------------------------------------------
   VÌ SAO CẦN TRIGGER TRONG KHI ĐÃ CÓ CHECK CONSTRAINT?

   CHECK constraint chỉ nhìn được các cột TRONG CÙNG MỘT DÒNG. Nó làm được:
        CHECK (MaKho = 'KHO_A')
   Nhưng nó KHÔNG làm được những việc cần nhìn sang bảng khác hoặc cần ghi
   nhật ký:

     1. Mảnh DẪN XUẤT ChiTietNhap = ChiTietNhap ⋉ PhieuNhap_A phải kiểm tra
        bằng phép NỐI sang bảng PhieuNhap -> chỉ trigger làm được.
     2. Danh mục VatTu ở KHO_B/KHO_C là BẢN SAO chỉ-đọc; phải chặn người dùng
        sửa tay, nhưng vẫn phải cho Distribution Agent ghi vào -> cần
        trigger có tuỳ chọn NOT FOR REPLICATION.
     3. Ghi NHẬT KÝ KIỂM TOÁN ai đổi tồn kho lúc nào -> chỉ trigger làm được.
     4. Cấm xoá chứng từ đã hoàn tất -> cần INSTEAD OF DELETE.

   Vì vậy hệ thống dùng BA LỚP bảo vệ chồng lên nhau:
        Lớp 1  CHECK constraint  - chặn dữ liệu sai mảnh ngay tại dòng
        Lớp 2  TRIGGER           - chặn cái CHECK không nhìn thấy + ghi nhật ký
        Lớp 3  QUYỀN (GRANT/DENY)- không cho chạm thẳng vào bảng, phải qua
                                   thủ tục đã kiểm soát
   ============================================================================ */

SET NOCOUNT ON;
GO

DECLARE @Kho CHAR(5) = dbo.fn_MaKhoHienTai();
PRINT N'';
PRINT N'════════════════════════════════════════════════════════════════════';
PRINT N'  ĐANG CÀI ĐẶT PHÂN QUYỀN + TRIGGER CHO SITE: ' + @Kho
      + N'   (CSDL ' + DB_NAME() + N')';
PRINT N'════════════════════════════════════════════════════════════════════';
GO


/* ############################################################################
   PHẦN 1 - BẢNG NHẬT KÝ KIỂM TOÁN

   Bảng này KHÔNG được nhân bản và KHÔNG được phân mảnh - mỗi site tự giữ nhật
   ký của mình. Đây là nơi trigger ghi lại mọi thay đổi nhạy cảm.
   ############################################################################ */
IF OBJECT_ID('dbo.NhatKyKiemToan', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.NhatKyKiemToan (
        MaNK       INT IDENTITY(1,1) CONSTRAINT PK_NhatKy PRIMARY KEY,
        ThoiDiem   DATETIME2(0)  NOT NULL CONSTRAINT DF_NK_Ngay DEFAULT SYSDATETIME(),
        Site       CHAR(5)       NOT NULL,
        NguoiDung  NVARCHAR(128) NOT NULL,   -- tài khoản CSDL thực hiện
        MayTram    NVARCHAR(128) NULL,       -- tên máy trạm gửi lệnh
        UngDung    NVARCHAR(128) NULL,       -- SSMS, ứng dụng, agent...
        Bang       SYSNAME       NOT NULL,
        HanhDong   VARCHAR(20)   NOT NULL,
        NoiDung    NVARCHAR(400) NOT NULL
    );
    PRINT N'   ✔ Đã tạo bảng NhatKyKiemToan';
END
ELSE
    PRINT N'   • Bảng NhatKyKiemToan đã có sẵn';
GO


/* ############################################################################
   PHẦN 2 - TRIGGER BẢO VỆ MẢNH NGUYÊN THỦY (bảng TonKho)

   Chặn hai kiểu tấn công mà CHECK constraint không lường hết:
     · INSERT dòng của kho khác vào mảnh này
     · UPDATE đổi MaKho, tức là "đá" một dòng sang mảnh của site khác
   ############################################################################ */
IF OBJECT_ID('dbo.trg_TonKho_BaoVeManh', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_TonKho_BaoVeManh;
GO
CREATE TRIGGER dbo.trg_TonKho_BaoVeManh
ON dbo.TonKho
AFTER INSERT, UPDATE
NOT FOR REPLICATION        -- không cản trở tiến trình nhân bản
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Kho CHAR(5) = dbo.fn_MaKhoHienTai();

    /* 2.1  Không cho dữ liệu của kho khác lọt vào mảnh này */
    IF EXISTS (SELECT 1 FROM inserted WHERE MaKho <> @Kho)
    BEGIN
        DECLARE @Sai CHAR(5) = (SELECT TOP 1 MaKho FROM inserted WHERE MaKho <> @Kho);
        ROLLBACK TRANSACTION;
        RAISERROR (N'VI PHẠM PHÂN MẢNH: site %s chỉ được giữ tồn kho của chính nó, không được ghi dữ liệu của %s. Hãy gửi lệnh tới đúng site hoặc dùng sp_DieuChuyenVatTu.',
                   16, 1, @Kho, @Sai);
        RETURN;
    END

    /* 2.2  Không cho UPDATE đổi MaKho - đó là hành vi "chuyển mảnh" trái phép */
    IF UPDATE(MaKho)
       AND EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.MaVT = i.MaVT
                   WHERE i.MaKho <> d.MaKho)
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR (N'VI PHẠM PHÂN MẢNH: không được sửa cột MaKho để đẩy dòng sang mảnh của site khác. Muốn chuyển hàng phải dùng giao tác phân tán sp_DieuChuyenVatTu.',
                   16, 1);
        RETURN;
    END

    /* 2.3  Ghi nhật ký mọi thay đổi tồn kho */
    INSERT INTO dbo.NhatKyKiemToan (Site, NguoiDung, MayTram, UngDung, Bang, HanhDong, NoiDung)
    SELECT  @Kho, SUSER_SNAME(), HOST_NAME(), APP_NAME(), N'TonKho',
            CASE WHEN d.MaVT IS NULL THEN 'INSERT' ELSE 'UPDATE' END,
            N'Vật tư ' + i.MaVT
            + CASE WHEN d.MaVT IS NULL
                   THEN N': tạo mới với số lượng ' + CAST(i.SoLuong AS NVARCHAR(10))
                   ELSE N': ' + CAST(d.SoLuong AS NVARCHAR(10))
                        + N' -> ' + CAST(i.SoLuong AS NVARCHAR(10))
                        + N'  (chênh lệch ' + CAST(i.SoLuong - d.SoLuong AS NVARCHAR(10)) + N')'
              END
    FROM    inserted i
    LEFT JOIN deleted d ON d.MaKho = i.MaKho AND d.MaVT = i.MaVT
    WHERE   d.MaVT IS NULL OR d.SoLuong <> i.SoLuong;
END
GO
PRINT N'   ✔ trg_TonKho_BaoVeManh';
GO


/* ############################################################################
   PHẦN 3 - TRIGGER BẢO VỆ MẢNH DẪN XUẤT (ChiTietNhap, ChiTietXuat)

   ĐÂY LÀ TRIGGER QUAN TRỌNG NHẤT VỀ MẶT LÝ THUYẾT.

   Định nghĩa mảnh dẫn xuất:
        ChiTietNhap_A = ChiTietNhap ⋉ PhieuNhap_A      (nửa nối theo MaPN)

   Bất biến phải giữ: MỌI dòng chi tiết ở site này đều phải thuộc về một phiếu
   của CHÍNH site này. Muốn kiểm tra điều đó phải NỐI sang bảng PhieuNhap —
   việc mà CHECK constraint hoàn toàn không làm được.
   ############################################################################ */
IF OBJECT_ID('dbo.trg_ChiTietNhap_BaoVeManhDanXuat', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_ChiTietNhap_BaoVeManhDanXuat;
GO
CREATE TRIGGER dbo.trg_ChiTietNhap_BaoVeManhDanXuat
ON dbo.ChiTietNhap
AFTER INSERT, UPDATE
NOT FOR REPLICATION
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Kho CHAR(5) = dbo.fn_MaKhoHienTai();

    IF EXISTS (
        SELECT 1
        FROM   inserted i
        LEFT JOIN dbo.PhieuNhap p ON p.MaPN = i.MaPN
        WHERE  p.MaPN IS NULL OR p.MaKho <> @Kho )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR (N'VI PHẠM MẢNH DẪN XUẤT: dòng chi tiết nhập phải thuộc một phiếu nhập của site %s. Phép nửa nối ChiTietNhap ⋉ PhieuNhap_%s bị phá vỡ.',
                   16, 1, @Kho, @Kho);
        RETURN;
    END
END
GO
PRINT N'   ✔ trg_ChiTietNhap_BaoVeManhDanXuat';
GO

IF OBJECT_ID('dbo.trg_ChiTietXuat_BaoVeManhDanXuat', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_ChiTietXuat_BaoVeManhDanXuat;
GO
CREATE TRIGGER dbo.trg_ChiTietXuat_BaoVeManhDanXuat
ON dbo.ChiTietXuat
AFTER INSERT, UPDATE
NOT FOR REPLICATION
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Kho CHAR(5) = dbo.fn_MaKhoHienTai();

    IF EXISTS (
        SELECT 1
        FROM   inserted i
        LEFT JOIN dbo.PhieuXuat p ON p.MaPX = i.MaPX
        WHERE  p.MaPX IS NULL OR p.MaKho <> @Kho )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR (N'VI PHẠM MẢNH DẪN XUẤT: dòng chi tiết xuất phải thuộc một phiếu xuất của site %s.',
                   16, 1, @Kho);
        RETURN;
    END
END
GO
PRINT N'   ✔ trg_ChiTietXuat_BaoVeManhDanXuat';
GO


/* ############################################################################
   PHẦN 4 - TRIGGER BẢO VỆ BẢNG NHÂN BẢN (VatTu, NhaCungCap, Kho)

   Quy tắc nhân bản một chiều: danh mục CHỈ được sửa ở Kho Trung tâm (Publisher),
   hai kho còn lại giữ bản sao CHỈ ĐỌC.

   Nếu nhân viên KHO_B sửa tay giá vật tư trong bản sao của mình:
     · Thay đổi đó KHÔNG được đẩy ngược về Publisher (đây là replication một chiều)
     · Lần sau Publisher sửa dòng đó, bản sửa tay bị ghi đè mất
     · Hậu quả: ba site báo ba giá khác nhau -> mất tính nhất quán

   Từ khoá NOT FOR REPLICATION khiến trigger BỎ QUA các lệnh do Distribution
   Agent thực hiện, chỉ chặn NGƯỜI DÙNG THẬT. Nhờ vậy nhân bản vẫn chạy bình
   thường mà bản sao vẫn được bảo vệ.
   ############################################################################ */
IF OBJECT_ID('dbo.trg_VatTu_ChiSuaTaiTrungTam', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_VatTu_ChiSuaTaiTrungTam;
GO
CREATE TRIGGER dbo.trg_VatTu_ChiSuaTaiTrungTam
ON dbo.VatTu
AFTER INSERT, UPDATE, DELETE
NOT FOR REPLICATION
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Kho CHAR(5) = dbo.fn_MaKhoHienTai();

    IF @Kho <> 'KHO_A'          -- KHO_B và KHO_C chỉ giữ bản sao
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR (N'BẢNG NHÂN BẢN CHỈ ĐỌC: danh mục VatTu tại %s là BẢN SAO nhận từ Kho Trung tâm. Mọi thay đổi phải thực hiện tại KHO_A rồi để replication tự đẩy về đây (khoảng 15 giây).',
                   16, 1, @Kho);
        RETURN;
    END

    -- Tại Kho Trung tâm: cho sửa, nhưng phải ghi nhật ký vì thay đổi này sẽ
    -- lan ra CẢ BA SITE
    INSERT INTO dbo.NhatKyKiemToan (Site, NguoiDung, MayTram, UngDung, Bang, HanhDong, NoiDung)
    SELECT  @Kho, SUSER_SNAME(), HOST_NAME(), APP_NAME(), N'VatTu',
            CASE WHEN EXISTS (SELECT 1 FROM deleted)
                  AND EXISTS (SELECT 1 FROM inserted) THEN 'UPDATE'
                 WHEN EXISTS (SELECT 1 FROM inserted) THEN 'INSERT'
                 ELSE 'DELETE' END,
            N'Sửa danh mục -> sẽ NHÂN BẢN xuống KHO_B và KHO_C: '
            + ISNULL((SELECT TOP 1 MaVT + N' / ' + TenVT FROM inserted),
                     (SELECT TOP 1 MaVT + N' (đã xoá)'  FROM deleted));
END
GO
PRINT N'   ✔ trg_VatTu_ChiSuaTaiTrungTam';
GO

IF OBJECT_ID('dbo.trg_NhaCungCap_ChiSuaTaiTrungTam', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_NhaCungCap_ChiSuaTaiTrungTam;
GO
CREATE TRIGGER dbo.trg_NhaCungCap_ChiSuaTaiTrungTam
ON dbo.NhaCungCap
AFTER INSERT, UPDATE, DELETE
NOT FOR REPLICATION
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_MaKhoHienTai() <> 'KHO_A'
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR (N'BẢNG NHÂN BẢN CHỈ ĐỌC: danh mục NhaCungCap chỉ được sửa tại Kho Trung tâm KHO_A.',
                   16, 1);
    END
END
GO
PRINT N'   ✔ trg_NhaCungCap_ChiSuaTaiTrungTam';
GO


/* ############################################################################
   PHẦN 5 - TRIGGER CHỐNG XOÁ CHỨNG TỪ ĐÃ HOÀN TẤT

   Chứng từ kho là bằng chứng kế toán. Đã HOAN_TAT thì không ai được xoá,
   kể cả quản trị viên - muốn huỷ phải lập phiếu điều chỉnh ngược lại.

   Dùng INSTEAD OF DELETE: lệnh DELETE bị CHẶN LẠI TRƯỚC KHI chạm vào dữ liệu,
   khác với AFTER là để nó xoá rồi mới rollback.
   ############################################################################ */
IF OBJECT_ID('dbo.trg_PhieuNhap_CamXoa', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_PhieuNhap_CamXoa;
GO
CREATE TRIGGER dbo.trg_PhieuNhap_CamXoa
ON dbo.PhieuNhap
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted WHERE TrangThai = 'HOAN_TAT')
    BEGIN
        DECLARE @Ma CHAR(7) = (SELECT TOP 1 MaPN FROM deleted WHERE TrangThai = 'HOAN_TAT');

        /* LƯU Ý KỸ THUẬT QUAN TRỌNG - đã kiểm chứng bằng thực nghiệm:
           KHÔNG ghi nhật ký ở đây được. Khi trigger phát RAISERROR, toàn bộ
           việc trigger vừa làm - kể cả dòng nhật ký - đều bị cuốn theo lệnh
           ROLLBACK, chỉ có số IDENTITY là bị tiêu tốn. Thử lần đầu bảng nhật
           ký nhảy từ MaNK = 1 sang 2 mà không có dòng nào, chính là vì vậy.

           Cách đúng: ghi nhật ký ở phía GỌI, trong khối BEGIN CATCH - lúc đó
           giao tác đã kết thúc nên dòng nhật ký mới nằm lại được.
           Xem PHẦN 10 bên dưới để thấy cách làm.                              */
        RAISERROR (N'CẤM XOÁ CHỨNG TỪ: phiếu nhập %s đã ở trạng thái HOAN_TAT. Chứng từ kho là bằng chứng kế toán, muốn huỷ phải lập phiếu điều chỉnh.',
                   16, 1, @Ma);
        RETURN;
    END

    -- Phiếu chưa hoàn tất thì cho xoá bình thường, xoá chi tiết trước
    DELETE FROM dbo.ChiTietNhap WHERE MaPN IN (SELECT MaPN FROM deleted);
    DELETE FROM dbo.PhieuNhap   WHERE MaPN IN (SELECT MaPN FROM deleted);
END
GO
PRINT N'   ✔ trg_PhieuNhap_CamXoa';
GO


/* ############################################################################
   PHẦN 6 - TẠO CÁC VAI TRÒ VÀ PHÂN QUYỀN
            (đúng bảng 3.3 trong tài liệu thiết kế)

   ┌──────────────────┬─────────────────────────────────────────────────────┐
   │ Vai trò          │ Quyền                                               │
   ├──────────────────┼─────────────────────────────────────────────────────┤
   │ NhanVienKho      │ Đọc mọi bảng của kho mình; nhập/xuất QUA THỦ TỤC    │
   │ TruongKho        │ NhanVienKho + được điều chuyển sang kho khác         │
   │ QuanTriDanhMuc   │ Toàn quyền danh mục - CHỈ có ở Kho Trung tâm         │
   │ BanGiamDoc       │ Đọc toàn hệ thống qua Linked Server - chỉ ở KHO_A    │
   └──────────────────┴─────────────────────────────────────────────────────┘

   NGUYÊN TẮC THIẾT KẾ QUAN TRỌNG:
     Nhân viên KHÔNG được cấp quyền ghi thẳng vào bảng TonKho. Họ chỉ có
     quyền EXECUTE thủ tục. Nhờ cơ chế CHUỖI SỞ HỮU (ownership chaining) -
     thủ tục và bảng cùng thuộc lược đồ dbo - thủ tục vẫn ghi được vào bảng
     dù người gọi bị DENY. Kết quả: mọi thay đổi tồn kho BẮT BUỘC đi qua
     đoạn mã đã kiểm tra tồn, đã đặt khóa, đã ghi chứng từ.
   ############################################################################ */

DECLARE @Kho CHAR(5) = dbo.fn_MaKhoHienTai();

/* 6.1  Tạo vai trò */
IF DATABASE_PRINCIPAL_ID('NhanVienKho')    IS NULL CREATE ROLE NhanVienKho;
IF DATABASE_PRINCIPAL_ID('TruongKho')      IS NULL CREATE ROLE TruongKho;
IF DATABASE_PRINCIPAL_ID('BanGiamDoc')     IS NULL CREATE ROLE BanGiamDoc;
IF @Kho = 'KHO_A' AND DATABASE_PRINCIPAL_ID('QuanTriDanhMuc') IS NULL
    EXEC ('CREATE ROLE QuanTriDanhMuc');

PRINT N'   ✔ Đã tạo các vai trò';
GO

/* 6.2  NhanVienKho - đọc mọi thứ của kho mình, KHÔNG ghi thẳng vào bảng */
GRANT SELECT ON dbo.TonKho            TO NhanVienKho;
GRANT SELECT ON dbo.VatTu             TO NhanVienKho;
GRANT SELECT ON dbo.NhaCungCap        TO NhanVienKho;
GRANT SELECT ON dbo.Kho               TO NhanVienKho;
GRANT SELECT ON dbo.PhieuNhap         TO NhanVienKho;
GRANT SELECT ON dbo.ChiTietNhap       TO NhanVienKho;
GRANT SELECT ON dbo.PhieuXuat         TO NhanVienKho;
GRANT SELECT ON dbo.ChiTietXuat       TO NhanVienKho;
GRANT SELECT ON dbo.PhieuDieuChuyen   TO NhanVienKho;

-- CẤM tuyệt đối việc ghi thẳng - bắt buộc phải đi qua thủ tục
DENY  INSERT, UPDATE, DELETE ON dbo.TonKho      TO NhanVienKho;
DENY  INSERT, UPDATE, DELETE ON dbo.PhieuNhap   TO NhanVienKho;
DENY  INSERT, UPDATE, DELETE ON dbo.PhieuXuat   TO NhanVienKho;

-- Nhưng ĐƯỢC chạy thủ tục nghiệp vụ (thủ tục sẽ tự ghi vào bảng)
GRANT EXECUTE ON dbo.sp_NhapKho            TO NhanVienKho;
GRANT EXECUTE ON dbo.sp_XuatKho            TO NhanVienKho;
GRANT EXECUTE ON dbo.sp_TraCuuTonKho       TO NhanVienKho;
GRANT EXECUTE ON dbo.sp_CanhBaoTonToiThieu TO NhanVienKho;
GRANT EXECUTE ON TYPE::dbo.ChiTietVatTu_Type TO NhanVienKho;

-- Danh mục là bản sao / nguồn nhân bản: nhân viên kho tuyệt đối không đụng
DENY  INSERT, UPDATE, DELETE ON dbo.VatTu      TO NhanVienKho;
DENY  INSERT, UPDATE, DELETE ON dbo.NhaCungCap TO NhanVienKho;

PRINT N'   ✔ Đã cấp quyền cho NhanVienKho';
GO

/* 6.3  TruongKho - kế thừa nhân viên, thêm quyền điều chuyển liên kho */
EXEC sp_addrolemember N'NhanVienKho', N'TruongKho';
GRANT SELECT ON dbo.NhatKyKiemToan TO TruongKho;

/* Thủ tục điều chuyển phải được triển khai ở cả ba site thì kho nào cũng chủ
   động gửi hàng đi được (xem ghi chú ở đầu file 07). Nếu site này chưa có thì
   bỏ qua bước cấp quyền thay vì để script đứt giữa chừng.                    */
IF OBJECT_ID('dbo.sp_DieuChuyenVatTu', 'P') IS NOT NULL
    EXEC ('GRANT EXECUTE ON dbo.sp_DieuChuyenVatTu TO TruongKho');
ELSE
    PRINT N'   ⚠ Site này chưa có sp_DieuChuyenVatTu - hãy chạy PHẦN 2 của file 07 tại đây trước';
PRINT N'   ✔ Đã cấp quyền cho TruongKho';
GO

/* 6.4  BanGiamDoc - chỉ đọc, nhưng đọc được toàn hệ thống */
GRANT SELECT ON dbo.TonKho          TO BanGiamDoc;
GRANT SELECT ON dbo.VatTu           TO BanGiamDoc;
GRANT SELECT ON dbo.Kho             TO BanGiamDoc;
GRANT SELECT ON dbo.PhieuDieuChuyen TO BanGiamDoc;
GRANT SELECT ON dbo.NhatKyKiemToan  TO BanGiamDoc;
DENY  INSERT, UPDATE, DELETE ON dbo.TonKho TO BanGiamDoc;
PRINT N'   ✔ Đã cấp quyền cho BanGiamDoc';
GO

/* 6.5  QuanTriDanhMuc - CHỈ TỒN TẠI Ở KHO TRUNG TÂM
        Đây là cách phân quyền THỂ HIỆN ĐÚNG kiến trúc phân tán: quyền sửa
        danh mục chỉ được cấp ở nơi làm Publisher, hai site kia không có
        vai trò này nên không ai sửa được bản sao.                          */
IF dbo.fn_MaKhoHienTai() = 'KHO_A'
BEGIN
    EXEC ('GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.VatTu      TO QuanTriDanhMuc');
    EXEC ('GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.NhaCungCap TO QuanTriDanhMuc');
    EXEC ('GRANT SELECT ON dbo.Kho TO QuanTriDanhMuc');
    PRINT N'   ✔ Đã cấp quyền cho QuanTriDanhMuc (chỉ có tại Kho Trung tâm)';
END
ELSE
    PRINT N'   • Site này KHÔNG có vai trò QuanTriDanhMuc - đúng thiết kế';
GO


/* ############################################################################
   PHẦN 7 - TẠO NGƯỜI DÙNG MẪU ĐỂ THỬ QUYỀN

   Tạo user không gắn login (WITHOUT LOGIN) - đủ để dùng EXECUTE AS thử
   nghiệm mà không phải tạo tài khoản đăng nhập thật trên máy chủ.
   ############################################################################ */
IF DATABASE_PRINCIPAL_ID('nv_kho')   IS NULL CREATE USER nv_kho   WITHOUT LOGIN;
IF DATABASE_PRINCIPAL_ID('truong_kho') IS NULL CREATE USER truong_kho WITHOUT LOGIN;
IF DATABASE_PRINCIPAL_ID('giam_doc') IS NULL CREATE USER giam_doc WITHOUT LOGIN;
GO

ALTER ROLE NhanVienKho ADD MEMBER nv_kho;
ALTER ROLE TruongKho   ADD MEMBER truong_kho;
ALTER ROLE BanGiamDoc  ADD MEMBER giam_doc;

IF dbo.fn_MaKhoHienTai() = 'KHO_A'
BEGIN
    IF DATABASE_PRINCIPAL_ID('qt_danhmuc') IS NULL
        EXEC ('CREATE USER qt_danhmuc WITHOUT LOGIN');
    EXEC ('ALTER ROLE QuanTriDanhMuc ADD MEMBER qt_danhmuc');
END
GO
PRINT N'   ✔ Đã tạo người dùng mẫu và gán vào vai trò';
GO


/* ############################################################################
   ⚠️ ĐỌC TRƯỚC KHI CHỤP ẢNH TỪNG PHẦN

   Bốn PHẦN 8, 9, 10, 11 dưới đây được thiết kế để BÔI ĐEN riêng từng phần rồi
   bấm F5, mỗi phần ra một ảnh sạch.

   NHƯNG: khi bôi đen riêng thì dòng USE ở đầu file KHÔNG chạy theo. Nếu ô
   database trên thanh công cụ SSMS đang là "master" thì sẽ gặp lỗi:

        Msg 4121 - Cannot find either column "dbo" or the user-defined
                   function or aggregate "dbo.fn_MaKhoHienTai"

   CÁCH SỬA: nhìn lên thanh công cụ SSMS, có một ô dropdown ghi tên database.
   Bấm vào đó chọn đúng KhoA / KhoB / KhoC theo site đang nối, rồi mới F5.

   Dòng kiểm tra ngay dưới đây sẽ báo cho bạn biết nếu chọn sai.
   ############################################################################ */
/* RAISERROR chỉ nhận biến hoặc hằng làm tham số thay thế, không nhận lời gọi hàm. */
DECLARE @db SYSNAME = DB_NAME();
IF @db NOT IN ('KhoA','KhoB','KhoC')
BEGIN
    RAISERROR (N'>>> ĐANG Ở SAI DATABASE (%s). Hãy chọn KhoA / KhoB / KhoC ở ô dropdown trên thanh công cụ SSMS rồi chạy lại. <<<',
               16, 1, @db);
END
ELSE
    PRINT N'✔ Database hiện tại: ' + @db + N'  -> chạy tiếp được';
GO


/* ############################################################################
   PHẦN 8 - BẢNG TỔNG HỢP QUYỀN ĐÃ CẤP               📷 ẢNH 16
            (chụp ảnh này cho mục 2.2.1.c và 3.7d)
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  PHẦN 8 - BẢNG QUYỀN ĐÃ CẤP TẠI SITE NÀY                         ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

SELECT  dp.name                                  AS VaiTro,
        ISNULL(o.name, ty.name)                  AS DoiTuong,
        CASE WHEN ty.name IS NOT NULL THEN N'Kiểu bảng (TVP)'
             WHEN o.type = 'U'  THEN N'Bảng'
             WHEN o.type = 'P'  THEN N'Thủ tục'
             WHEN o.type = 'V'  THEN N'Khung nhìn'
             ELSE o.type END                     AS Loai,
        p.permission_name                        AS Quyen,
        CASE p.state WHEN 'G' THEN N'✔ CHO PHÉP'
                     WHEN 'D' THEN N'✘ CẤM (DENY)'
                     WHEN 'W' THEN N'✔ CHO PHÉP + uỷ quyền lại' END AS TrangThai
FROM    sys.database_permissions p
JOIN    sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
LEFT JOIN sys.objects o  ON o.object_id  = p.major_id AND p.class = 1
LEFT JOIN sys.types  ty  ON ty.user_type_id = p.major_id AND p.class = 6
WHERE   dp.name IN ('NhanVienKho','TruongKho','BanGiamDoc','QuanTriDanhMuc')
ORDER BY dp.name, p.state DESC, ISNULL(o.name, ty.name);
GO

-- Ai đang thuộc vai trò nào
SELECT  r.name AS VaiTro,
        m.name AS ThanhVien,
        CASE m.type WHEN 'R' THEN N'Là VAI TRÒ con - kế thừa toàn bộ quyền của vai trò cha'
                    ELSE N'Là người dùng' END AS Loai
FROM    sys.database_role_members rm
JOIN    sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN    sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE   r.name IN ('NhanVienKho','TruongKho','BanGiamDoc','QuanTriDanhMuc')
ORDER BY r.name;
GO

-- Danh sách trigger bảo vệ đang hoạt động tại site này
SELECT  t.name                          AS TenTrigger,
        OBJECT_NAME(t.parent_id)        AS BangDuocBaoVe,
        CASE WHEN t.is_instead_of_trigger = 1 THEN N'INSTEAD OF' ELSE N'AFTER' END AS Kieu,
        CASE WHEN t.is_disabled = 1 THEN N'✘ Đang tắt' ELSE N'✔ Đang bật' END AS TrangThai,
        CASE WHEN t.is_not_for_replication = 1
             THEN N'Bỏ qua lệnh của replication' ELSE N'Áp dụng cho mọi lệnh' END AS PhamVi
FROM    sys.triggers t
WHERE   t.parent_class = 1
ORDER BY OBJECT_NAME(t.parent_id), t.name;
GO


/* ############################################################################
   PHẦN 9 - THỬ QUYỀN THẬT                            📷 ẢNH 17

   Dùng EXECUTE AS để "hoá thân" thành từng vai trò rồi thử làm việc bị cấm.
   Mỗi tình huống đều được bắt lỗi nên script chạy trọn vẹn, không đứt giữa chừng.
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  PHẦN 9 - THỬ QUYỀN: AI LÀM ĐƯỢC GÌ, AI BỊ CHẶN                  ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

DECLARE @KetQua TABLE (
    STT INT IDENTITY(1,1), VaiTro NVARCHAR(30), HanhDong NVARCHAR(80),
    KetQua NVARCHAR(20), ChiTiet NVARCHAR(250));

/* 9.1  Nhân viên kho ĐỌC tồn kho -> phải ĐƯỢC */
BEGIN TRY
    EXECUTE AS USER = 'nv_kho';
    DECLARE @n INT = (SELECT COUNT(*) FROM dbo.TonKho);
    REVERT;
    INSERT INTO @KetQua VALUES (N'nv_kho', N'SELECT trên TonKho', N'✔ ĐƯỢC PHÉP',
        N'Đọc được ' + CAST(@n AS NVARCHAR(10)) + N' dòng tồn kho của kho mình');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO @KetQua VALUES (N'nv_kho', N'SELECT trên TonKho', N'✘ BỊ CHẶN', LEFT(ERROR_MESSAGE(),200));
END CATCH

/* 9.2  Nhân viên kho GHI THẲNG vào TonKho -> phải BỊ CHẶN */
BEGIN TRY
    EXECUTE AS USER = 'nv_kho';
    UPDATE dbo.TonKho SET SoLuong = SoLuong + 999 WHERE MaVT = 'VT001';
    REVERT;
    INSERT INTO @KetQua VALUES (N'nv_kho', N'UPDATE thẳng vào TonKho', N'✘ NGUY HIỂM',
        N'Sửa được tồn kho mà không qua thủ tục!');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO @KetQua VALUES (N'nv_kho', N'UPDATE thẳng vào TonKho', N'✔ BỊ CHẶN ĐÚNG',
        N'DENY có hiệu lực - buộc phải dùng sp_XuatKho / sp_NhapKho');
END CATCH

/* 9.3  Nhân viên kho SỬA DANH MỤC -> phải BỊ CHẶN */
BEGIN TRY
    EXECUTE AS USER = 'nv_kho';
    UPDATE dbo.VatTu SET DonGia = 1 WHERE MaVT = 'VT001';
    REVERT;
    INSERT INTO @KetQua VALUES (N'nv_kho', N'UPDATE danh mục VatTu', N'✘ NGUY HIỂM',
        N'Sửa được danh mục nhân bản!');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO @KetQua VALUES (N'nv_kho', N'UPDATE danh mục VatTu', N'✔ BỊ CHẶN ĐÚNG',
        N'Danh mục là nguồn/bản sao nhân bản, nhân viên kho không được đụng');
END CATCH

/* 9.4  Ban giám đốc GHI vào TonKho -> phải BỊ CHẶN (chỉ được đọc) */
BEGIN TRY
    EXECUTE AS USER = 'giam_doc';
    DELETE FROM dbo.TonKho WHERE MaVT = 'VT001';
    REVERT;
    INSERT INTO @KetQua VALUES (N'giam_doc', N'DELETE trên TonKho', N'✘ NGUY HIỂM',
        N'Vai trò chỉ-đọc lại xoá được dữ liệu!');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO @KetQua VALUES (N'giam_doc', N'DELETE trên TonKho', N'✔ BỊ CHẶN ĐÚNG',
        N'BanGiamDoc là vai trò CHỈ ĐỌC toàn hệ thống');
END CATCH

/* 9.5  Nhân viên kho gọi thủ tục điều chuyển -> phải BỊ CHẶN (chỉ trưởng kho) */
BEGIN TRY
    EXECUTE AS USER = 'nv_kho';
    DECLARE @perm INT = (SELECT HAS_PERMS_BY_NAME('dbo.sp_DieuChuyenVatTu','OBJECT','EXECUTE'));
    REVERT;
    INSERT INTO @KetQua VALUES (N'nv_kho', N'EXECUTE sp_DieuChuyenVatTu',
        CASE WHEN @perm = 1 THEN N'✘ NGUY HIỂM' ELSE N'✔ BỊ CHẶN ĐÚNG' END,
        N'Chỉ TruongKho mới được điều chuyển hàng sang kho khác');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO @KetQua VALUES (N'nv_kho', N'EXECUTE sp_DieuChuyenVatTu', N'✔ BỊ CHẶN ĐÚNG', LEFT(ERROR_MESSAGE(),200));
END CATCH

/* 9.6  Trưởng kho gọi thủ tục điều chuyển -> phải ĐƯỢC */
BEGIN TRY
    EXECUTE AS USER = 'truong_kho';
    DECLARE @perm2 INT = (SELECT HAS_PERMS_BY_NAME('dbo.sp_DieuChuyenVatTu','OBJECT','EXECUTE'));
    REVERT;
    INSERT INTO @KetQua VALUES (N'truong_kho', N'EXECUTE sp_DieuChuyenVatTu',
        CASE WHEN @perm2 = 1 THEN N'✔ ĐƯỢC PHÉP' ELSE N'✘ SAI - đáng lẽ được' END,
        N'Trưởng kho có quyền khởi tạo giao tác phân tán');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO @KetQua VALUES (N'truong_kho', N'EXECUTE sp_DieuChuyenVatTu', N'✘ LỖI', LEFT(ERROR_MESSAGE(),200));
END CATCH

SELECT * FROM @KetQua;
GO


/* ############################################################################
   PHẦN 10 - THỬ TRIGGER BẢO VỆ                        📷 ẢNH 18

   Bốn phép thử, cả bốn đều PHẢI bị chặn. Chạy với quyền cao nhất (sa/dbo)
   để chứng minh: trigger chặn KỂ CẢ QUẢN TRỊ VIÊN, không chỉ chặn nhân viên.
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  PHẦN 10 - THỬ TRIGGER: CHẶN CẢ QUẢN TRỊ VIÊN                    ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

/* Cột "LỚP CHẶN" được suy ra từ SỐ HIỆU LỖI, cho thấy chính xác hàng phòng thủ
   nào đã bắt được hành vi sai:
        547            -> Lớp 1: CHECK constraint hoặc khoá ngoại
        50000          -> Lớp 2: TRIGGER (lệnh RAISERROR do ta tự viết)
        229 / 230      -> Lớp 3: hệ thống quyền GRANT/DENY
   Đây chính là bằng chứng cho mô hình BA LỚP BẢO VỆ nêu ở đầu file.          */
DECLARE @T TABLE (STT INT IDENTITY(1,1), PhepThu NVARCHAR(60),
                  KetQua NVARCHAR(16), SoHieuLoi INT, LopChan NVARCHAR(40),
                  ThongBao NVARCHAR(250));
DECLARE @KhoNay CHAR(5) = dbo.fn_MaKhoHienTai();
DECLARE @KhoKhac CHAR(5) = CASE WHEN @KhoNay = 'KHO_A' THEN 'KHO_B' ELSE 'KHO_A' END;

DECLARE @Lop NVARCHAR(40);

/* 10.1  Ghi dòng của kho khác vào mảnh này */
BEGIN TRY
    INSERT INTO dbo.TonKho (MaKho, MaVT, SoLuong) VALUES (@KhoKhac, 'VT001', 1);
    DELETE FROM dbo.TonKho WHERE MaKho = @KhoKhac;
    INSERT INTO @T VALUES (N'Ghi tồn kho của site khác', N'✘ LỌT', 0, N'—', N'Dữ liệu sai mảnh đã ghi được!');
END TRY
BEGIN CATCH
    SET @Lop = CASE ERROR_NUMBER() WHEN 547 THEN N'Lớp 1 - CHECK constraint'
                                   WHEN 50000 THEN N'Lớp 2 - TRIGGER' ELSE N'Khác' END;
    INSERT INTO @T VALUES (N'Ghi tồn kho của site khác', N'✔ BỊ CHẶN', ERROR_NUMBER(), @Lop, LEFT(ERROR_MESSAGE(), 250));
END CATCH

/* 10.2  Đổi MaKho để đẩy một dòng sang mảnh của site khác */
BEGIN TRY
    UPDATE dbo.TonKho SET MaKho = @KhoKhac WHERE MaVT = 'VT001';
    INSERT INTO @T VALUES (N'Đổi MaKho để chuyển mảnh', N'✘ LỌT', 0, N'—', N'Đã đá được dòng sang mảnh khác!');
END TRY
BEGIN CATCH
    SET @Lop = CASE ERROR_NUMBER() WHEN 547 THEN N'Lớp 1 - CHECK constraint'
                                   WHEN 50000 THEN N'Lớp 2 - TRIGGER' ELSE N'Khác' END;
    INSERT INTO @T VALUES (N'Đổi MaKho để chuyển mảnh', N'✔ BỊ CHẶN', ERROR_NUMBER(), @Lop, LEFT(ERROR_MESSAGE(), 250));
END CATCH

/* 10.3  Ghi chi tiết nhập không thuộc phiếu nào của site này (phá mảnh dẫn xuất) */
BEGIN TRY
    INSERT INTO dbo.ChiTietNhap (MaPN, MaVT, SoLuong, DonGia)
    VALUES ('PNZ9999', 'VT001', 1, 1000);
    INSERT INTO @T VALUES (N'Chi tiết nhập mồ côi (mảnh dẫn xuất)', N'✘ LỌT', 0, N'—', N'Đã ghi được dòng mồ côi!');
END TRY
BEGIN CATCH
    SET @Lop = CASE ERROR_NUMBER() WHEN 547 THEN N'Lớp 1 - khoá ngoại'
                                   WHEN 50000 THEN N'Lớp 2 - TRIGGER' ELSE N'Khác' END;
    INSERT INTO @T VALUES (N'Chi tiết nhập mồ côi (mảnh dẫn xuất)', N'✔ BỊ CHẶN', ERROR_NUMBER(), @Lop, LEFT(ERROR_MESSAGE(), 250));
END CATCH

/* 10.4  Xoá phiếu nhập đã hoàn tất
         KHÔNG có ràng buộc nào diễn tả được luật này -> CHỈ TRIGGER làm được */
BEGIN TRY
    DECLARE @PN CHAR(7) = (SELECT TOP 1 MaPN FROM dbo.PhieuNhap WHERE TrangThai = 'HOAN_TAT');
    IF @PN IS NULL
        INSERT INTO @T VALUES (N'Xoá chứng từ đã hoàn tất', N'— bỏ qua', 0, N'—', N'Site này chưa có phiếu nhập nào');
    ELSE
    BEGIN
        DELETE FROM dbo.PhieuNhap WHERE MaPN = @PN;
        INSERT INTO @T VALUES (N'Xoá chứng từ đã hoàn tất', N'✘ LỌT', 0, N'—', N'Đã xoá được chứng từ kế toán!');
    END
END TRY
BEGIN CATCH
    SET @Lop = CASE ERROR_NUMBER() WHEN 547 THEN N'Lớp 1 - khoá ngoại'
                                   WHEN 50000 THEN N'Lớp 2 - TRIGGER (chỉ trigger làm được)' ELSE N'Khác' END;
    INSERT INTO @T VALUES (N'Xoá chứng từ đã hoàn tất', N'✔ BỊ CHẶN', ERROR_NUMBER(), @Lop, LEFT(ERROR_MESSAGE(), 250));

    /* GHI NHẬT KÝ Ở ĐÂY - phía gọi, sau khi giao tác đã kết thúc.
       Đây là chỗ duy nhất dòng nhật ký về một hành vi BỊ TỪ CHỐI sống sót
       được, vì ROLLBACK của trigger không còn với tới nữa.                  */
    INSERT INTO dbo.NhatKyKiemToan (Site, NguoiDung, MayTram, UngDung, Bang, HanhDong, NoiDung)
    VALUES (@KhoNay, SUSER_SNAME(), HOST_NAME(), APP_NAME(), N'PhieuNhap', 'DELETE-BLOCKED',
            N'Có người cố xoá phiếu nhập đã hoàn tất ' + ISNULL(@PN, N'?') + N' -> TRIGGER ĐÃ CHẶN');
END CATCH

/* 10.5  Sửa danh mục nhân bản
         Cũng KHÔNG ràng buộc nào diễn tả được "bản sao thì chỉ đọc"
         -> CHỈ TRIGGER làm được, và phải là trigger NOT FOR REPLICATION */
BEGIN TRY
    UPDATE dbo.VatTu SET MucTonToiThieu = MucTonToiThieu WHERE MaVT = 'VT001';
    INSERT INTO @T VALUES (N'Sửa danh mục VatTu tại site này',
        CASE WHEN @KhoNay = 'KHO_A' THEN N'✔ ĐƯỢC PHÉP' ELSE N'✘ LỌT' END, 0,
        CASE WHEN @KhoNay = 'KHO_A' THEN N'Publisher - đúng thiết kế' ELSE N'—' END,
        CASE WHEN @KhoNay = 'KHO_A'
             THEN N'Đây là Publisher, được sửa và sẽ nhân bản xuống 2 site kia'
             ELSE N'Bản sao lại sửa được - SAI!' END);
END TRY
BEGIN CATCH
    SET @Lop = CASE ERROR_NUMBER() WHEN 50000 THEN N'Lớp 2 - TRIGGER (chỉ trigger làm được)' ELSE N'Khác' END;
    INSERT INTO @T VALUES (N'Sửa danh mục VatTu tại site này', N'✔ BỊ CHẶN', ERROR_NUMBER(), @Lop, LEFT(ERROR_MESSAGE(), 250));
END CATCH

SELECT * FROM @T;
GO

/*  ĐỌC BẢNG KẾT QUẢ TRÊN NHƯ THẾ NÀO (viết vào báo cáo)

    Phép thử 1, 2, 3 bị chặn bởi LỚP 1 (lỗi 547) - ràng buộc CHECK và khoá
    ngoại bắt được trước khi trigger kịp chạy. Điều đó KHÔNG có nghĩa trigger
    thừa: nó là hàng phòng thủ thứ hai, và nó là thứ duy nhất ghi được nhật ký.

    Phép thử 4 và 5 bị chặn bởi LỚP 2 (lỗi 50000) - đây là hai luật mà KHÔNG
    một ràng buộc nào của SQL diễn tả nổi:
        · "không được xoá chứng từ đã hoàn tất"       -> cần INSTEAD OF DELETE
        · "bản sao nhân bản thì chỉ được đọc"          -> cần NOT FOR REPLICATION
    Hai dòng này chính là câu trả lời cho yêu cầu 3.7 của đề cương:
    "viết trigger để phân quyền bảo vệ cho các bảng".                          */


/* ############################################################################
   PHẦN 11 - XEM NHẬT KÝ KIỂM TOÁN DO TRIGGER GHI LẠI     📷 ẢNH 19
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  PHẦN 11 - NHẬT KÝ KIỂM TOÁN                                     ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

SELECT TOP 20
       MaNK, ThoiDiem, Site, NguoiDung, MayTram, Bang, HanhDong, NoiDung
FROM   dbo.NhatKyKiemToan
ORDER BY MaNK DESC;

SELECT Bang, HanhDong, COUNT(*) AS SoLan,
       MIN(ThoiDiem) AS LanDauTien, MAX(ThoiDiem) AS LanGanNhat
FROM   dbo.NhatKyKiemToan
GROUP BY Bang, HanhDong
ORDER BY SoLan DESC;
GO


/* ============================================================================
   TỔNG KẾT ĐƯA VÀO BÁO CÁO - MỤC 3.7d

   BA LỚP BẢO VỆ CHỒNG NHAU

     Lớp 1 - RÀNG BUỘC (CHECK)
         CK_TonKho_Manh, CK_PN_Manh, CK_PX_Manh, CK_PN_MaSo, CK_PX_MaSo
         Chặn ngay tại dòng dữ liệu, nhanh nhất, không thể vô hiệu hoá.

     Lớp 2 - TRIGGER   (6 trigger)
         trg_TonKho_BaoVeManh ................ chặn ghi sai mảnh + cấm đổi MaKho
         trg_ChiTietNhap_BaoVeManhDanXuat .... giữ bất biến nửa nối ⋉
         trg_ChiTietXuat_BaoVeManhDanXuat .... giữ bất biến nửa nối ⋉
         trg_VatTu_ChiSuaTaiTrungTam ......... bản sao chỉ-đọc, NOT FOR REPLICATION
         trg_NhaCungCap_ChiSuaTaiTrungTam .... bản sao chỉ-đọc
         trg_PhieuNhap_CamXoa ................ INSTEAD OF, giữ chứng từ kế toán
         Đồng thời ghi NhatKyKiemToan - biết ai sửa gì, lúc nào, từ máy nào.

     Lớp 3 - QUYỀN     (4 vai trò)
         NhanVienKho / TruongKho / BanGiamDoc / QuanTriDanhMuc
         Điểm mấu chốt: DENY ghi thẳng vào bảng + GRANT EXECUTE thủ tục.
         Nhờ chuỗi sở hữu, thủ tục vẫn ghi được, nên MỌI thay đổi tồn kho
         bắt buộc đi qua đoạn mã đã kiểm tra tồn và đã đặt khóa.

   ĐIỂM GẮN VỚI KIẾN TRÚC PHÂN TÁN - nên nhấn mạnh khi thuyết trình
     · Vai trò QuanTriDanhMuc CHỈ tồn tại ở KHO_A. Quyền sửa danh mục được
       đặt đúng nơi làm Publisher -> phân quyền phản ánh đúng sơ đồ nhân bản.
     · Trigger dùng NOT FOR REPLICATION để phân biệt "người dùng sửa" và
       "replication đẩy dữ liệu về" - hai việc giống nhau về mặt câu lệnh
       nhưng khác hẳn nhau về mặt hợp lệ.
     · Trigger mảnh dẫn xuất là thứ CHECK constraint không thể thay thế,
       vì nó phải nối sang bảng cha mới biết dòng có đúng mảnh hay không.
   ============================================================================ */
