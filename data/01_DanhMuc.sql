-- Du lieu MAU MOI, khong trich giao dich/khach hang tu database hien co.
-- Chi chay trong database moi do TrienKhai.ps1 vua tao.
SET NOCOUNT ON; SET XACT_ABORT ON; SET QUOTED_IDENTIFIER ON;
IF EXISTS(SELECT 1 FROM dbo.KhachHang) OR EXISTS(SELECT 1 FROM dbo.NhaMang) THROW 57000,N'Nguon khong trong; dung de bao toan du lieu.',1;
BEGIN TRAN;
INSERT dbo.NhaMang(MaNhaMang,TenNhaMang) VALUES('NM003',N'Viettel'),('NM004',N'VinaPhone'),('NM005',N'MobiFone');
DECLARE @t TABLE(ThuTu int,MaTinh char(2),TenTinh nvarchar(100),Vung nvarchar(30));
INSERT @t VALUES
(1,'01',N'Hà Nội',N'Bắc'),
(2,'02',N'Hà Giang',N'Bắc'),
(3,'04',N'Cao Bằng',N'Bắc'),
(4,'06',N'Bắc Kạn',N'Bắc'),
(5,'08',N'Tuyên Quang',N'Bắc'),
(6,'10',N'Lào Cai',N'Bắc'),
(7,'11',N'Điện Biên',N'Bắc'),
(8,'12',N'Lai Châu',N'Bắc'),
(9,'14',N'Sơn La',N'Bắc'),
(10,'15',N'Yên Bái',N'Bắc'),
(11,'17',N'Hòa Bình',N'Bắc'),
(12,'19',N'Thái Nguyên',N'Bắc'),
(13,'20',N'Lạng Sơn',N'Bắc'),
(14,'22',N'Quảng Ninh',N'Bắc'),
(15,'24',N'Bắc Giang',N'Bắc'),
(16,'25',N'Phú Thọ',N'Bắc'),
(17,'26',N'Vĩnh Phúc',N'Bắc'),
(18,'27',N'Bắc Ninh',N'Bắc'),
(19,'30',N'Hải Dương',N'Bắc'),
(20,'31',N'Hải Phòng',N'Bắc'),
(21,'33',N'Hưng Yên',N'Bắc'),
(22,'34',N'Thái Bình',N'Bắc'),
(23,'35',N'Hà Nam',N'Bắc'),
(24,'36',N'Nam Định',N'Bắc'),
(25,'37',N'Ninh Bình',N'Bắc'),
(26,'38',N'Thanh Hóa',N'Trung'),
(27,'40',N'Nghệ An',N'Trung'),
(28,'42',N'Hà Tĩnh',N'Trung'),
(29,'44',N'Quảng Bình',N'Trung'),
(30,'45',N'Quảng Trị',N'Trung'),
(31,'46',N'Thừa Thiên Huế',N'Trung'),
(32,'48',N'Đà Nẵng',N'Trung'),
(33,'49',N'Quảng Nam',N'Trung'),
(34,'51',N'Quảng Ngãi',N'Trung'),
(35,'52',N'Bình Định',N'Trung'),
(36,'54',N'Phú Yên',N'Trung'),
(37,'56',N'Khánh Hòa',N'Trung'),
(38,'58',N'Ninh Thuận',N'Trung'),
(39,'60',N'Bình Thuận',N'Trung'),
(40,'62',N'Kon Tum',N'Trung'),
(41,'64',N'Gia Lai',N'Trung'),
(42,'66',N'Đắk Lắk',N'Trung'),
(43,'67',N'Đắk Nông',N'Trung'),
(44,'68',N'Lâm Đồng',N'Trung'),
(45,'70',N'Bình Phước',N'Nam'),
(46,'72',N'Tây Ninh',N'Nam'),
(47,'74',N'Bình Dương',N'Nam'),
(48,'75',N'Đồng Nai',N'Nam'),
(49,'77',N'Bà Rịa - Vũng Tàu',N'Nam'),
(50,'79',N'Thành phố Hồ Chí Minh',N'Nam'),
(51,'80',N'Long An',N'Nam'),
(52,'82',N'Tiền Giang',N'Nam'),
(53,'83',N'Bến Tre',N'Nam'),
(54,'84',N'Trà Vinh',N'Nam'),
(55,'86',N'Vĩnh Long',N'Nam'),
(56,'87',N'Đồng Tháp',N'Nam'),
(57,'89',N'An Giang',N'Nam'),
(58,'91',N'Kiên Giang',N'Nam'),
(59,'92',N'Cần Thơ',N'Nam'),
(60,'93',N'Hậu Giang',N'Nam'),
(61,'94',N'Sóc Trăng',N'Nam'),
(62,'95',N'Bạc Liêu',N'Nam'),
(63,'96',N'Cà Mau',N'Nam');
INSERT dbo.KhuVuc(MaKhuVuc,TenTinh,Vung) SELECT 'KV'+RIGHT('00'+CONVERT(varchar,ThuTu),2),TenTinh,Vung FROM @t ORDER BY ThuTu;
INSERT dbo.TinhThanh_LichSu(MaTinh,ThuTu,KhuVucID,MocDanhMuc) SELECT t.MaTinh,t.ThuTu,k.KhuVucID,'20241231' FROM @t t JOIN dbo.KhuVuc k ON k.MaKhuVuc='KV'+RIGHT('00'+CONVERT(varchar,t.ThuTu),2);
INSERT dbo.KhoHang(MaKhoHang,TenKhoHang,KhuVucID,LaMoPhong) SELECT 'KHO'+RIGHT('00'+CONVERT(varchar,t.ThuTu),2),N'Kho mô phỏng '+k.TenTinh,k.KhuVucID,1 FROM @t t JOIN dbo.KhuVuc k ON k.MaKhuVuc='KV'+RIGHT('00'+CONVERT(varchar,t.ThuTu),2);
INSERT dbo.GoiCuoc(MaGoiCuoc,TenGoiCuoc,LoaiDichVu,DonViTinh,DonGia) VALUES
('GC001',N'Viettel - Thoại mô phỏng','THOAI','PHUT',800),('GC002',N'Viettel - Data mô phỏng','DATA','MB',20),
('GC003',N'VinaPhone - Thoại mô phỏng','THOAI','PHUT',800),('GC004',N'VinaPhone - Data mô phỏng','DATA','MB',20),
('GC005',N'MobiFone - Thoại mô phỏng','THOAI','PHUT',800),('GC006',N'MobiFone - Data mô phỏng','DATA','MB',20);
COMMIT;

-- Gia goi cong bo la tham khao tai 11/11/2026, khong dung de tinh cuoc mo phong.
INSERT dbo.GoiCuoc_ThamKhao(NhaMangID,MaGoi,LoaiGoi,GiaChuKy,SoNgay,DonViChuKy,GBMoiNgay,GBMoiChuKy,PhutNoiMang,PhutNgoaiMang,Nguon,GhiChu,NgayTraCuu)
SELECT n.NhaMangID,s.MaGoi,s.LoaiGoi,s.GiaChuKy,s.SoNgay,s.DonViChuKy,s.GBMoiNgay,s.GBMoiChuKy,s.PhutNoiMang,s.PhutNgoaiMang,s.Nguon,s.GhiChu,'20261111'
FROM(VALUES
(N'NM003',N'5G135N',N'DATA',135000,NULL,N'THANG',NULL,NULL,NULL,NULL,N'https://media.vietteltelecom.vn/upload/ckfinder/files/The%20le%20CT.pdf',N'Tài liệu chương trình 08/2025; chỉ xác nhận giá và kỳ. Chưa xác minh hạn mức hoặc còn áp dụng năm 2026.'),
(N'NM003',N'5G150',N'DATA',150000,NULL,N'THANG',NULL,NULL,NULL,NULL,N'https://media.vietteltelecom.vn/upload/ckfinder/files/The%20le%20CT.pdf',N'Tài liệu chương trình 08/2025; hạn mức chưa xác minh. Không cam kết đang mở đăng ký.'),
(N'NM003',N'5G160B',N'CHUA_XAC_MINH',160000,NULL,N'THANG',NULL,NULL,NULL,NULL,N'https://media.vietteltelecom.vn/upload/ckfinder/files/The%20le%20CT.pdf',N'Tài liệu chương trình 08/2025; chưa xác minh thành phần thoại/data, không suy đoán từ mã gói.'),
(N'NM004',N'VD90',N'COMBO',90000,30,N'NGAY',1,NULL,1500,30,N'https://digishop.vnpt.vn/tin-tuc-km/tu-van/goi-cuoc-goi-noi-mang',N'Nội mạng dưới 10 phút/cuộc, tối đa 1.500 phút; điều kiện theo thuê bao. Trang mô tả theo tháng, chu kỳ 30 ngày đối chiếu DigiShop.'),
(N'NM004',N'BIG90',N'DATA',90000,30,N'NGAY',1,NULL,NULL,NULL,N'https://digishop.vnpt.vn/tin-tuc-km/tat-ca/goi-cuoc-4g-phat-wifi',N'Hạn mức ngày; hết dung lượng áp dụng điều kiện của nhà mạng.'),
(N'NM004',N'BIG120',N'DATA',120000,30,N'NGAY',2,NULL,NULL,NULL,N'https://digishop.vnpt.vn/tin-tuc-km/tat-ca/goi-cuoc-4g-phat-wifi',N'Hạn mức ngày; đối tượng áp dụng cần kiểm tra theo thuê bao.'),
(N'NM005',N'PT90',N'DATA',90000,30,N'NGAY',1.5,NULL,NULL,NULL,N'https://www.mobifone.vn/dich-vu-di-dong/chi-tiet-goi-cuoc/pt90-PT90',N'1,5 GB/ngày, hết hạn mức dừng; đăng ký tùy đối tượng đủ điều kiện.'),
(N'NM005',N'NA90',N'DATA',90000,30,N'NGAY',NULL,15,NULL,NULL,N'https://5g.mobifone.vn/dich-vu-di-dong/goi-data?target=Th%C3%A1ng',N'15 GB/chu kỳ; điều kiện áp dụng kiểm tra trên nhà mạng.'),
(N'NM005',N'NA120',N'DATA',120000,30,N'NGAY',NULL,20,NULL,NULL,N'https://5g.mobifone.vn/dich-vu-di-dong/goi-data?target=Th%C3%A1ng',N'20 GB/chu kỳ; điều kiện áp dụng kiểm tra trên nhà mạng.')
)s(MaNhaMang,MaGoi,LoaiGoi,GiaChuKy,SoNgay,DonViChuKy,GBMoiNgay,GBMoiChuKy,PhutNoiMang,PhutNgoaiMang,Nguon,GhiChu)
JOIN dbo.NhaMang n ON n.MaNhaMang=s.MaNhaMang
WHERE NOT EXISTS(SELECT 1 FROM dbo.GoiCuoc_ThamKhao x WHERE x.NhaMangID=n.NhaMangID AND x.MaGoi=s.MaGoi AND x.NgayTraCuu='20261111');
