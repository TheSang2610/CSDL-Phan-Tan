# =============================================================================
#  ĐỒ ÁN CSDL PHÂN TÁN - BẬT TCP/IP + GÁN CỔNG CỐ ĐỊNH + MỞ FIREWALL
# -----------------------------------------------------------------------------
#  Mục đích: cho phép máy KHÁC (qua LAN hoặc qua VPN ZeroTier) kết nối được tới
#            ba instance SQL Server trên máy này.
#
#  Hiện tại ba instance chỉ nói chuyện qua Shared Memory - bộ nhớ chung trong
#  cùng một máy, không máy nào bên ngoài với tới được. Script này mở đường TCP.
#
#  ⚠️  PHẢI CHẠY BẰNG QUYỀN ADMINISTRATOR
#      Bấm Start -> gõ  powershell  -> chuột phải "Windows PowerShell"
#      -> chọn "Run as administrator" -> rồi dán lệnh:
#
#      powershell -ExecutionPolicy Bypass -File "D:\CSDL PHAN TAN\Do an cuoi ki\BatTCPIP_VaFirewall.ps1"
#
#  An toàn: KHÔNG đụng tới database, Linked Server hay Replication.
#           Chỉ đổi cách nghe cổng mạng. Đảo ngược được (xem cuối file).
# =============================================================================

$ErrorActionPreference = 'Stop'

# --- Kiểm tra quyền Administrator ---------------------------------------------
$pr = New-Object Security.Principal.WindowsPrincipal(
          [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ""
    Write-Host "  !!! CHUA CO QUYEN ADMINISTRATOR !!!" -ForegroundColor Red
    Write-Host "  Hay dong cua so nay, mo lai PowerShell bang 'Run as administrator'"
    Write-Host ""
    pause
    exit 1
}

# --- Cấu hình: mỗi instance một cổng riêng ------------------------------------
$CauHinh = @(
    @{ Ten = 'KHO_A'; Cong = 1440 },
    @{ Ten = 'KHO_B'; Cong = 1441 },
    @{ Ten = 'KHO_C'; Cong = 1442 }
)

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  BUOC 1 - BAT TCP/IP VA GAN CONG CO DINH" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan

foreach ($c in $CauHinh) {
    $goc   = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.$($c.Ten)\MSSQLServer\SuperSocketNetLib\Tcp"
    $ipall = "$goc\IPAll"

    if (-not (Test-Path $goc)) {
        Write-Host "  [$($c.Ten)] KHONG TIM THAY - bo qua" -ForegroundColor Yellow
        continue
    }

    # Bật giao thức TCP/IP
    Set-ItemProperty -Path $goc -Name 'Enabled'         -Value 1
    # Nghe trên mọi địa chỉ IP (kể cả IP ảo của ZeroTier sau này)
    Set-ItemProperty -Path $goc -Name 'ListenOnAllIPs'  -Value 1

    # Gán cổng CỐ ĐỊNH, xoá cổng động (cổng động đổi mỗi lần khởi động -> không
    # mở firewall được, và máy khác không biết đường nào mà nối)
    Set-ItemProperty -Path $ipall -Name 'TcpPort'          -Value "$($c.Cong)"
    Set-ItemProperty -Path $ipall -Name 'TcpDynamicPorts'  -Value ''

    Write-Host "  [$($c.Ten)] TCP/IP = BAT, cong co dinh = $($c.Cong)" -ForegroundColor Green
}

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  BUOC 2 - MO FIREWALL" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan

# Ba cổng của ba instance
$tenTcp = 'CSDLPT - SQL Server 3 instance (TCP 1440-1442)'
Remove-NetFirewallRule -DisplayName $tenTcp -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName $tenTcp -Direction Inbound -Protocol TCP `
    -LocalPort 1440,1441,1442 -Action Allow -Profile Any | Out-Null
Write-Host "  Da mo TCP 1440, 1441, 1442" -ForegroundColor Green

# SQL Browser - giúp máy khác tìm instance theo TÊN thay vì phải nhớ cổng
$tenUdp = 'CSDLPT - SQL Server Browser (UDP 1434)'
Remove-NetFirewallRule -DisplayName $tenUdp -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName $tenUdp -Direction Inbound -Protocol UDP `
    -LocalPort 1434 -Action Allow -Profile Any | Out-Null
Write-Host "  Da mo UDP 1434 (SQL Browser)" -ForegroundColor Green

# MS DTC - BẮT BUỘC cho giao tác phân tán 2PC khi chay tren nhieu may
$tenDtc = 'CSDLPT - MS DTC (giao tac phan tan)'
Remove-NetFirewallRule -DisplayName $tenDtc -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName $tenDtc -Direction Inbound -Program '%SystemRoot%\System32\msdtc.exe' `
    -Action Allow -Profile Any | Out-Null
Write-Host "  Da mo MS DTC (can cho dieu chuyen giua 2 kho)" -ForegroundColor Green

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  BUOC 3 - KHOI DONG LAI DICH VU (mat khoang 1 phut)" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan

foreach ($c in $CauHinh) {
    $svc   = "MSSQL`$$($c.Ten)"
    $agent = "SQLAgent`$$($c.Ten)"

    if (Get-Service $svc -ErrorAction SilentlyContinue) {
        Restart-Service $svc -Force
        Write-Host "  [$($c.Ten)] SQL Server da khoi dong lai" -ForegroundColor Green

        # Restart SQL Server se lam dung Agent -> phai bat lai, neu khong
        # Replication (Log Reader + Distribution Agent) se khong chay
        if (Get-Service $agent -ErrorAction SilentlyContinue) {
            Start-Service $agent
            Write-Host "  [$($c.Ten)] SQL Agent da bat lai" -ForegroundColor Green
        }
    }
}

# SQL Browser phải chạy thì máy khác mới gọi được theo tên MIGNON\KHO_B
if ((Get-Service SQLBrowser).Status -ne 'Running') { Start-Service SQLBrowser }

# MS DTC phải chạy thì điều chuyển 2PC mới hoạt động
if ((Get-Service MSDTC).Status -ne 'Running') { Start-Service MSDTC }
Set-Service MSDTC -StartupType Automatic

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  BUOC 4 - KIEM TRA KET QUA" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan

Start-Sleep -Seconds 5

Write-Host ""
Write-Host "  Cac cong dang duoc SQL Server lang nghe:" -ForegroundColor White
Get-NetTCPConnection -State Listen -LocalPort 1440,1441,1442 -ErrorAction SilentlyContinue |
    Select-Object LocalAddress, LocalPort |
    Sort-Object LocalPort | Format-Table -AutoSize

Write-Host "  Dia chi IP cua may nay (dua cho ban be dung de ket noi):" -ForegroundColor White
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.IPAddress -notlike '169.254.*' } |
    Select-Object InterfaceAlias, IPAddress | Format-Table -AutoSize

Write-Host "  Trang thai dich vu:" -ForegroundColor White
Get-Service MSSQL`$KHO_A, MSSQL`$KHO_B, MSSQL`$KHO_C,
            SQLAgent`$KHO_A, SQLAgent`$KHO_B, SQLAgent`$KHO_C,
            SQLBrowser, MSDTC -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize

Write-Host ""
Write-Host "  XONG. Bay gio may khac co the ket noi bang:" -ForegroundColor Green
Write-Host "      <IP cua may nay>,1440   -> KHO_A"
Write-Host "      <IP cua may nay>,1441   -> KHO_B"
Write-Host "      <IP cua may nay>,1442   -> KHO_C"
Write-Host ""
Write-Host "  Buoc tiep theo: doc file HUONG_DAN_ZEROTIER_3MAY.md" -ForegroundColor Yellow
Write-Host ""
pause

# =============================================================================
#  MUỐN ĐẢO NGƯỢC (trả về như cũ)?
#  Chạy lại bằng quyền Admin ba lệnh sau cho mỗi instance:
#
#    $g = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.KHO_A\MSSQLServer\SuperSocketNetLib\Tcp"
#    Set-ItemProperty $g -Name Enabled -Value 0
#    Restart-Service MSSQL`$KHO_A -Force
#
#  Và xoá 3 luật firewall:
#    Remove-NetFirewallRule -DisplayName 'CSDLPT - SQL Server 3 instance (TCP 1440-1442)'
#    Remove-NetFirewallRule -DisplayName 'CSDLPT - SQL Server Browser (UDP 1434)'
#    Remove-NetFirewallRule -DisplayName 'CSDLPT - MS DTC (giao tac phan tan)'
# =============================================================================
