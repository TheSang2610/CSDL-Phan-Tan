<#
================================================================================
 TIỆN ÍCH GỠ SẠCH SQL SERVER ĐỂ CÀI LẠI TOÀN BỘ SANG Ổ D
 Đồ án cuối kỳ - CSDL phân tán - Quản lý kho vật tư đa chi nhánh
================================================================================

 MỤC ĐÍCH
   Gỡ toàn bộ thành phần SQL Server 2019 còn sót + SSMS + LocalDB 2025, xóa
   thư mục và khóa registry đang GIỮ KHÓA đường dẫn "Shared feature directory"
   ở ổ C. Sau khi chạy xong, bộ cài SQL Server 2022 sẽ CHO PHÉP đổi đường dẫn
   shared sang ổ D.

 CÁCH DÙNG
   1) Mở PowerShell với quyền ADMINISTRATOR
      (chuột phải nút Start -> Terminal (Admin))

   2) Xem trước, KHÔNG xóa gì:
        cd "D:\CSDL PHAN TAN\Do an cuoi ki"
        .\TienIch_GoSachSQLServer.ps1

   3) Thực hiện gỡ thật:
        .\TienIch_GoSachSQLServer.ps1 -Xoa

   Nếu báo lỗi không chạy được script:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

 LƯU Ý QUAN TRỌNG
   * SSMS 19 SẼ BỊ GỠ. Cài lại sau, nhớ bấm "Change install location" -> D:\SSMS
   * GIỮ LẠI: ODBC Driver 17, OLE DB Driver, Command Line Utilities (sqlcmd),
     Native Client 2012 - các phần mềm khác trên máy có thể đang dùng, và
     chúng KHÔNG giữ khóa đường dẫn shared.
   * Registry được sao lưu ra D:\SQL_Backup trước khi xóa.
   * Ba database cũ đã sao lưu sẵn ở D:\SQL_Backup\*.bak
================================================================================
#>

[CmdletBinding()]
param(
    [switch]$Xoa,                               # Không có switch này = chỉ xem trước
    [string]$ThuMucBackup = 'D:\SQL_Backup'
)

$ErrorActionPreference = 'Continue'

function Ghi($mau, $text) { Write-Host $text -ForegroundColor $mau }
function Tieude($text) {
    Write-Host ''
    Ghi Cyan ('=' * 78)
    Ghi Cyan "  $text"
    Ghi Cyan ('=' * 78)
}

# ------------------------------------------------------------------ kiểm tra
$laAdmin = ([Security.Principal.WindowsPrincipal] `
            [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Tieude 'KIEM TRA MOI TRUONG'
if ($laAdmin) { Ghi Green '  [OK]  Dang chay voi quyen Administrator' }
else {
    Ghi Red '  [LOI] CHUA co quyen Administrator.'
    Ghi Yellow '        Dong cua so nay, mo lai bang: chuot phai Start -> Terminal (Admin)'
    return
}

if ($Xoa) { Ghi Yellow '  [!!]  CHE DO XOA THAT - se go va xoa du lieu' }
else      { Ghi Green  '  [OK]  Che do XEM TRUOC - khong xoa gi ca (them -Xoa de go that)' }

# ---------------------------------------------- danh sách gỡ, đúng thứ tự phụ thuộc
$danhSachGo = @(
    @{ Ten = 'SSMS Language Pack - English';                Guid = '{64A020B1-26F4-4B68-A4E8-6622BA034D0E}' }
    @{ Ten = 'SQL Server Management Studio 19.2';           Guid = '{0fa2021d-5bc7-44f9-ab33-4a60fa6b77ad}' }
    @{ Ten = 'SQL Server Management Studio (base)';         Guid = '{D74DBD2E-1A0A-4D12-97AB-BFB4B9E6BF5F}' }
    @{ Ten = 'SQL Server 2025 LocalDB';                     Guid = '{E9279A3D-A613-4CA7-8B09-A6C4C5C5AB5A}' }
    @{ Ten = 'SQL Server 2019 T-SQL Language Service';      Guid = '{31D27B41-A051-49D8-907A-62E0F4A2188C}' }
    @{ Ten = 'System CLR Types for SQL Server 2019';        Guid = '{5BC7E9EB-13E8-45DB-8A60-F2481FEB4595}' }
    @{ Ten = 'SQL Server 2019 SMO Extensions';              Guid = '{8DDAEBCA-4267-4E16-9FE0-D87F21D36891}' }
    @{ Ten = 'SQL Server 2019 Shared Management Objects';   Guid = '{6213D6CB-D258-47A3-B1A0-EE1E5C080DCF}' }
    @{ Ten = 'SQL Server 2019 DMF';                         Guid = '{814D5077-C93F-42E2-B875-717007C186B9}' }
    @{ Ten = 'SQL Server 2019 Connection Info';             Guid = '{FD730873-33D1-4D1F-9AE0-E259586F8827}' }
    @{ Ten = 'SQL Server 2019 Batch Parser';                Guid = '{D459615B-83B0-408F-8F39-6CC07C277BA6}' }
    @{ Ten = 'SQL Server 2019 SQL Diagnostics';             Guid = '{28ED6838-D8E5-454C-A813-12C5EB447CAB}' }
    @{ Ten = 'SQL Server 2019 XEvent';                      Guid = '{2129312E-5204-4F3A-9039-B6D34DBB00FB}' }
    @{ Ten = 'SQL Server 2019 Database Engine Shared';      Guid = '{DE5B7937-D5B5-4157-BC30-BB87F021CFF0}' }
    @{ Ten = 'SQL Server 2019 Common Files';                Guid = '{0FB552DD-543E-48E7-A6F4-2F8D82723C6A}' }
    @{ Ten = 'SQL Server 2019 Setup (English)';             Guid = '{17DCED0E-5B27-453A-B2B4-E487B869B28A}' }
)

function CoCaiDat($guid) {
    $p = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
           'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
    foreach ($r in $p) { if (Test-Path (Join-Path $r $guid)) { return $true } }
    return $false
}

Tieude 'BUOC 1/4  -  GO CAC THANH PHAN (theo thu tu phu thuoc)'

# --- SSMS 19 phai go RIENG: no dung bo cai Burn bootstrapper, KHONG phai MSI
#     thuong, nen "msiexec /x" vo tac dung. Phai go SSMS TRUOC thi 5 thu vien
#     dung chung ben duoi moi chiu nha ra.
$ssmsExe = 'C:\ProgramData\Package Cache\{0fa2021d-5bc7-44f9-ab33-4a60fa6b77ad}\SSMS-Setup-ENU.exe'
if (Test-Path $ssmsExe) {
    if ($Xoa) {
        Write-Host '  [dang go] SQL Server Management Studio 19.2 (bootstrapper) ...' -NoNewline
        $p = Start-Process $ssmsExe -ArgumentList '/uninstall /quiet /norestart' -Wait -PassThru
        if ($p.ExitCode -in 0, 3010) { Ghi Green ' OK' }
        else { Ghi Red (' LOI, ma {0}' -f $p.ExitCode) }
    } else {
        Ghi Yellow '  [se go ] SQL Server Management Studio 19.2 (qua bootstrapper rieng)'
    }
} else {
    Ghi DarkGray '  [bo qua] SSMS bootstrapper - khong tim thay'
}

$soGo = 0; $soBo = 0
foreach ($m in $danhSachGo) {
    if (-not (CoCaiDat $m.Guid)) {
        Ghi DarkGray ('  [bo qua] {0}  - khong co tren may' -f $m.Ten)
        $soBo++
        continue
    }
    if (-not $Xoa) {
        Ghi Yellow ('  [se go ] {0}' -f $m.Ten)
        $soGo++
        continue
    }
    Write-Host ('  [dang go] {0} ...' -f $m.Ten) -NoNewline
    $p = Start-Process msiexec.exe -ArgumentList "/x $($m.Guid) /quiet /norestart" -Wait -PassThru
    switch ($p.ExitCode) {
        0     { Ghi Green  ' OK' }
        3010  { Ghi Green  ' OK (can khoi dong lai may)' }
        1605  { Ghi DarkGray ' da go tu truoc' }
        default { Ghi Red (' LOI, ma {0}' -f $p.ExitCode) }
    }
    $soGo++
}
Ghi White ('  --> {0} muc se go / da go, {1} muc khong co tren may' -f $soGo, $soBo)

# ------------------------------------------------------------------ registry
Tieude 'BUOC 2/4  -  SAO LUU VA XOA KHOA REGISTRY GIU DUONG DAN SHARED'
$khoaRegistry = @(
    'HKLM\SOFTWARE\Microsoft\Microsoft SQL Server',
    'HKLM\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server'
)

if ($Xoa) {
    if (-not (Test-Path $ThuMucBackup)) { New-Item -ItemType Directory -Path $ThuMucBackup -Force | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $i = 0
    foreach ($k in $khoaRegistry) {
        $i++
        $file = Join-Path $ThuMucBackup ("registry_sqlserver_{0}_{1}.reg" -f $i, $stamp)
        & reg.exe export $k $file /y | Out-Null
        if (Test-Path $file) { Ghi Green ('  [sao luu] {0}' -f $file) }
        else                 { Ghi DarkGray ('  [bo qua ] khoa khong ton tai: {0}' -f $k) }
    }
    foreach ($k in $khoaRegistry) {
        & reg.exe delete $k /f 2>&1 | Out-Null
        Ghi Green ('  [da xoa ] {0}' -f $k)
    }
} else {
    foreach ($k in $khoaRegistry) { Ghi Yellow ('  [se sao luu roi xoa] {0}' -f $k) }
    Ghi DarkGray ('  Ban sao luu se nam o: {0}\registry_sqlserver_*.reg' -f $ThuMucBackup)
}

# ------------------------------------------------------------------- thư mục
Tieude 'BUOC 3/4  -  XOA THU MUC CON SOT TREN O C'
$thuMuc = @(
    'C:\Program Files\Microsoft SQL Server',
    'C:\Program Files (x86)\Microsoft SQL Server'
)
foreach ($t in $thuMuc) {
    if (-not (Test-Path $t)) { Ghi DarkGray ('  [bo qua] khong co: {0}' -f $t); continue }
    $mb = [math]::Round((Get-ChildItem $t -Recurse -Force -File -ErrorAction SilentlyContinue |
                         Measure-Object Length -Sum).Sum / 1MB, 0)
    if ($Xoa) {
        Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $t) { Ghi Yellow ('  [con sot] {0}  (~{1} MB) - xoa tay sau khi khoi dong lai' -f $t, $mb) }
        else              { Ghi Green  ('  [da xoa ] {0}  (~{1} MB)' -f $t, $mb) }
    } else {
        Ghi Yellow ('  [se xoa ] {0}  (~{1} MB)' -f $t, $mb)
    }
}

# ------------------------------------------------------------------- kết quả
Tieude 'BUOC 4/4  -  KIEM TRA LAI'
$conLai = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue |
          ForEach-Object { Get-ItemProperty $_.PSPath } |
          Where-Object { $_.DisplayName -match 'SQL Server|Management Studio' } |
          Select-Object -ExpandProperty DisplayName | Sort-Object

if ($conLai) {
    Ghi White '  Cac muc lien quan SQL con lai tren may:'
    $conLai | ForEach-Object {
        if ($_ -match 'ODBC|OLE DB|Native Client|Command Line') { Ghi DarkGray ('    (giu lai co y) {0}' -f $_) }
        else                                                    { Ghi Yellow   ('    {0}' -f $_) }
    }
} else {
    Ghi Green '  Khong con muc SQL Server nao.'
}

Write-Host ''
if ($Xoa) {
    Ghi Cyan '  VIEC TIEP THEO'
    Ghi White '    1. KHOI DONG LAI MAY (bat buoc - de Windows nha cac file dang khoa)'
    Ghi White '    2. Chay D:\SQL2022Media\setup.exe'
    Ghi White '    3. O trang Feature Selection, DOI CA BA duong dan sang o D:'
    Ghi White '         Shared feature directory       -> D:\Program Files\Microsoft SQL Server\'
    Ghi White '         Shared feature directory (x86) -> D:\Program Files (x86)\Microsoft SQL Server\'
    Ghi White '         Instance root directory        -> D:\SQLServer\KhoA'
    Ghi White '       (Lan cai DAU TIEN moi doi duoc 2 dong dau - sau do bi khoa lai)'
    Ghi White '    4. Cai lai SSMS, nho bam "Change install location" -> D:\SSMS'
} else {
    Ghi Cyan '  Day moi la XEM TRUOC. Chay lai voi -Xoa de thuc hien that:'
    Ghi White '    .\TienIch_GoSachSQLServer.ps1 -Xoa'
}
Write-Host ''
