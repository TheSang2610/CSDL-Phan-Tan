/* ============================================================================
   ĐỒ ÁN CUỐI KỲ - CSDL PHÂN TÁN - QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
   ----------------------------------------------------------------------------
   SITE  S3 : Kho Miền Nam
   INSTANCE : MIGNON\KHO_C
   DATABASE : KhoC
   MẢNH     : TonKho_C, PhieuNhap_C, ChiTietNhap_C,
              PhieuXuat_C, ChiTietXuat_C

   CHẠY TẠI : CHỈ chạy file này trên instance MIGNON\KHO_C
   ============================================================================ */

USE master;
GO

IF DB_ID('KhoC') IS NOT NULL
BEGIN
    ALTER DATABASE [KhoC] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [KhoC];
END
GO

CREATE DATABASE [KhoC];
GO

USE [KhoC];
GO

/* ----------------------------------------------------------------------------
   PHẦN 1. NHÓM BẢNG DANH MỤC  -  sẽ được NHÂN BẢN (replication) từ KHO_A
   ---------------------------------------------------------------------------- */

CREATE TABLE NhaCungCap (
    MaNCC     CHAR(5)        NOT NULL CONSTRAINT PK_NhaCungCap PRIMARY KEY,
    TenNCC    NVARCHAR(100)  NOT NULL,
    DiaChi    NVARCHAR(150)  NULL,
    DienThoai VARCHAR(20)    NULL,
    Email     VARCHAR(80)    NULL
);
GO

CREATE TABLE VatTu (
    MaVT           CHAR(5)       NOT NULL CONSTRAINT PK_VatTu PRIMARY KEY,
    TenVT          NVARCHAR(100) NOT NULL,
    DonViTinh      NVARCHAR(20)  NOT NULL,
    DonGia         DECIMAL(14,0) NOT NULL CONSTRAINT CK_VatTu_DonGia CHECK (DonGia >= 0),
    MaNCC          CHAR(5)       NOT NULL,
    MucTonToiThieu INT           NOT NULL DEFAULT 0,
    CONSTRAINT FK_VatTu_NCC FOREIGN KEY (MaNCC) REFERENCES NhaCungCap(MaNCC)
);
GO

CREATE TABLE Kho (
    MaKho      CHAR(5)       NOT NULL CONSTRAINT PK_Kho PRIMARY KEY,
    TenKho     NVARCHAR(50)  NOT NULL,
    DiaChi     NVARCHAR(150) NULL,
    ServerName NVARCHAR(128) NOT NULL   -- tên instance, dùng dựng Linked Server
);
GO

/* ----------------------------------------------------------------------------
   PHẦN 2. MẢNH NGANG NGUYÊN THỦY  -  TonKho_C = σ(MaKho='KHO_C')(TonKho)

   Ràng buộc CK_TonKho_Manh chính là ĐỊNH NGHĨA MẢNH được cưỡng chế ở tầng CSDL:
   site này TUYỆT ĐỐI không chứa được dòng tồn kho của kho khác.
   Cột RowVer (rowversion) phục vụ điều khiển tương tranh lạc quan (mục 07).
   ---------------------------------------------------------------------------- */

CREATE TABLE TonKho (
    MaKho       CHAR(5)      NOT NULL,
    MaVT        CHAR(5)      NOT NULL,
    SoLuong     INT          NOT NULL,
    NgayCapNhat DATETIME2(0) NOT NULL CONSTRAINT DF_TonKho_Ngay DEFAULT SYSDATETIME(),
    RowVer      ROWVERSION   NOT NULL,
    CONSTRAINT PK_TonKho       PRIMARY KEY (MaKho, MaVT),
    CONSTRAINT CK_TonKho_SL    CHECK (SoLuong >= 0),
    CONSTRAINT CK_TonKho_Manh  CHECK (MaKho = 'KHO_C'),   -- <<< ĐỊNH NGHĨA MẢNH
    CONSTRAINT FK_TonKho_Kho   FOREIGN KEY (MaKho) REFERENCES Kho(MaKho),
    CONSTRAINT FK_TonKho_VatTu FOREIGN KEY (MaVT)  REFERENCES VatTu(MaVT)
);
GO

/* ----------------------------------------------------------------------------
   PHẦN 3. CHỨNG TỪ
     PhieuNhap_C / PhieuXuat_C : phân mảnh ngang NGUYÊN THỦY theo MaKho
     ChiTietNhap_C / ChiTietXuat_C : phân mảnh ngang DẪN XUẤT (nửa nối
        theo MaPN / MaPX) - vì hai bảng này KHÔNG có thuộc tính MaKho

   Mã phiếu nhúng ký tự kho ('PNC0001') để khóa chính không đụng nhau giữa 3 site.
   ---------------------------------------------------------------------------- */

CREATE TABLE PhieuNhap (
    MaPN      CHAR(7)       NOT NULL CONSTRAINT PK_PhieuNhap PRIMARY KEY,
    MaKho     CHAR(5)       NOT NULL,
    MaNCC     CHAR(5)       NOT NULL,
    NgayNhap  DATETIME2(0)  NOT NULL,
    NguoiLap  NVARCHAR(50)  NOT NULL,
    TrangThai VARCHAR(12)   NOT NULL DEFAULT 'HOAN_TAT',
    CONSTRAINT CK_PN_Manh  CHECK (MaKho = 'KHO_C'),        -- <<< ĐỊNH NGHĨA MẢNH
    CONSTRAINT CK_PN_MaSo  CHECK (MaPN LIKE 'PNC[0-9][0-9][0-9][0-9]'),
    CONSTRAINT FK_PN_Kho   FOREIGN KEY (MaKho) REFERENCES Kho(MaKho),
    CONSTRAINT FK_PN_NCC   FOREIGN KEY (MaNCC) REFERENCES NhaCungCap(MaNCC)
);
GO

CREATE TABLE ChiTietNhap (
    MaPN    CHAR(7)       NOT NULL,
    MaVT    CHAR(5)       NOT NULL,
    SoLuong INT           NOT NULL CONSTRAINT CK_CTN_SL CHECK (SoLuong > 0),
    DonGia  DECIMAL(14,0) NOT NULL,
    CONSTRAINT PK_ChiTietNhap PRIMARY KEY (MaPN, MaVT),
    CONSTRAINT FK_CTN_PN      FOREIGN KEY (MaPN) REFERENCES PhieuNhap(MaPN),
    CONSTRAINT FK_CTN_VatTu   FOREIGN KEY (MaVT) REFERENCES VatTu(MaVT)
);
GO

CREATE TABLE PhieuXuat (
    MaPX      CHAR(7)       NOT NULL CONSTRAINT PK_PhieuXuat PRIMARY KEY,
    MaKho     CHAR(5)       NOT NULL,
    NgayXuat  DATETIME2(0)  NOT NULL,
    NguoiNhan NVARCHAR(100) NOT NULL,
    NguoiLap  NVARCHAR(50)  NOT NULL,
    TrangThai VARCHAR(12)   NOT NULL DEFAULT 'HOAN_TAT',
    CONSTRAINT CK_PX_Manh CHECK (MaKho = 'KHO_C'),         -- <<< ĐỊNH NGHĨA MẢNH
    CONSTRAINT CK_PX_MaSo CHECK (MaPX LIKE 'PXC[0-9][0-9][0-9][0-9]'),
    CONSTRAINT FK_PX_Kho  FOREIGN KEY (MaKho) REFERENCES Kho(MaKho)
);
GO

CREATE TABLE ChiTietXuat (
    MaPX    CHAR(7)       NOT NULL,
    MaVT    CHAR(5)       NOT NULL,
    SoLuong INT           NOT NULL CONSTRAINT CK_CTX_SL CHECK (SoLuong > 0),
    DonGia  DECIMAL(14,0) NOT NULL,
    CONSTRAINT PK_ChiTietXuat PRIMARY KEY (MaPX, MaVT),
    CONSTRAINT FK_CTX_PX      FOREIGN KEY (MaPX) REFERENCES PhieuXuat(MaPX),
    CONSTRAINT FK_CTX_VatTu   FOREIGN KEY (MaVT) REFERENCES VatTu(MaVT)
);
GO

/* ----------------------------------------------------------------------------
   PHẦN 4. PHIẾU ĐIỀU CHUYỂN - ghi ở CẢ 2 SITE trong một giao tác phân tán
   ---------------------------------------------------------------------------- */

CREATE TABLE PhieuDieuChuyen (
    MaDC       CHAR(6)       NOT NULL CONSTRAINT PK_PhieuDieuChuyen PRIMARY KEY,
    MaKhoNguon CHAR(5)       NOT NULL,
    MaKhoDich  CHAR(5)       NOT NULL,
    MaVT       CHAR(5)       NOT NULL,
    SoLuong    INT           NOT NULL CONSTRAINT CK_DC_SL CHECK (SoLuong > 0),
    NgayLap    DATETIME2(0)  NOT NULL CONSTRAINT DF_DC_Ngay DEFAULT SYSDATETIME(),
    TrangThai  VARCHAR(12)   NOT NULL,
    GhiChu     NVARCHAR(200) NULL,
    CONSTRAINT CK_DC_KhacKho   CHECK (MaKhoNguon <> MaKhoDich),
    CONSTRAINT CK_DC_TrangThai CHECK (TrangThai IN ('CHO_DUYET','HOAN_TAT','THAT_BAI','DA_HUY')),
    CONSTRAINT CK_DC_LienQuan  CHECK (MaKhoNguon = 'KHO_C' OR MaKhoDich = 'KHO_C')
);
GO

/* ----------------------------------------------------------------------------
   PHẦN 5. CHỈ MỤC HỖ TRỢ
   ---------------------------------------------------------------------------- */

CREATE INDEX IX_TonKho_MaVT      ON TonKho(MaVT) INCLUDE (SoLuong);
CREATE INDEX IX_PhieuNhap_Ngay   ON PhieuNhap(NgayNhap);
CREATE INDEX IX_PhieuXuat_Ngay   ON PhieuXuat(NgayXuat);
CREATE INDEX IX_DieuChuyen_Ngay  ON PhieuDieuChuyen(NgayLap);
GO

/* ----------------------------------------------------------------------------
   PHẦN 6. DỮ LIỆU DANH MỤC

   Ba site nạp danh mục GIỐNG HỆT NHAU để chạy thử được ngay trước khi
   cấu hình replication. Sau khi Publication hoạt động, dữ liệu ở KHO_B và
   KHO_C sẽ do Distribution Agent làm chủ.
   ---------------------------------------------------------------------------- */

INSERT INTO NhaCungCap (MaNCC, TenNCC, DiaChi, DienThoai, Email) VALUES
 ('NCC01', N'Công ty VLXD Hòa Phát', N'Khu CN Phố Nối A, Hưng Yên', '0221-3941-888', 'kinhdoanh@hoaphat.vn'),
 ('NCC02', N'Công ty Khoáng sản Miền Bắc', N'Km12 QL3, Thái Nguyên', '0208-3855-246', 'sales@khoangsanmb.vn'),
 ('NCC03', N'Công ty Sơn & Nhựa Đông Á', N'Lô C5 KCN Sóng Thần, Bình Dương', '0274-3790-121', 'info@donga-paint.vn'),
 ('NCC04', N'Công ty Thiết bị điện Quang Minh', N'45 Trường Chinh, Hà Nội', '024-3868-7799', 'cskh@quangminh.com.vn');
GO

INSERT INTO VatTu (MaVT, TenVT, DonViTinh, DonGia, MaNCC, MucTonToiThieu) VALUES
 ('VT001', N'Xi măng PCB40', N'Bao', 95000, 'NCC01', 100),
 ('VT002', N'Thép cây phi 16', N'Cây', 185000, 'NCC01', 50),
 ('VT003', N'Gạch ống 8x8x18', N'Viên', 1500, 'NCC02', 5000),
 ('VT004', N'Cát xây dựng', N'Khối', 320000, 'NCC02', 20),
 ('VT005', N'Đá 1x2', N'Khối', 380000, 'NCC02', 20),
 ('VT006', N'Sơn nước nội thất 18L', N'Thùng', 1250000, 'NCC03', 10),
 ('VT007', N'Ống nhựa PVC phi 90', N'Cây', 78000, 'NCC03', 40),
 ('VT008', N'Dây điện Cadivi 2.5mm', N'Cuộn', 890000, 'NCC04', 15),
 ('VT009', N'Bóng đèn LED 9W', N'Cái', 45000, 'NCC04', 200),
 ('VT010', N'Khóa cửa tay gạt', N'Bộ', 350000, 'NCC04', 30);
GO

INSERT INTO Kho (MaKho, TenKho, DiaChi, ServerName) VALUES
 ('KHO_A', N'Kho Trung tâm', N'15 Nguyễn Trãi, Thanh Xuân, Hà Nội', N'MIGNON\KHO_A'),
 ('KHO_B', N'Kho Miền Bắc', N'22 Lê Thái Tổ, TP. Bắc Ninh, Bắc Ninh', N'MIGNON\KHO_B'),
 ('KHO_C', N'Kho Miền Nam', N'88 Võ Văn Kiệt, Quận 1, TP. Hồ Chí Minh', N'MIGNON\KHO_C');
GO

/* ----------------------------------------------------------------------------
   PHẦN 7. DỮ LIỆU MẢNH CỦA RIÊNG SITE NÀY
   ---------------------------------------------------------------------------- */

INSERT INTO TonKho (MaKho, MaVT, SoLuong) VALUES
 ('KHO_C', 'VT001', 240),
 ('KHO_C', 'VT002', 130),
 ('KHO_C', 'VT003', 6000),
 ('KHO_C', 'VT005', 30),
 ('KHO_C', 'VT008', 18),
 ('KHO_C', 'VT009', 420),
 ('KHO_C', 'VT010', 45);
GO

-- Phiếu nhập
INSERT INTO PhieuNhap (MaPN, MaKho, MaNCC, NgayNhap, NguoiLap) VALUES
 ('PNC0001', 'KHO_C', 'NCC01', '2026-08-07 08:45', N'Lê Minh Tuấn');
INSERT INTO ChiTietNhap (MaPN, MaVT, SoLuong, DonGia) VALUES
 ('PNC0001', 'VT001', 120, 95000),
 ('PNC0001', 'VT002', 60, 185000);

INSERT INTO PhieuNhap (MaPN, MaKho, MaNCC, NgayNhap, NguoiLap) VALUES
 ('PNC0002', 'KHO_C', 'NCC04', '2026-08-18 15:30', N'Lê Minh Tuấn');
INSERT INTO ChiTietNhap (MaPN, MaVT, SoLuong, DonGia) VALUES
 ('PNC0002', 'VT008', 10, 890000),
 ('PNC0002', 'VT009', 200, 45000);

GO

-- Phiếu xuất
INSERT INTO PhieuXuat (MaPX, MaKho, NgayXuat, NguoiNhan, NguoiLap) VALUES
 ('PXC0001', 'KHO_C', '2026-08-22 14:00', N'Cao ốc Bitexco', N'Võ Thị Ngọc');
INSERT INTO ChiTietXuat (MaPX, MaVT, SoLuong, DonGia) VALUES
 ('PXC0001', 'VT002', 40, 192000),
 ('PXC0001', 'VT009', 150, 48000);

INSERT INTO PhieuXuat (MaPX, MaKho, NgayXuat, NguoiNhan, NguoiLap) VALUES
 ('PXC0002', 'KHO_C', '2026-08-28 09:50', N'Khu dân cư Phú Mỹ Hưng', N'Võ Thị Ngọc');
INSERT INTO ChiTietXuat (MaPX, MaVT, SoLuong, DonGia) VALUES
 ('PXC0002', 'VT001', 80, 98000);

GO

/* ----------------------------------------------------------------------------
   PHẦN 8. KIỂM TRA SAU KHI CHẠY
   ---------------------------------------------------------------------------- */

PRINT N'===== SITE KHO_C / DATABASE KhoC =====';

SELECT N'NhaCungCap' AS Bang, COUNT(*) AS SoDong FROM NhaCungCap
UNION ALL SELECT N'VatTu',           COUNT(*) FROM VatTu
UNION ALL SELECT N'Kho',             COUNT(*) FROM Kho
UNION ALL SELECT N'TonKho (mảnh)',   COUNT(*) FROM TonKho
UNION ALL SELECT N'PhieuNhap',       COUNT(*) FROM PhieuNhap
UNION ALL SELECT N'ChiTietNhap',     COUNT(*) FROM ChiTietNhap
UNION ALL SELECT N'PhieuXuat',       COUNT(*) FROM PhieuXuat
UNION ALL SELECT N'ChiTietXuat',     COUNT(*) FROM ChiTietXuat;
GO

-- Bằng chứng PHÂN MẢNH: site này chỉ chứa đúng một giá trị MaKho
SELECT DISTINCT MaKho AS MaKho_DuyNhat_TaiSiteNay FROM TonKho;
GO

-- Bằng chứng RÀNG BUỘC MẢNH: câu dưới PHẢI lỗi (msg 547) - đó là kết quả ĐÚNG
BEGIN TRY
    INSERT INTO TonKho (MaKho, MaVT, SoLuong) VALUES ('KHO_B', 'VT001', 1);
    PRINT N'SAI: đáng lẽ phải bị chặn!';
END TRY
BEGIN CATCH
    PRINT N'ĐÚNG: ràng buộc mảnh đã chặn - ' + ERROR_MESSAGE();
END CATCH
GO
