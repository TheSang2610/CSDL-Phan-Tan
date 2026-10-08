# =============================================================================
#  BAT MS DTC CHO GIAO TAC PHAN TAN QUA MANG
#  Do an CSDL phan tan - Quan ly kho vat tu da chi nhanh - Nhom 2
# -----------------------------------------------------------------------------
#  CHAY O CA BA MAY (Kho A, Kho B, Kho C), BANG QUYEN ADMINISTRATOR.
#
#  Vi sao can: MS DTC la trong tai hai pha cua giao tac phan tan. Mac dinh
#  Windows TAT hoan toan giao tac qua mang, nen cau lenh
#  BEGIN DISTRIBUTED TRANSACTION se bao:
#      "The transaction manager has disabled its support for
#       remote/network transactions."
#  Khi ba site nam chung mot may thi khong gap loi nay, vi chung dung chung
#  mot DTC noi bo. Loi chi lo ra khi chay that tren ba may.
# =============================================================================

$ErrorActionPreference = 'Stop'

function Tieude($chu) {
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Cyan
    Write-Host "  $chu" -ForegroundColor Cyan
    Write-Host "==============================================================" -ForegroundColor Cyan
}

# --- Kiem tra quyen administrator -------------------------------------------
$laAdmin = ([Security.Principal.WindowsPrincipal] `
            [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $laAdmin) {
    Write-Host ""
    Write-Host "  CHUA CO QUYEN ADMINISTRATOR." -ForegroundColor Red
    Write-Host "  Bam chuot phai vao file nay -> Run with PowerShell (as administrator)," -ForegroundColor Yellow
    Write-Host "  hoac mo PowerShell bang Run as administrator roi chay lai." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

Tieude "BUOC 1 - BAT DICH VU MS DTC"

$dtc = Get-Service MSDTC
if ($dtc.Status -ne 'Running') { Start-Service MSDTC }
Set-Service MSDTC -StartupType Automatic
Write-Host "  Dich vu MSDTC: $((Get-Service MSDTC).Status)" -ForegroundColor Green

Tieude "BUOC 2 - MO QUYEN GIAO TAC QUA MANG"

# LUU Y VE BAO MAT
#   Dat 'No Authentication Required' (NoAuth) la lua chon CUA PHONG THUC HANH.
#   Ba may khong cung domain nen khong dung duoc Mutual Authentication.
#   Moi truong that phai de Mutual Authentication va dua may vao domain.
# PHAI dung cmdlet Set-DtcNetworkSetting, KHONG ghi thang registry.
# MS DTC khong doc muc xac thuc tu registry: ghi tay vao
# HKLM\SOFTWARE\Microsoft\MSDTC\Security van de AuthenticationLevel = Mutual,
# va giao tac se that bai voi thong bao kho hieu "No transaction is active."
#
# AuthenticationLevel = NoAuth la lua chon CUA PHONG THUC HANH, vi ba may
# khong cung domain nen khong the xac thuc lan nhau (Mutual).
# Moi truong that phai dua may vao domain va giu Mutual.
Set-DtcNetworkSetting -DtcName Local `
    -AuthenticationLevel NoAuth `
    -InboundTransactionsEnabled  $true `
    -OutboundTransactionsEnabled $true `
    -RemoteClientAccessEnabled   $true `
    -RemoteAdministrationAccessEnabled $false `
    -Confirm:$false

Write-Host "  AuthenticationLevel         = NoAuth"  -ForegroundColor Green
Write-Host "  InboundTransactionsEnabled  = True"    -ForegroundColor Green
Write-Host "  OutboundTransactionsEnabled = True"    -ForegroundColor Green
Write-Host "  RemoteClientAccessEnabled   = True"    -ForegroundColor Green

Tieude "BUOC 3 - MO TUONG LUA CHO MS DTC"

$luat = Get-NetFirewallRule -DisplayGroup 'Distributed Transaction Coordinator' -ErrorAction SilentlyContinue
if ($luat) {
    $luat | Enable-NetFirewallRule
    Write-Host "  Da bat nhom luat 'Distributed Transaction Coordinator'" -ForegroundColor Green
} else {
    New-NetFirewallRule -DisplayName 'MSDTC (do an CSDLPT)' -Direction Inbound `
        -Program '%SystemRoot%\System32\msdtc.exe' -Action Allow -Profile Any | Out-Null
    Write-Host "  Da tao luat tuong lua rieng cho msdtc.exe" -ForegroundColor Green
}

# RPC Endpoint Mapper - DTC thuong luong cong qua cong 135
if (-not (Get-NetFirewallRule -DisplayName 'RPC EPMap 135 (do an CSDLPT)' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName 'RPC EPMap 135 (do an CSDLPT)' -Direction Inbound `
        -Protocol TCP -LocalPort 135 -Action Allow -Profile Any | Out-Null
    Write-Host "  Da mo cong TCP 135 (RPC Endpoint Mapper)" -ForegroundColor Green
}

Tieude "BUOC 4 - KHOI DONG LAI MS DTC DE AP DUNG"

Restart-Service MSDTC -Force
Start-Sleep -Seconds 3
Write-Host "  Dich vu MSDTC: $((Get-Service MSDTC).Status)" -ForegroundColor Green

Tieude "KIEM TRA LAI CAU HINH"

Get-DtcNetworkSetting -DtcName Local |
    Select-Object AuthenticationLevel, InboundTransactionsEnabled,
                  OutboundTransactionsEnabled, RemoteClientAccessEnabled |
    Format-List

Write-Host "  Phai thay dung bon dong nay:"                     -ForegroundColor Yellow
Write-Host "      AuthenticationLevel         : NoAuth"         -ForegroundColor Yellow
Write-Host "      InboundTransactionsEnabled  : True"           -ForegroundColor Yellow
Write-Host "      OutboundTransactionsEnabled : True"           -ForegroundColor Yellow
Write-Host "      RemoteClientAccessEnabled   : True"           -ForegroundColor Yellow
Write-Host ""
Write-Host "  Con thay AuthenticationLevel : Mutual la CHUA AN." -ForegroundColor Red
Write-Host ""
Write-Host "  XONG. May nay da san sang cho giao tac phan tan." -ForegroundColor Green
Write-Host "  Nho chay file nay o CA BA MAY, thieu mot may la hong." -ForegroundColor Yellow
Write-Host ""
pause
