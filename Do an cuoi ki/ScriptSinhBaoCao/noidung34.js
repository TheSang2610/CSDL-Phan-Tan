// CHƯƠNG III và CHƯƠNG IV của cuốn báo cáo
const H = require('./helper');
const { p, h1, h2, h3, li, no, code, fig, ghiChuAnh, tabCap, table, pageBreak } = H;

const A = 'D:\\CSDL PHAN TAN\\Do an cuoi ki\\AnhChup\\';
const I = 'D:\\CSDL PHAN TAN\\ảnh\\';

function chuongIII() {
  return [
    h1('CHƯƠNG III. TRIỂN KHAI HỆ THỐNG'),
    p('Chương này trình bày quá trình cài đặt vật lý thực tế của hệ thống, kèm ảnh chụp màn hình minh chứng cho từng bước.'),

    // ================= 3.1 =================
    h2('1. Cài đặt mạng riêng ảo'),
    p('Ba kho trong bài toán nằm ở ba tỉnh thành khác nhau, nên phải có một mạng riêng ảo để ba máy chủ thấy nhau như trong cùng một mạng nội bộ. Nhóm chọn **ZeroTier** vì miễn phí, cài đặt đơn giản và tạo được mạng LAN ảo xuyên Internet.'),
    p('Các bước thực hiện:'),
    no(1, 'Tải và cài ZeroTier trên cả ba máy.'),
    no(2, 'Tạo một network riêng cho nhóm, thu được **Network ID** gồm 16 ký tự.'),
    no(3, 'Mỗi máy tham gia network bằng Network ID đó.'),
    no(4, 'Người quản trị network duyệt (Authorize) từng máy trên trang quản lý.'),
    no(5, 'Mỗi máy được cấp một địa chỉ IP ảo riêng — network của nhóm được cấp dải **10.91.x.x**.'),
    p('Sau bước này, ba máy chủ có thể gọi nhau bằng địa chỉ IP ảo, bất kể chúng đang ở mạng vật lý nào.'),

    ...fig(A + '3.1_VPN_ZeroTier\\01_TaoNetwork_NetworkID.png',
           'Network riêng của nhóm vừa được tạo, kèm Network ID mười sáu ký tự dùng để mời hai máy còn lại', 'III'),
    ...fig(A + '3.1_VPN_ZeroTier\\02_ThanhVien_DaDuyet.png',
           'Danh sách thành viên của network. Mỗi máy chỉ vào được sau khi người quản trị tích ô Auth', 'III'),
    ...fig(A + '3.1_VPN_ZeroTier\\03_IPAo_TrenMay.png',
           'Địa chỉ IP ảo mà ZeroTier cấp cho máy chủ, đối chiếu giữa trang quản lý network và lệnh ipconfig trên chính máy đó', 'III'),
    ...ghiChuAnh(A + '3.1_VPN_ZeroTier\\01_TaoNetwork_NetworkID.png'),

    // ================= 3.2 =================
    h2('2. Tạo đường liên kết mạng giữa các máy chủ'),
    p('Sau khi có mạng ảo, phải mở đường cho SQL Server nghe trên mạng. Mặc định sau khi cài, ba thể hiện SQL Server chỉ giao tiếp qua **Shared Memory** — bộ nhớ chung trong cùng một máy — nên máy khác không thể kết nối tới.'),
    p('Ba việc cần làm trên mỗi máy chủ:'),
    no(1, '**Bật giao thức TCP/IP** cho từng thể hiện SQL Server.'),
    no(2, '**Gán cổng cố định** cho từng thể hiện. Không dùng cổng động vì cổng động thay đổi sau mỗi lần khởi động, không thể mở tường lửa và máy khác không biết đường nào mà nối.'),
    no(3, '**Mở tường lửa** cho các cổng đó, cho cổng UDP 1434 của SQL Server Browser, và cho dịch vụ **MS DTC** — thiếu MS DTC thì giao tác phân tán giữa hai máy không chạy được.'),
    tabCap('Cổng TCP được gán cho ba thể hiện', 'III'),
    table(
      ['Site', 'Thể hiện', 'Cổng TCP', 'Vai trò'],
      [
        ['S1', 'MIGNON\\KHO_A', '1440', 'Kho Trung tâm — Publisher + Distributor'],
        ['S2', 'MIGNON\\KHO_B', '1441', 'Kho Miền Bắc — Subscriber'],
        ['S3', 'MIGNON\\KHO_C', '1442', 'Kho Miền Nam — Subscriber'],
      ], [8, 24, 14, 54]),
    p('Việc kiểm chứng đường truyền được thực hiện bằng khung nhìn hệ thống `sys.dm_exec_connections`. Khi kết nối theo tên thể hiện trong cùng một máy, cột `net_transport` cho giá trị **Shared memory**; khi kết nối qua địa chỉ IP ảo, cột này cho giá trị **TCP** kèm đúng địa chỉ ảo — đó là bằng chứng bằng số liệu rằng dữ liệu thật sự đi qua mạng.'),

    p('Ba việc trên được gộp vào một tập lệnh PowerShell chạy một lần với quyền quản trị, nhờ đó lặp lại được y hệt trên máy của từng thành viên mà không sợ sót bước hay gõ nhầm cổng.'),
    ...fig(A + '3.2_LinkMang\\00_KetQuaChayScript.png',
           'Kết quả tập lệnh cấu hình mạng: ba cổng đã được lắng nghe, bảy dịch vụ đều ở trạng thái Running và Automatic', 'III', { width: 250 }),

    ...fig(A + '3.2_LinkMang\\01_TCPIP_Enabled.png',
           'Giao thức TCP/IP được bật cho thể hiện SQL Server trong SQL Server Configuration Manager', 'III'),
    ...fig(A + '3.2_LinkMang\\02_CongCoDinh.png',
           'Gán cổng cố định tại mục IPAll, đồng thời xoá trắng ô cổng động', 'III'),
    ...fig(A + '3.2_LinkMang\\03_TuongLua.png',
           'Các luật tường lửa mở cho ba cổng thể hiện, cổng UDP 1434 của SQL Server Browser và dịch vụ MS DTC', 'III'),
    ...fig(A + '3.2_LinkMang\\04_NetTransport_TCP.png',
           'Kết nối qua địa chỉ IP ảo cho net_transport bằng TCP — dữ liệu thật sự đi qua mạng chứ không qua bộ nhớ chung', 'III'),
    ...ghiChuAnh(A + '3.2_LinkMang\\01_TCPIP_Enabled.png'),

    // ================= 3.3 =================
    pageBreak(),
    h2('3. Cài đặt SQL Server'),
    p('Nhóm cài **SQL Server 2022 Developer Edition** — bản miễn phí có đầy đủ tính năng của bản Enterprise, khác với bản Express vốn **không hỗ trợ Replication làm Publisher**, tức là không dùng được cho đồ án này.'),
    p('Quá trình cài đặt được lặp lại **ba lần** để tạo ba thể hiện độc lập trên cùng một máy. Mỗi thể hiện có dịch vụ Windows riêng, SQL Server Agent riêng, thư mục dữ liệu riêng và cổng mạng riêng.'),

    ...fig(I + 'KHO A\\Screenshot 2026-09-12 164629.png', 'Chọn phiên bản Developer — miễn phí và đầy đủ tính năng', 'III', { width: 470 }),
    ...fig(I + 'KHO A\\Screenshot 2026-09-12 165024.png', 'Chọn tính năng cài đặt. Bắt buộc tích SQL Server Replication, thiếu mục này là không làm được nhân bản', 'III', { width: 470 }),
    p('Tại màn hình này nhóm cũng đổi **Instance root directory** sang ổ D để tách dữ liệu khỏi ổ hệ thống.'),

    ...fig(I + 'KHO A\\Screenshot 2026-09-12 165113.png', 'Đặt tên thể hiện là KHO_A. Đây là bước quyết định ba site độc lập với nhau', 'III', { width: 470 }),
    ...fig(I + 'KHO A\\Screenshot 2026-09-12 165154.png', 'Đặt SQL Server Agent ở chế độ Automatic — điều kiện bắt buộc để các tiến trình nhân bản chạy được', 'III', { width: 470 }),
    ...fig(I + 'KHO A\\Screenshot 2026-09-12 165230.png', 'Chọn Mixed Mode để dùng được tài khoản sa. Linked Server giữa các site sẽ đăng nhập bằng tài khoản này', 'III', { width: 470 }),
    ...fig(I + 'KHO A\\Screenshot 2026-09-12 165330.png', 'Thư mục dữ liệu riêng của từng thể hiện', 'III', { width: 470 }),
    ...fig(I + 'KHO A\\Screenshot 2026-09-12 165649.png', 'Cài đặt thể hiện KHO_A hoàn tất, cả Database Engine và Replication đều Succeeded', 'III', { width: 470 }),
    ...fig(I + 'KHO B\\Screenshot 2026-09-12 170014.png', 'Cài thể hiện thứ hai. Bảng Installed instances đã có KHO_A, chọn Perform a new installation để tạo thêm thể hiện mới', 'III', { width: 470 }),
    ...fig(I + 'KHO C\\Screenshot 2026-09-12 171726.png', 'Cài thể hiện thứ ba KHO_C. Bảng dưới cho thấy KHO_A và KHO_B đã tồn tại — ba thể hiện chạy song song trên cùng một máy', 'III', { width: 470 }),
    ...fig(I + 'KHO C\\Screenshot 2026-09-12 172340.png', 'Hoàn tất cài đặt cả ba thể hiện', 'III', { width: 470 }),
    ...fig(A + '3.3_CaiDat_SQLServer\\99_SSMS_3Instance.png', 'Ba thể hiện hiện diện cùng lúc trong Object Explorer của SSMS — hình ảnh đại diện cho toàn bộ hệ thống phân tán', 'III'),

    // ================= 3.4 =================
    pageBreak(),
    h2('4. Kiểm tra dịch vụ Agent'),
    p('SQL Server Agent là tiến trình nền chạy các công việc theo lịch. Trong đồ án này nó **bắt buộc phải chạy**, vì hai tiến trình của nhân bản — Log Reader Agent và Distribution Agent — đều là công việc do Agent điều khiển. Agent dừng thì dữ liệu danh mục sẽ không được đẩy xuống hai kho vệ tinh.'),
    ...fig(A + '3.4_DichVu_Agent\\01_ConfigurationManager_7Service.png', 'Bảy dịch vụ của hệ thống đều ở trạng thái Running và Automatic', 'III'),
    p('Bảy dịch vụ trong ảnh gồm:'),
    li('**Ba dịch vụ SQL Server** — ba máy chủ cơ sở dữ liệu của ba kho.'),
    li('**Ba dịch vụ SQL Server Agent** — điều kiện để nhân bản hoạt động.'),
    li('**SQL Server Browser** — giúp máy khác tìm được thể hiện theo tên thay vì phải nhớ số cổng.'),
    p('Cả bảy đều đặt **Start Mode = Automatic**, nghĩa là tự khởi động cùng máy, không cần người dùng bật tay.'),

    // ================= 3.5 =================
    pageBreak(),
    h2('5. Tạo liên kết cơ sở dữ liệu giữa các máy chủ'),
    p('**Linked Server** là cơ chế cho phép một thể hiện SQL Server truy vấn dữ liệu nằm trên thể hiện khác như thể đó là bảng của chính mình. Đây là nền tảng kỹ thuật của **truy vấn phân tán** và **giao tác phân tán**.'),
    p('Hệ thống tạo **sáu liên kết** — mỗi site nối tới hai site còn lại, tạo thành đồ thị hai chiều đầy đủ:'),
    ...code([
      '   KHO_A ──► KHO_B      KHO_B ──► KHO_A      KHO_C ──► KHO_A',
      '   KHO_A ──► KHO_C      KHO_B ──► KHO_C      KHO_C ──► KHO_B',
    ]),
    ...fig(A + '3.5_LinkedServer\\01_DanhSachLinkedServer.png', 'Hai Linked Server tại site KHO_A trong Object Explorer', 'III'),
    ...fig(A + '3.5_LinkedServer\\02_General.png', 'Trang General — khai báo nguồn dữ liệu của liên kết', 'III'),
    ...fig(A + '3.5_LinkedServer\\03_Security.png', 'Trang Security — ánh xạ đăng nhập sang tài khoản cố định ở máy đích', 'III'),
    p('Bốn tuỳ chọn bắt buộc phải bật cho mỗi liên kết, thiếu cái nào hỏng chức năng tương ứng:'),
    tabCap('Bốn tuỳ chọn của Linked Server', 'III'),
    table(
      ['Tuỳ chọn', 'Tác dụng', 'Thiếu thì sao'],
      [
        ['data access', 'Cho phép đọc dữ liệu qua liên kết', 'Lỗi Msg 7411 — not configured for DATA ACCESS'],
        ['rpc', 'Cho phép nhận lời gọi thủ tục từ xa', 'Không gọi được thủ tục ở site kia'],
        ['rpc out', 'Cho phép gọi thủ tục sang site kia', 'Không điều chuyển hàng được'],
        ['remote proc transaction promotion', 'Tự nâng lời gọi thủ tục từ xa lên giao tác phân tán', 'Nửa việc ở máy kia không được quay lui cùng máy này'],
      ], [26, 34, 40]),
    p('**Một sự cố thực tế nhóm đã gặp và khắc phục:** sau khi cấu hình nhân bản, thủ tục `sp_addsubscription` **ghi đè lại mục Linked Server** của Subscriber và **tắt tuỳ chọn `data access`**, vì bản thân nhân bản giao tiếp bằng cơ chế RPC riêng, không cần tới truy vấn phân tán. Hậu quả là mọi truy vấn phân tán đang chạy tốt bỗng báo lỗi **Msg 7411**. Nhóm đã bổ sung một bước bật lại các tuỳ chọn này vào cuối kịch bản cấu hình nhân bản.'),
    ...fig(A + '3.5_LinkedServer\\04_TruyVanPhanTan.png', 'Truy vấn phân tán đầu tiên — đứng tại KHO_A nhưng đọc được dữ liệu tồn kho của cả ba site', 'III'),
    p('Kết quả trả về ba dòng tương ứng ba mảnh dữ liệu, chứng minh hệ thống thật sự phân tán và các liên kết hoạt động.'),

    // ================= 3.6 =================
    pageBreak(),
    h2('6. Tạo Publication'),
    p('Publication là đơn vị cấu hình của Transactional Replication, mô tả **những bảng nào được nhân bản** và **nhân bản xuống đâu**. Nhóm tạo Publication tên **PUB_DanhMuc** tại KHO_A gồm ba bài viết (article): VatTu, NhaCungCap và Kho.'),
    ...fig(A + '3.6_Publication_Replication\\01_Publication_ObjectExplorer.png', 'Publication PUB_DanhMuc trong Object Explorer tại site KHO_A', 'III'),
    ...fig(A + '3.6_Publication_Replication\\02_Articles_3Bang.png', 'Ba bảng danh mục được chọn làm article của Publication', 'III'),
    ...fig(A + '3.6_Publication_Replication\\03_ReplicationMonitor.png', 'Replication Monitor — hai Subscription đều ở trạng thái hoạt động', 'III'),
    p('**Hai vấn đề kỹ thuật nhóm đã xử lý trong bước này:**'),
    no(1, '**Xung đột khoá ngoại khi tạo snapshot.** Ba bảng danh mục có ràng buộc khoá ngoại với nhau và với các bảng khác ở Subscriber. Nếu để cơ chế snapshot mặc định, tiến trình sẽ cố xoá và tạo lại bảng ở Subscriber, gây xung đột. Nhóm dùng tham số `@sync_type = \'replication support only\'` để chỉ tạo cơ chế nhân bản mà không đụng tới dữ liệu sẵn có.'),
    no(2, '**Distribution Agent không kết nối được tới Subscriber.** Tiến trình này chạy dưới tài khoản dịch vụ `NT Service\\SQLAgent$KHO_A`, vốn không có quyền đăng nhập ở hai thể hiện kia. Nhóm khắc phục bằng cách đặt `@subscriber_security_mode = 0` và chỉ định tài khoản SQL đăng nhập vào Subscriber.'),
    ...fig(A + '3.6_Publication_Replication\\05_BangChungDongBo.png', 'Bằng chứng đồng bộ — sửa danh mục tại KHO_A, sau khoảng 20 giây cả KHO_B và KHO_C đều tự động cập nhật theo', 'III'),
    p('Kịch bản kiểm chứng gồm ba thao tác để chứng minh cả ba loại lệnh đều được nhân bản: **UPDATE** đổi giá một vật tư, **INSERT** thêm một vật tư mới, và **DELETE** khi hoàn tác. Số lượng vật tư ở ba site luôn bằng nhau sau mỗi lần đồng bộ.'),

    // ================= 3.7 =================
    pageBreak(),
    h2('7. Thử các giao tác tương ứng với các chức năng'),

    h3('7.1. Nhập dữ liệu'),
    p('Năm thủ tục nghiệp vụ được cài đặt và chạy **giống hệt nhau trên cả ba site**, không sửa một dòng nào. Điều này thực hiện được nhờ một hàm nhỏ tự nhận biết site đang chạy:'),
    ...code([
      '   CREATE FUNCTION dbo.fn_MaKhoHienTai() RETURNS CHAR(5)',
      '   AS BEGIN',
      '       RETURN \'KHO_\' + UPPER(RIGHT(DB_NAME(), 1));',
      '   END',
    ]),
    tabCap('Năm thủ tục nghiệp vụ', 'III'),
    table(
      ['Thủ tục', 'Chức năng', 'Kỹ thuật đáng chú ý'],
      [
        ['sp_NhapKho', 'F1 — Nhập vật tư vào kho', 'Dùng tham số kiểu bảng (TVP) để nhận nhiều dòng hàng trong một lần gọi; dùng MERGE để cộng tồn'],
        ['sp_XuatKho', 'F2 — Xuất vật tư khỏi kho', 'Kiểm tra tồn với gợi ý khoá UPDLOCK, HOLDLOCK để chống mất cập nhật'],
        ['sp_TraCuuTonKho', 'F3 — Tra cứu tồn tại chỗ', 'Truy vấn cục bộ, không qua mạng'],
        ['sp_CanhBaoTonToiThieu', 'F7 — Cảnh báo thiếu hàng', 'So sánh tồn với mức tối thiểu trong danh mục'],
        ['sp_DieuChuyenVatTu', 'F5 — Điều chuyển giữa hai kho', 'Giao tác phân tán hai pha qua MS DTC'],
      ], [22, 26, 52]),
    p('Thủ tục xuất kho được thiết kế để **từ chối xuất quá tồn**: nếu số lượng yêu cầu vượt tồn hiện có, giao tác bị huỷ và trả về thông báo nêu rõ mã vật tư, số tồn còn lại và số cần xuất.'),

    h3('7.2. Hiển thị dữ liệu'),
    p('Mục này kiểm chứng bốn điều: dữ liệu có được phân mảnh đúng không, có được nhân bản đúng không, các liên kết có hoạt động không, và có đồng bộ không.'),

    p('**a) Tồn kho toàn hệ thống**'),
    ...fig(A + '3.7_KetQua_GiaoTac\\09_HienThi_TonKhoToanHeThong.png', 'Tồn kho toàn hệ thống — 24 dòng gộp từ ba site, hiển thị như một bảng duy nhất', 'III'),
    p('Một câu lệnh SELECT duy nhất, nhưng bộ tối ưu đã phải mở hai kết nối qua Linked Server, lấy dữ liệu từ KHO_B và KHO_C, gộp với dữ liệu tại chỗ rồi mới tính tổng. Người dùng hoàn toàn không thấy điều đó — **đây chính là trong suốt phân mảnh**.'),

    p('**b) Kiểm tra phân mảnh**'),
    ...fig(A + '3.7_KetQua_GiaoTac\\12_KiemTra_PhanManh.png', 'Kiểm chứng ba tính chất của phân mảnh cùng phép thử vi phạm', 'III'),
    tabCap('Kết quả kiểm chứng phân mảnh', 'III'),
    table(
      ['Phép kiểm tra', 'Kết quả thực tế', 'Kết luận'],
      [
        ['Tính tách rời', 'Mỗi site chỉ chứa đúng 1 mã kho; 0 dòng trùng giữa các mảnh', 'ĐẠT'],
        ['Tính đầy đủ', '3 kho trong danh mục = 3 mảnh có dữ liệu', 'ĐẠT'],
        ['Tính tái thiết', '10 + 7 + 7 = 24 dòng, bằng đúng số dòng quan hệ toàn cục', 'ĐẠT'],
        ['Phân mảnh dẫn xuất', '6 dòng chi tiết nhập đều thuộc phiếu của site mình; 4 dòng chi tiết xuất tương tự', 'ĐẠT'],
        ['Thử ghi sai mảnh', 'Bị chặn bằng lỗi 547 — ràng buộc CK_TonKho_Manh', 'ĐẠT'],
      ], [22, 52, 26]),

    p('**c) Kiểm tra nhân bản và đồng bộ**'),
    ...fig(A + '3.7_KetQua_GiaoTac\\13_KiemTra_NhanBan.png', 'So khớp ba bản sao danh mục bằng vân tay CHECKSUM_AGG', 'III'),
    p('Phương pháp kiểm chứng: tính **vân tay (checksum tổng hợp)** của toàn bộ bảng VatTu tại cả ba site. Chỉ cần một ô dữ liệu lệch nhau là vân tay đổi ngay. Kết quả thực tế: cả ba site cùng cho giá trị **347490305**, nghĩa là ba bản sao giống hệt nhau tới từng ô.'),
    p('Phép kiểm tra thứ hai dùng toán tử EXCEPT để tìm những dòng có ở site này mà thiếu ở site kia — kết quả không trả về dòng nào, xác nhận đồng bộ hoàn toàn.'),

    p('**d) Kiểm tra Linked Server**'),
    ...fig(A + '3.7_KetQua_GiaoTac\\14_KiemTra_LinkedServer.png', 'Danh sách liên kết, ánh xạ đăng nhập, kết quả thử kết nối và thông tin phiên bản đọc ngược từ hai site kia', 'III'),
    p('Bảng cuối cùng trong ảnh đọc ngược `@@SERVERNAME` và phiên bản của hai site còn lại thông qua liên kết — bằng chứng trực tiếp rằng liên kết đang hoạt động thật.'),

    p('**e) Trong suốt vị trí**'),
    ...fig(A + '3.7_KetQua_GiaoTac\\20_TrongSuotViTri.png', 'Thủ tục sp_TonKhoToanHeThong dựng câu lệnh tự động từ bảng Kho', 'III'),
    p('Thủ tục này đọc tên máy chủ từ **cột ServerName của bảng Kho** rồi mới dựng câu lệnh. Thêm một kho mới chỉ cần thêm một dòng vào bảng Kho, **không phải sửa một dòng mã nguồn nào** — đó là trong suốt vị trí.'),

    h3('7.3. Thống kê'),
    ...fig(A + '3.7_KetQua_GiaoTac\\10_ThongKe.png', 'Thống kê toàn hệ thống theo kho, theo vật tư và theo tỷ trọng vốn', 'III'),
    tabCap('Số liệu thống kê toàn hệ thống', 'III'),
    table(
      ['Site', 'Số mặt hàng', 'Tổng số lượng', 'Tổng giá trị (VND)'],
      [
        ['KHO_A — Kho Trung tâm', '10', '13.970', '318.050.000'],
        ['KHO_B — Kho Miền Bắc', '7', '5.231', '87.830.000'],
        ['KHO_C — Kho Miền Nam', '7', '7.003', '133.820.000'],
        ['**Cộng toàn hệ thống**', '**24**', '**26.204**', '**539.700.000**'],
      ], [34, 20, 22, 24]),
    ...fig(A + '3.7_KetQua_GiaoTac\\11_CanhBao_ThieuHang.png', 'Cảnh báo thiếu hàng kèm đề xuất kho cấp bù', 'III'),
    p('Đây là truy vấn phân tán **có giá trị nghiệp vụ thật**, không chỉ để minh hoạ: nó tìm mặt hàng đang dưới mức tối thiểu ở kho này, đồng thời chỉ ra kho nào đang dư để điều chuyển sang. Kết quả của nó chính là đầu vào cho thủ tục điều chuyển.'),
    ...fig(A + '3.7_KetQua_GiaoTac\\15_SoSanh_OpenQuery.png', 'So sánh hai cách viết truy vấn phân tán qua thời gian thực thi', 'III'),
    p('Cùng một nhu cầu có hai cách viết. Cách dùng **tên bốn phần** buộc máy chủ phải kéo toàn bộ dòng dữ liệu thô về rồi mới gom nhóm. Cách dùng **OPENQUERY** gửi nguyên văn câu lệnh sang máy đích, máy đó tự gom nhóm rồi chỉ trả về kết quả đã tóm tắt. Trong cơ sở dữ liệu phân tán, chi phí lớn nhất là truyền dữ liệu qua mạng, nên với bảng lớn cách thứ hai luôn thắng.'),

    h3('7.4. Trigger phân quyền bảo vệ các bảng'),
    p('Hệ thống dùng **ba lớp bảo vệ chồng lên nhau**, mỗi lớp bắt được loại vi phạm mà lớp kia không thấy.'),
    tabCap('Ba lớp bảo vệ dữ liệu', 'III'),
    table(
      ['Lớp', 'Cơ chế', 'Bắt được gì'],
      [
        ['Lớp 1', 'Ràng buộc CHECK và khoá ngoại', 'Dữ liệu sai mảnh, dữ liệu mồ côi. Nhanh nhất, không thể vô hiệu hoá'],
        ['Lớp 2', 'Sáu trigger', 'Những luật mà ràng buộc không diễn tả nổi, và ghi nhật ký kiểm toán'],
        ['Lớp 3', 'Hệ thống quyền GRANT / DENY', 'Ngăn người dùng chạm thẳng vào bảng, buộc đi qua thủ tục'],
      ], [10, 30, 60]),
    p('**Sáu trigger được cài ở cả ba site:**'),
    tabCap('Danh sách trigger bảo vệ', 'III'),
    table(
      ['Trigger', 'Bảo vệ bảng', 'Nhiệm vụ'],
      [
        ['trg_TonKho_BaoVeManh', 'TonKho', 'Chặn ghi dữ liệu của site khác, cấm sửa MaKho để đẩy dòng sang mảnh khác, đồng thời ghi nhật ký mọi thay đổi tồn kho'],
        ['trg_ChiTietNhap_BaoVeManhDanXuat', 'ChiTietNhap', 'Giữ bất biến của phép nửa nối: mọi dòng chi tiết phải thuộc một phiếu của chính site này'],
        ['trg_ChiTietXuat_BaoVeManhDanXuat', 'ChiTietXuat', 'Tương tự cho phiếu xuất'],
        ['trg_VatTu_ChiSuaTaiTrungTam', 'VatTu', 'Bản sao nhân bản là chỉ đọc — chặn người dùng sửa tay tại KHO_B và KHO_C'],
        ['trg_NhaCungCap_ChiSuaTaiTrungTam', 'NhaCungCap', 'Tương tự cho danh mục nhà cung cấp'],
        ['trg_PhieuNhap_CamXoa', 'PhieuNhap', 'Cấm xoá chứng từ đã hoàn tất — dùng INSTEAD OF DELETE'],
      ], [30, 16, 54]),
    p('**Vì sao cần trigger trong khi đã có ràng buộc CHECK?** Ràng buộc CHECK chỉ nhìn được các cột trong cùng một dòng. Nó không làm được bốn việc sau:'),
    no(1, 'Kiểm tra mảnh **dẫn xuất** — phải nối sang bảng phiếu mới biết dòng chi tiết có đúng mảnh hay không.'),
    no(2, 'Phân biệt "người dùng sửa" với "tiến trình nhân bản đẩy dữ liệu về" — hai việc giống hệt nhau về câu lệnh nhưng khác hẳn về tính hợp lệ. Giải quyết bằng tuỳ chọn **NOT FOR REPLICATION**.'),
    no(3, 'Ghi **nhật ký kiểm toán** ai sửa gì, lúc nào, từ máy nào.'),
    no(4, 'Cấm xoá chứng từ đã hoàn tất — cần **INSTEAD OF DELETE** để chặn trước khi lệnh chạm vào dữ liệu.'),
    ...fig(A + '3.7_KetQua_GiaoTac\\16_BangQuyen.png', 'Bảng tổng hợp quyền đã cấp cho bốn vai trò và danh sách trigger đang hoạt động', 'III'),
    ...fig(A + '3.7_KetQua_GiaoTac\\17_ThuQuyen.png', 'Kết quả thử quyền — ai làm được gì, ai bị chặn', 'III'),
    p('Sáu phép thử đều cho kết quả đúng như thiết kế. Đáng chú ý nhất là phép thử thứ hai: nhân viên kho **đọc được** bảng tồn kho nhưng **không ghi thẳng vào được**, buộc phải đi qua thủ tục — chính là cơ chế chuỗi sở hữu đã trình bày ở Chương II.'),
    ...fig(A + '3.7_KetQua_GiaoTac\\18_ThuTrigger.png', 'Thử trigger tại site KHO_A — cột LỚP CHẶN chỉ rõ hàng phòng thủ nào đã bắt được vi phạm', 'III'),
    p('Cùng một kịch bản này được chạy ở cả ba site và cho kết quả khác nhau đúng như thiết kế. Với phép thử cuối — sửa danh mục vật tư — tại **KHO_A** (Publisher) thì **được phép**, còn tại **KHO_B** và **KHO_C** (Subscriber) thì **bị trigger chặn** bằng lỗi 50000 kèm thông báo *"BẢNG NHÂN BẢN CHỈ ĐỌC"*. Đây là luật mà không một ràng buộc nào của SQL diễn tả nổi.'),
    ...fig(A + '3.7_KetQua_GiaoTac\\18b_ThuTrigger_KhoB.png', 'Cùng kịch bản chạy tại site KHO_B. Bốn dòng đầu giống hệt, riêng dòng thứ năm đổi từ được phép sang bị chặn — bằng chứng cho thấy trigger phân biệt được vai trò Publisher và Subscriber', 'III'),
    p('Cột **LỚP CHẶN** được suy ra từ số hiệu lỗi, cho thấy chính xác hàng phòng thủ nào đã bắt được hành vi sai:'),
    tabCap('Kết quả thử năm hành vi vi phạm', 'III'),
    table(
      ['Hành vi thử', 'Số hiệu lỗi', 'Lớp chặn'],
      [
        ['Ghi tồn kho của site khác', '547', 'Lớp 1 — ràng buộc CHECK'],
        ['Sửa MaKho để đẩy dòng sang mảnh khác', '547', 'Lớp 1 — ràng buộc CHECK'],
        ['Ghi dòng chi tiết nhập mồ côi', '547', 'Lớp 1 — khoá ngoại'],
        ['Xoá chứng từ đã hoàn tất', '50000', '**Lớp 2 — trigger** (chỉ trigger làm được)'],
        ['Sửa danh mục tại bản sao', '50000', '**Lớp 2 — trigger** (chỉ trigger làm được)'],
      ], [40, 16, 44]),
    ...fig(A + '3.7_KetQua_GiaoTac\\19_NhatKyKiemToan.png', 'Nhật ký kiểm toán do trigger ghi lại', 'III'),
    p('Nhật ký ghi lại cả những hành vi **bị từ chối**, kèm tên tài khoản và tên máy trạm đã thực hiện.'),
    p('**Một chi tiết kỹ thuật nhóm phát hiện trong quá trình kiểm thử:** ban đầu trigger ghi nhật ký rồi mới phát lỗi. Chạy thử thấy bảng nhật ký nhảy số thứ tự từ 1 sang 2 mà không có dòng nào — nguyên nhân là lệnh quay lui của trigger **cuốn theo cả dòng nhật ký vừa ghi**, chỉ số IDENTITY thì đã bị tiêu tốn. Nhóm đã chuyển việc ghi nhật ký sang phía gọi, trong khối bắt lỗi, nhờ đó dòng nhật ký mới tồn tại được.'),

    h3('7.5. Thử các giao tác'),

    p('**a) Giao tác phân tán — kịch bản bắt buộc của đề tài**'),
    p('Bối cảnh nghiệp vụ được dựng đúng theo yêu cầu đề bài: Kho Miền Bắc báo thiếu mặt hàng **VT009 — Bóng đèn LED 9W**, tồn chỉ còn 150 trong khi mức tối thiểu là 200, thiếu đúng 50 đơn vị. Kho Trung tâm điều chuyển sang 50 đơn vị.'),
    p('Thủ tục `sp_DieuChuyenVatTu` thực hiện bốn việc trong **một giao tác phân tán duy nhất**:'),
    no(1, 'Trừ tồn kho tại kho nguồn, có đặt khoá để chống tương tranh.'),
    no(2, 'Cộng tồn kho tại kho đích thông qua Linked Server.'),
    no(3, 'Ghi phiếu điều chuyển tại kho nguồn.'),
    no(4, 'Ghi phiếu điều chuyển tại kho đích.'),
    p('Bốn việc này nằm trên **hai máy chủ khác nhau**, nên bắt buộc phải dùng `BEGIN DISTRIBUTED TRANSACTION` với MS DTC làm bộ điều phối.'),

    p('**Kịch bản T1 — điều chuyển thành công**'),
    ...fig(A + '3.7_KetQua_GiaoTac\\01_T1_DieuChuyen_ThanhCong.png', 'Kịch bản T1 — tồn kho trước và sau khi điều chuyển, phiếu được ghi ở cả hai site', 'III'),
    ...fig(A + '3.7_KetQua_GiaoTac\\01b_T1_Messages_ThanhCong.png', 'Thông báo của kịch bản T1', 'III'),
    tabCap('Kết quả kịch bản T1', 'III'),
    table(
      ['Thời điểm', 'Tồn tại KHO_A', 'Tồn tại KHO_B', 'Phiếu điều chuyển'],
      [
        ['Trước', '800', '150', 'chưa có'],
        ['Sau', '**750**', '**200**', 'Ghi ở **cả hai site**, trạng thái HOAN_TAT'],
      ], [16, 20, 20, 44]),
    p('Tổng số lượng vật tư VT009 toàn hệ thống trước và sau đều bằng **1370** — không mất, không sinh thêm hàng.'),

    p('**Kịch bản T2 — không đủ hàng, bị từ chối trước khi thay đổi gì**'),
    ...fig(A + '3.7_KetQua_GiaoTac\\02_T2_KhongDuHang_TuChoi.png', 'Kịch bản T2 — tồn kho hai site trước và sau đều y nguyên', 'III'),
    ...fig(A + '3.7_KetQua_GiaoTac\\02b_T2_Messages_TuChoi.png', 'Thông báo từ chối của kịch bản T2', 'III'),
    p('Thủ tục kiểm tra tồn **trước khi** thực hiện bất cứ thay đổi nào, phát hiện không đủ hàng nên từ chối ngay. Tồn kho ở cả hai site giữ nguyên 570 và 250.'),

    p('**Kịch bản T3 — lỗi xảy ra giữa chừng, sau khi đã trừ kho nguồn**'),
    p('Đây là kịch bản **quan trọng nhất** của cả đồ án, trả lời trực tiếp yêu cầu *"nếu giao dịch thất bại giữa chừng thì dữ liệu phải được xử lý nhất quán"*.'),
    p('Nhóm cố tình gây lỗi mô phỏng mất kết nối **sau khi kho nguồn đã bị trừ hàng**. Nếu hệ thống không có cơ chế bảo vệ, kết quả sẽ là: kho nguồn mất 50 đơn vị, kho đích không nhận được gì — hàng **biến mất khỏi hệ thống**.'),
    ...fig(A + '3.7_KetQua_GiaoTac\\03_T3_LoiGiuaChung_Rollback.png', 'Kịch bản T3 — tồn kho và số phiếu ở cả hai site đều y nguyên sau khi giao tác bị huỷ', 'III'),
    ...fig(A + '3.7_KetQua_GiaoTac\\03b_T3_Messages_Rollback.png', 'Thông báo quay lui của kịch bản T3', 'III'),
    p('Kết quả thực tế: MS DTC phát hiện một site không hoàn thành được, ra lệnh **quay lui toàn bộ ở cả hai máy chủ**. Tồn kho trở về đúng giá trị ban đầu, số phiếu điều chuyển không đổi. **Không một đơn vị hàng nào bị mất.**'),
    tabCap('Tổng kết ba kịch bản giao tác phân tán', 'III'),
    table(
      ['Kịch bản', 'Tình huống', 'Kết quả', 'Trạng thái dữ liệu'],
      [
        ['T1', 'Đủ hàng, mọi bước thành công', 'Commit ở cả hai site', 'KHO_A 800→750, KHO_B 150→200, phiếu ghi ở cả hai nơi'],
        ['T2', 'Không đủ hàng ở kho nguồn', 'Từ chối trước khi thay đổi gì', 'Cả hai site y nguyên 570 và 250'],
        ['T3', 'Lỗi giữa chừng, **sau khi đã trừ kho nguồn**', 'Quay lui toàn bộ ở cả hai site', 'Tồn kho và số phiếu **y nguyên** — không mất hàng'],
      ], [10, 30, 24, 36]),

    p('**b) Tình huống tương tranh**'),
    p('Nhóm dựng bốn kịch bản, mỗi kịch bản chạy bằng **hai phiên làm việc song song** để mô phỏng hai nhân viên thao tác cùng lúc trên cùng một mặt hàng.'),

    ...fig(A + '3.7_KetQua_GiaoTac\\04_C1_LostUpdate.png', 'Kịch bản C1 — hiện tượng mất cập nhật khi không dùng khoá', 'III'),
    p('Hai phiên cùng xuất 100 đơn vị từ tồn 250, kết quả đúng phải là 50. Nhưng cả hai cùng đọc được 250, cùng tính 250 − 100 = 150 rồi cùng ghi đè. Lần ghi sau xoá sạch lần ghi trước. **Tồn cuối cùng là 150, mất đúng 100 đơn vị** — và nguy hiểm ở chỗ hệ thống hoàn toàn không hay biết.'),

    ...fig(A + '3.7_KetQua_GiaoTac\\05_C2_KhoaBiQuan.png', 'Kịch bản C2 — khoá bi quan khắc phục triệt để', 'III'),
    p('Chỉ thêm gợi ý `WITH (UPDLOCK, HOLDLOCK)` vào câu đọc, phiên thứ hai bị chặn lại và **phải chờ 13 giây** cho tới khi phiên thứ nhất kết thúc. Sau đó nó đọc được số mới nhất là 150 và ghi ra kết quả đúng **50**.'),

    ...fig(A + '3.7_KetQua_GiaoTac\\06_C3_KhoaLacQuan_RowVersion.png', 'Kịch bản C3 — khoá lạc quan bằng cột ROWVERSION', 'III'),
    p('Cách thứ hai không khoá gì cả, nhưng lúc ghi thì kiểm tra cột phiên bản. Phiên thứ hai ghi thành công và làm đổi giá trị cột này. Phiên thứ nhất khi ghi phát hiện phiên bản đã khác, `@@ROWCOUNT` trả về 0, nên **từ chối ghi và báo lỗi xung đột** thay vì ghi đè âm thầm.'),

    ...fig(A + '3.7_KetQua_GiaoTac\\07_C4_Deadlock_1205.png', 'Kịch bản C4 — khoá chết và cơ chế tự gỡ của SQL Server', 'III'),
    p('Hai giao tác khoá hai mặt hàng theo **thứ tự ngược nhau**, mỗi bên giữ thứ bên kia cần nên chờ nhau vĩnh viễn. Bộ giám sát khoá của SQL Server phát hiện vòng tròn chờ, **chọn một giao tác làm nạn nhân** và huỷ nó bằng lỗi **Msg 1205**. Giao tác còn lại chạy tiếp bình thường.'),
    p('Kiểm chứng sau đó cho thấy tổng số lượng hai mặt hàng vẫn đúng bằng 500 — **cơ sở dữ liệu vẫn nhất quán, không cần con người can thiệp**.'),

    ...fig(A + '3.7_KetQua_GiaoTac\\08_QuanSat_Khoa_Blocking.png', 'Quan sát các khoá đang tồn tại trong hệ thống', 'III'),

    tabCap('Tổng kết bốn kịch bản tương tranh', 'III'),
    table(
      ['Mã', 'Kịch bản', 'Kết quả', 'Ý nghĩa'],
      [
        ['C1', 'Không dùng khoá', 'Tồn 150 — **SAI**', 'Mất cập nhật, hệ thống không hề hay biết'],
        ['C2', 'UPDLOCK + HOLDLOCK', 'Tồn 50 — **ĐÚNG**', 'Kết quả chính xác, phiên sau phải chờ 13 giây'],
        ['C3', 'ROWVERSION', 'Tồn 150 — **ĐÚNG**', 'Phát hiện xung đột và báo lỗi cho phiên thua'],
        ['C4', 'Deadlock hai chiều', 'Tổng 500 — **ĐÚNG**', 'SQL Server tự gỡ bằng Msg 1205'],
      ], [6, 26, 22, 46]),
    p('**Lựa chọn của nhóm:** dùng **khoá bi quan** cho các thao tác trong cùng một site, vì thao tác kho rất ngắn, tranh chấp ít, và khoá bi quan cho kết quả đúng tuyệt đối mà không bắt người dùng nhập lại phiếu. Cột phiên bản vẫn được giữ trong bảng tồn kho để dành cho tầng ứng dụng web sau này, nơi một màn hình có thể mở hàng phút trước khi bấm Lưu — lúc đó khoá bi quan sẽ chặn cả hệ thống quá lâu.'),
  ];
}

function chuongIV() {
  return [
    h1('CHƯƠNG IV. KẾT LUẬN'),

    h2('1. Kết quả đạt được'),
    p('Nhóm đã xây dựng hoàn chỉnh và **chạy kiểm thử thực tế** một hệ cơ sở dữ liệu phân tán quản lý kho vật tư trên ba site độc lập. Toàn bộ các yêu cầu của đề tài đều được đáp ứng và có minh chứng bằng ảnh chụp kết quả chạy thật.'),
    tabCap('Đối chiếu yêu cầu đề tài với kết quả', 'IV'),
    table(
      ['Yêu cầu', 'Cách đáp ứng', 'Kết quả kiểm chứng'],
      [
        ['Có từ 2 đến 4 site', 'Ba thể hiện SQL Server độc lập', 'Ba dịch vụ riêng, ba Agent riêng, ba cổng riêng'],
        ['Ít nhất một phép phân mảnh', 'Phân mảnh ngang **nguyên thủy** và **dẫn xuất**', '10 + 7 + 7 = 24 dòng; 0 dòng trùng giữa các mảnh'],
        ['Ít nhất một nhân bản', 'Transactional Replication ba bảng danh mục', 'Ba site cùng vân tay 347490305'],
        ['Ít nhất một giao tác phân tán', 'sp_DieuChuyenVatTu qua MS DTC', 'T1 thành công, T2 và T3 quay lui sạch'],
        ['Ít nhất một tình huống tương tranh', 'Bốn kịch bản C1 đến C4', 'Tái hiện mất cập nhật và khắc phục bằng hai cách'],
        ['Ít nhất một truy vấn phân tán', 'Khung nhìn gộp ba site và thủ tục động', '24 dòng gộp từ ba máy chủ'],
        ['Đồng bộ dữ liệu', 'Nhân bản danh mục và giao tác phân tán', 'Độ trễ đo được 15–20 giây'],
        ['Nhập tại Kho A, xuất tại Kho B', 'sp_NhapKho và sp_XuatKho', 'Chạy thật trên cả ba site'],
        ['Kiểm tra tồn toàn hệ thống', 'v_TonKho_ToanHeThong', 'Tổng 26.204 đơn vị, giá trị 539.700.000 đồng'],
        ['Điều chuyển giữa hai kho', 'sp_DieuChuyenVatTu', 'KHO_A 800→750, KHO_B 150→200'],
        ['**Thất bại giữa chừng phải nhất quán**', 'Giao thức hai pha, quay lui toàn bộ', '**Tồn kho và số phiếu ở cả hai site y nguyên**'],
      ], [26, 32, 42]),

    h2('2. Những vấn đề đã gặp và cách khắc phục'),
    p('Quá trình triển khai gặp một số vấn đề thực tế mà tài liệu lý thuyết không nêu. Nhóm ghi lại đây vì đó là phần học được nhiều nhất.'),
    tabCap('Các sự cố đã xử lý', 'IV'),
    table(
      ['Sự cố', 'Nguyên nhân', 'Cách khắc phục'],
      [
        ['Msg 7411 — not configured for DATA ACCESS', 'sp_addsubscription ghi đè mục Linked Server và tắt tuỳ chọn data access', 'Bổ sung bước bật lại các tuỳ chọn sau khi cấu hình nhân bản'],
        ['Distribution Agent không kết nối được Subscriber', 'Agent chạy dưới tài khoản dịch vụ không có quyền ở site kia', 'Đặt subscriber_security_mode = 0 và chỉ định tài khoản SQL'],
        ['Xung đột khoá ngoại khi tạo snapshot', 'Snapshot cố tạo lại bảng đã có dữ liệu ở Subscriber', 'Dùng sync_type = replication support only'],
        ['Nhật ký kiểm toán bị mất khi trigger từ chối', 'Lệnh quay lui của trigger cuốn theo cả dòng nhật ký vừa ghi', 'Chuyển việc ghi nhật ký sang phía gọi, trong khối bắt lỗi'],
        ['Mất dấu tiếng Việt trong câu lệnh động', 'Thiếu tiền tố N nên chuỗi bị hiểu là VARCHAR', 'Thêm tiền tố N vào chuỗi khi dựng câu lệnh'],
        ['Tuỳ chọn nâng lên giao tác phân tán bị tắt', 'Cũng do sp_addsubscription ghi đè cấu hình liên kết', 'Bật lại remote proc transaction promotion trên cả sáu liên kết'],
      ], [26, 34, 40]),

    h2('3. Đánh giá'),
    p('**Ưu điểm của hệ thống:**'),
    li('89% nghiệp vụ hằng ngày chạy **hoàn toàn tại chỗ**, không phụ thuộc đường truyền.'),
    li('Định nghĩa mảnh được cưỡng chế ngay tại tầng cơ sở dữ liệu, **không thể ghi sai mảnh** kể cả với quyền quản trị cao nhất.'),
    li('Giao tác điều chuyển bảo đảm nguyên tố tuyệt đối, đã kiểm chứng bằng kịch bản gây lỗi cố ý.'),
    li('Mã nguồn của các thủ tục **giống hệt nhau ở cả ba site**, giảm chi phí bảo trì.'),
    li('Ba lớp bảo vệ chồng nhau, mỗi lớp bắt được loại vi phạm mà lớp kia không thấy.'),
    p('**Hạn chế còn tồn tại:**'),
    li('Nhân bản danh mục là **một chiều**, nên khi Kho Trung tâm gặp sự cố thì không site nào sửa được danh mục.'),
    li('Distributor đặt chung máy với Publisher, chưa tách riêng như hệ thống thật.'),
    li('Chưa có cơ chế tự động thử lại giao tác khi gặp deadlock — hiện tại việc này để cho tầng ứng dụng.'),
    li('Chưa xây dựng phần mềm ứng dụng cho các trạm; hiện thao tác qua công cụ quản trị.'),

    h2('4. Hướng phát triển'),
    no(1, 'Xây dựng phần mềm ứng dụng cho máy trạm theo đúng mô hình front-end đã thiết kế, dùng cột phiên bản để điều khiển tương tranh lạc quan.'),
    no(2, 'Tách Distributor ra máy riêng để giảm tải cho Publisher.'),
    no(3, 'Bổ sung cơ chế tự động thử lại khi gặp lỗi 1205.'),
    no(4, 'Mở rộng sang mô hình nhiều kho hơn — thiết kế hiện tại đã sẵn sàng, vì thêm kho mới chỉ cần thêm một dòng vào bảng Kho.'),
    no(5, 'Bổ sung sao lưu và phục hồi theo lịch cho từng site.'),
  ];
}

module.exports = { chuongIII, chuongIV };
