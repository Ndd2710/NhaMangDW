"""Hợp đồng giao diện nguồn; chỉ gọi thủ tục nghiệp vụ được liệt kê."""
import re
from datetime import datetime
from decimal import Decimal, InvalidOperation


def f(name, label, kind='text', source=None, optional=False):
    return dict(name=name, label=label, kind=kind, source=source, optional=optional)


YC = f('MaYeuCau', 'Mã yêu cầu', 'request')
TB = f('ThueBaoID', 'Thuê bao', 'select', 'subscribers')
TIME = f('ThoiDiem', 'Thời điểm', 'datetime-local')
MONEY = f('SoTien', 'Số tiền (VND)', 'decimal')
FORMS = {
    'khach-hang': dict(title='Khách hàng', section='customers', fields=[f('MaKhachHang', 'Mã khách hàng · KH + 6 số'), f('TenKhachHang', 'Tên khách hàng'), f('LoaiKhachHang', 'Loại khách hàng', 'select', 'customerTypes'), f('Email', 'Email (nếu có)', 'email', optional=True)]),
    'thue-bao': dict(title='Tạo thuê bao', section='subscribers', fields=[f('MaThueBao', 'Mã thuê bao · TB + 6 số'), f('SoThueBao', 'Số mô phỏng · DEMO- + 6 số'), f('KhachHangID', 'Khách hàng', 'select', 'customers'), f('NhaMangID', 'Nhà mạng', 'select', 'networks'), f('KhuVucID', 'Khu vực', 'select', 'regions'), f('LoaiThueBao', 'Hình thức', 'select', 'subscriberTypes'), f('NgayDangKy', 'Ngày đăng ký', 'datetime-local')]),
    'trang-thai': dict(title='Trạng thái thuê bao', section='subscribers', fields=[TB, f('TrangThai', 'Trạng thái', 'select', 'statuses')]),
    'dang-ky': dict(title='Đăng ký gói', section='registrations', fields=[YC, TB, f('GoiCuocID', 'Biểu giá mô phỏng', 'select', 'plans'), f('NgayBatDau', 'Bắt đầu hiệu lực', 'datetime-local'), f('NgayKetThuc', 'Kết thúc (bỏ trống nếu chưa có)', 'datetime-local', optional=True)]),
    'huy-goi': dict(title='Hủy đăng ký', section='registrations', fields=[f('DangKyID', 'Đăng ký của thuê bao đang lọc', 'select', 'registrations'), f('ThoiDiemHuy', 'Thời điểm hủy', 'datetime-local')]),
    'nap-tien': dict(title='Nạp tiền', section='topups', fields=[YC, TB, MONEY, TIME]),
    'su-dung': dict(title='Ghi sử dụng dịch vụ', section='usage', fields=[YC, f('DangKyID', 'Đăng ký của thuê bao đang lọc', 'select', 'registrations'), f('KhuVucID', 'Khu vực sử dụng', 'select', 'regions'), f('BatDau', 'Bắt đầu', 'datetime-local'), f('KetThuc', 'Kết thúc', 'datetime-local'), f('DungLuongMB', 'Dung lượng MB · thoại nhập 0', 'decimal')]),
    'hoa-don': dict(title='Lập hóa đơn', section='invoices', fields=[YC, TB, f('Thang', 'Tháng hóa đơn', 'month'), f('NgayLap', 'Ngày lập (sau khi hết tháng)', 'datetime-local')]),
    'thanh-toan': dict(title='Thanh toán hóa đơn', section='payments', fields=[YC, f('HoaDonID', 'Hóa đơn của thuê bao đang lọc', 'select', 'invoices'), MONEY, TIME, f('PhuongThuc', 'Phương thức', 'select', 'paymentMethods')]),
    'goi-cuoc': dict(title='Thêm biểu giá', section='plans', admin=True, fields=[f('MaGoiCuoc', 'Mã gói · GC + 3 số'), f('TenGoiCuoc', 'Tên biểu giá mô phỏng'), f('LoaiDichVu', 'Dịch vụ', 'select', 'serviceTypes'), f('DonViTinh', 'Đơn vị', 'select', 'units'), f('DonGia', 'Đơn giá (VND/đơn vị)', 'decimal')]),
}

PATTERNS = {'MaKhachHang': r'KH\d{6}', 'MaThueBao': r'TB\d{6}', 'SoThueBao': r'DEMO-\d{6}', 'MaGoiCuoc': r'GC\d{3}', 'MaYeuCau': r'YC\d{12}'}
ENUMS = {'LoaiKhachHang': ('CA_NHAN', 'DOANH_NGHIEP'), 'LoaiThueBao': ('TRA_TRUOC', 'TRA_SAU'), 'TrangThai': ('HOAT_DONG', 'KHOA'), 'PhuongThuc': ('TIEN_MAT', 'CHUYEN_KHOAN'), 'LoaiDichVu': ('THOAI', 'DATA'), 'DonViTinh': ('PHUT', 'MB')}


def validate(action, payload, role):
    if action not in FORMS:
        raise ValueError('Chức năng nguồn không hợp lệ.')
    form = FORMS[action]
    if form.get('admin') and role != 'admin':
        raise PermissionError('Chỉ quản trị viên được thêm biểu giá.')
    if not isinstance(payload, dict) or set(payload) != {x['name'] for x in form['fields']}:
        raise ValueError('Các trường giao dịch không đúng biểu mẫu.')
    clean = {}
    for field in form['fields']:
        name = field['name']; value = payload[name]
        if not isinstance(value, str) or len(value) > (150 if name in ('TenKhachHang', 'Email') else 100):
            raise ValueError('Dữ liệu không hợp lệ: ' + field['label'])
        value = value.strip()
        if not value:
            if field['optional']:
                clean[name] = None
                continue
            raise ValueError('Cần nhập: ' + field['label'])
        if name in PATTERNS and not re.fullmatch(PATTERNS[name], value, flags=re.ASCII):
            raise ValueError('Sai quy tắc: ' + field['label'])
        if name in ENUMS and value not in ENUMS[name]:
            raise ValueError('Lựa chọn không hợp lệ: ' + field['label'])
        if name.endswith('ID') and not re.fullmatch(r'[1-9][0-9]{0,14}', value):
            raise ValueError('Cần chọn: ' + field['label'])
        if field['kind'] == 'datetime-local':
            if not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?', value):
                raise ValueError('Ngày giờ không hợp lệ.')
            datetime.fromisoformat(value)
        if field['kind'] == 'month':
            datetime.strptime(value, '%Y-%m'); value = value.replace('-', '')
        if field['kind'] == 'decimal':
            if not re.fullmatch(r'\d{1,12}(\.\d{1,2})?', value):
                raise ValueError('Số không âm, tối đa hai chữ số lẻ: ' + field['label'])
            try:
                if not Decimal(value).is_finite():
                    raise InvalidOperation
            except InvalidOperation:
                raise ValueError('Số không hợp lệ.')
        if name == 'Email' and not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', value):
            raise ValueError('Email không hợp lệ.')
        clean[name] = value
    if action == 'goi-cuoc' and clean['DonViTinh'] != ('PHUT' if clean['LoaiDichVu'] == 'THOAI' else 'MB'):
        raise ValueError('Thoại dùng PHUT; data dùng MB.')
    return clean
