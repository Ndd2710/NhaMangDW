"""Demo cục bộ hai vai trò; đọc SQL/SSAS và gọi đúng các script hiện có."""
import sys
sys.dont_write_bytecode = True
import csv
import getpass
import hashlib
import hmac
import io
import json
import re
import secrets
import subprocess
import threading
import time
from datetime import datetime, timezone
from http import HTTPStatus
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
ROLES = {'quantri': 'admin', 'nhanvien': 'staff'}
APP_VERSION = 'nhamangdw-trien-khai-11'
PS = ['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File']
sys.path.insert(0, str(HERE))
from oltp_api import FORMS, validate


class SourceError(Exception):
    def __init__(self, message, code):
        super().__init__(message)
        self.code = code

    @property
    def status(self):
        # Lỗi nghiệp vụ/constraint đã rollback; lỗi kết nối/timeout còn cần retry.
        return 400 if 50000 <= self.code < 60000 or self.code in (547, 2601, 2627, 2628, 8152) else 503


def source_data(mode, **values):
    result = execute(PS + [str(HERE / 'NguonOLTP.ps1')],
                     input=json.dumps(dict(values, mode=mode)), timeout=50)
    if result.returncode:
        raise SourceError('Không kết nối được nguồn OLTP. Giữ mã yêu cầu và thử lại.', 0)
    data = json.loads(result.stdout.lstrip('\ufeff'))
    if not data.get('ok'):
        raise SourceError(data.get('error', 'Không thực hiện được giao dịch.'), data.get('code', 0))
    return data['data']


def execute(command, **kwargs):
    return subprocess.run(command, capture_output=True, text=True, encoding='utf-8',
                          errors='replace', creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0), **kwargs)


def read_data(mode, filters):
    result = execute(PS + [str(HERE / 'DocDuLieu.ps1')],
                     input=json.dumps(dict(filters, mode=mode)), timeout=80)
    if result.returncode:
        raise RuntimeError('Không đọc được dữ liệu trực tiếp. Kiểm tra dịch vụ SQL/SSAS và quyền Windows. ' + result.stderr.strip()[:450])
    return json.loads(result.stdout.lstrip('\ufeff'))


def filters_from(query):
    raw = {k: v[0] for k, v in parse_qs(query, keep_blank_values=True).items()}
    month = raw.get('month', '202610')
    if not re.fullmatch(r'20[0-9]{2}(0[1-9]|1[0-2])', month):
        raise ValueError('Chọn tháng hợp lệ trong lịch dữ liệu 2000–2099.')
    warehouse = raw.get('warehouse', '0')
    if not re.fullmatch(r'\d{1,6}', warehouse):
        raise ValueError('Mã kho không hợp lệ.')
    result = {'month': int(month), 'warehouse': int(warehouse)}
    for name in ('type', 'network', 'region', 'subscriber'):
        value = raw.get(name, '')
        if not re.fullmatch(r'[A-Z0-9_]{0,30}', value):
            raise ValueError('Mã bộ lọc không hợp lệ.')
        result[name] = value
    if result['type'] not in ('', 'THOAI', 'DATA'):
        raise ValueError('Loại dịch vụ không hợp lệ.')
    return result


class App:
    def __init__(self, passwords):
        self.accounts = {}
        for name, password in passwords.items():
            salt = secrets.token_bytes(16)
            self.accounts[name] = (salt, hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 200_000))
        self.sessions = {}
        self.failures = []
        self.lock = threading.Lock()
        self.job_lock = threading.Lock()
        self.jobs = []
        history = ROOT / 'evidence/demo/jobs'
        if history.is_dir():
            for path in sorted(history.glob('*.json'), reverse=True)[:12]:
                try:
                    job = json.loads(path.read_text(encoding='utf-8'))
                    if job.get('status') in ('success', 'failed') and job.get('action') in ('pipeline', 'process', 'verify'):
                        self.jobs.append(job)
                except (ValueError, OSError):
                    continue

    def login(self, username, password):
        with self.lock:
            self.failures = [x for x in self.failures if x > time.time() - 120]
            if len(self.failures) >= 8:
                raise ValueError('Đăng nhập sai nhiều lần. Vui lòng chờ hai phút.')
        salt, expected = self.accounts.get(username, (b'not-a-user', b'x' * 32))
        actual = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 200_000)
        if not hmac.compare_digest(actual, expected):
            with self.lock:
                self.failures.append(time.time())
            return None
        token = secrets.token_urlsafe(32)
        session = {'username': username, 'role': ROLES[username], 'csrf': secrets.token_urlsafe(24), 'expires': time.time() + 8 * 3600}
        with self.lock:
            self.sessions = {k: v for k, v in self.sessions.items() if v['expires'] > time.time()}
            self.sessions[token] = session
            self.failures = []
        return token, session

    def start_job(self, action):
        if action not in ('pipeline', 'process', 'verify'):
            raise ValueError('Tác vụ không hợp lệ.')
        if not self.job_lock.acquire(blocking=False):
            return None
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        job = {'id': stamp + '-' + secrets.token_hex(3), 'action': action, 'status': 'running', 'steps': [], 'output': '', 'started': stamp}
        with self.lock:
            self.jobs.insert(0, job)
            self.jobs = self.jobs[:12]
        threading.Thread(target=self._run_job, args=(job,), daemon=True).start()
        return job

    def _run_job(self, job):
        def step(title, name):
            return title, PS + [str(HERE / 'ChayBuoc.ps1'), '-Buoc', name]
        commands = []
        if job['action'] == 'pipeline':
            commands += [step('Nạp tăng dần hai luồng', 'nap'), step('Kiểm tra dữ liệu kho', 'kiemtra')]
        if job['action'] in ('pipeline', 'process'):
            commands.append(step('Xử lý cube', 'process'))
        commands += [step('Đối soát SQL/cube và 14 MDX', 'mdx'), step('Đối soát cước', 'cuoc')]
        try:
            for title, command in commands:
                with self.lock:
                    job['steps'].append({'title': title, 'status': 'running'})
                result = execute(command, timeout=240, cwd=str(ROOT))
                with self.lock:
                    job['steps'][-1]['status'] = 'success' if result.returncode == 0 else 'failed'
                    job['output'] += '\n' + title + '\n' + result.stdout + result.stderr
                if result.returncode:
                    raise RuntimeError('Tác vụ dừng tại bước: ' + title)
            with self.lock:
                job['status'] = 'success'
        except Exception as exc:
            with self.lock:
                job['status'] = 'failed'
                job['output'] += '\n' + str(exc)
                if job['steps'] and job['steps'][-1]['status'] == 'running':
                    job['steps'][-1]['status'] = 'failed'
        finally:
            with self.lock:
                job['finished'] = datetime.now(timezone.utc).isoformat()
                saved = dict(job)
            path = ROOT / 'evidence/demo/jobs'
            try:
                path.mkdir(parents=True, exist_ok=True)
                (path / (job['id'] + '.json')).write_text(json.dumps(saved, ensure_ascii=False, indent=2), encoding='utf-8')
            finally:
                self.job_lock.release()


class Handler(BaseHTTPRequestHandler):
    server_version = 'NhaMangDW/1.0'

    def log_message(self, *_):
        pass  # Không ghi mật khẩu, cookie hoặc body vào log HTTP.

    def reply(self, status, payload, content='application/json; charset=utf-8', cookie=None):
        data = json.dumps(payload, ensure_ascii=False).encode('utf-8') if isinstance(payload, (dict, list)) else payload
        self.send_response(status)
        self.send_header('Content-Type', content)
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-App-Version', APP_VERSION)
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'same-origin')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
        if cookie:
            self.send_header('Set-Cookie', cookie)
        try:
            self.end_headers()
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionAbortedError, ConnectionResetError):
            # Trình duyệt có thể hủy request khi đổi menu hoặc tải lại trang.
            return

    def session(self):
        try:
            cookies = SimpleCookie(self.headers.get('Cookie', ''))
            token = cookies['nmdw_session'].value if 'nmdw_session' in cookies else ''
            session = self.server.app.sessions.get(token)
            if session and session['expires'] > time.time():
                return token, session
        except Exception:
            pass
        return '', None

    def allowed_host(self):
        return self.headers.get('Host') in (f'127.0.0.1:{self.server.server_port}', f'localhost:{self.server.server_port}')

    def do_GET(self):
        try:
            if not self.allowed_host():
                return self.reply(403, {'error': 'Máy chủ chỉ phục vụ kết nối cục bộ.'})
            url = urlsplit(self.path)
            static = {'/': ('index.html', 'text/html; charset=utf-8'), '/app.js': ('app.js', 'text/javascript; charset=utf-8'), '/oltp.js': ('oltp.js', 'text/javascript; charset=utf-8'), '/analysis.js': ('analysis.js', 'text/javascript; charset=utf-8'), '/style.css': ('style.css', 'text/css; charset=utf-8')}
            if url.path in static:
                file, mime = static[url.path]
                return self.reply(200, (HERE / 'static' / file).read_bytes(), mime)
            if url.path == '/api/info':
                return self.reply(200, {'version': APP_VERSION, 'roles': ['admin', 'staff']})
            _, session = self.session()
            if not session:
                return self.reply(401, {'error': 'Vui lòng đăng nhập.'})
            if url.path == '/api/me':
                return self.reply(200, {k: session[k] for k in ('username', 'role', 'csrf')})
            if url.path == '/api/oltp/catalog':
                data = source_data('catalog')
                data['forms'] = {k: v for k, v in FORMS.items() if not v.get('admin') or session['role'] == 'admin'}
                return self.reply(200, data)
            if url.path == '/api/oltp/list':
                params = parse_qs(url.query, keep_blank_values=True)
                values = {k: params.get(k, [v])[0] for k, v in [('section', 'customers'), ('subject', '0'), ('page', '1'), ('q', '')]}
                if values['section'] not in ('customers', 'subscribers', 'registrations', 'topups', 'usage', 'invoices', 'payments', 'ledger', 'plans'):
                    raise ValueError('Danh sách không hợp lệ.')
                if not re.fullmatch(r'\d{1,9}', values['subject']) or not re.fullmatch(r'[1-9]\d{0,5}', values['page']) or len(values['q']) > 100:
                    raise ValueError('Bộ lọc nguồn không hợp lệ.')
                return self.reply(200, source_data('list', **values))
            if url.path == '/api/jobs':
                if session['role'] != 'admin':
                    return self.reply(403, {'error': 'Chỉ quản trị viên được xem tác vụ.'})
                with self.server.app.lock:
                    return self.reply(200, {'jobs': json.loads(json.dumps(self.server.app.jobs))})
            modes = {'/api/catalog': 'catalog', '/api/report': 'report', '/api/analysis': 'analysis', '/api/cube': 'cube', '/api/admin': 'admin'}
            if url.path in modes:
                if url.path == '/api/admin' and session['role'] != 'admin':
                    return self.reply(403, {'error': 'Chỉ quản trị viên được xem nhật ký nạp.'})
                return self.reply(200, read_data(modes[url.path], filters_from(url.query)))
            if url.path == '/api/analysis/export':
                group = parse_qs(url.query).get('group', ['networks'])[0]
                if group not in ('networks', 'regions', 'plans', 'provinces', 'days'):
                    raise ValueError('Góc phân tích không hợp lệ.')
                data = read_data('analysis', filters_from(url.query))['rows']
                columns = [('Ma','Mã / ngày'),('Ten','Tên / ngày'),('SoBanGhi','Số bản ghi'),('SoThueBao','Thuê bao có phát sinh'),('SoPhutGoi','Phút thoại'),('DungLuongDataMB','Dung lượng (MB)'),('SoCuocGoi','Số cuộc thoại'),('DoanhThuThoai','Doanh thu thoại (VND)'),('DoanhThuData','Doanh thu data (VND)'),('DoanhThu','Doanh thu cước (VND)'),('DonGiaThoaiBinhQuan','Đơn giá thoại bình quân (VND/phút)'),('DonGiaDataBinhQuan','Đơn giá data bình quân (VND/MB)')]
                buf = io.StringIO(); writer = csv.writer(buf)
                writer.writerow([label for _, label in columns])
                for row in data:
                    if row['GocNhin'] != group:
                        continue
                    writer.writerow([("'" + value if isinstance(value, str) and value.startswith(('=', '+', '-', '@')) else value) for value in [row.get(key) for key, _ in columns]])
                return self.reply(200, ('\ufeff' + buf.getvalue()).encode('utf-8'), 'text/csv; charset=utf-8')
            if url.path == '/api/export':
                params = parse_qs(url.query)
                kind = params.get('kind', ['goods'])[0]
                if kind not in ('goods', 'sales', 'purchases', 'inventory', 'telecom'):
                    raise ValueError('Loại báo cáo không hợp lệ.')
                data = read_data('report', filters_from(url.query))['telecom' if kind == 'telecom' else 'goods']
                labels = {'NhomSanPham': 'Nhóm sản phẩm', 'SoLuongBan': 'Số lượng bán', 'DoanhThu': 'Doanh thu (VND)', 'SoLuongMua': 'Số lượng mua', 'ThanhTienMua': 'Thành tiền mua (VND)', 'SoLuongTon': 'Tồn cuối kỳ', 'LoaiDichVu': 'Loại dịch vụ', 'TenNhaMang': 'Nhà mạng', 'TenTinh': 'Khu vực', 'Vung': 'Vùng', 'MaThueBao': 'Mã thuê bao', 'LoaiKhachHang': 'Loại khách hàng', 'SoPhutGoi': 'Phút thoại', 'DungLuongDataMB': 'Dung lượng (MB)', 'SoCuocGoi': 'Số cuộc gọi', 'DoanhThuThoai': 'Doanh thu thoại (VND)', 'DoanhThuData': 'Doanh thu data (VND)', 'PhiVienThong': 'Phí viễn thông giả lập (VND)', 'PhiXuLy': 'Phí xử lý giả lập (VND)', 'SoBanGhi': 'Số bản ghi'}
                columns = {'sales': ['NhomSanPham', 'SoLuongBan', 'DoanhThu'],
                           'purchases': ['NhomSanPham', 'SoLuongMua', 'ThanhTienMua'],
                           'inventory': ['NhomSanPham', 'SoLuongTon']}
                keys = columns.get(kind) or (list(data[0]) if data else (list(labels)[:6] if kind == 'goods' else list(labels)[6:]))
                buf = io.StringIO(); writer = csv.writer(buf)
                writer.writerow([labels.get(k, k) for k in keys])
                for row in data:
                    values = [row.get(k) for k in keys]
                    writer.writerow(["'" + v if isinstance(v, str) and v.startswith(('=', '+', '-', '@')) else v for v in values])
                return self.reply(200, ('\ufeff' + buf.getvalue()).encode('utf-8'), 'text/csv; charset=utf-8')
            return self.reply(404, {'error': 'Không tìm thấy chức năng.'})
        except SourceError as exc:
            self.reply(exc.status, {'error': str(exc), 'code': exc.code})
        except ValueError as exc:
            self.reply(400, {'error': str(exc)})
        except Exception as exc:
            self.reply(503, {'error': str(exc)})

    def do_POST(self):
        try:
            if not self.allowed_host() or self.headers.get('Origin') != 'http://' + self.headers.get('Host', ''):
                return self.reply(403, {'error': 'Nguồn yêu cầu không hợp lệ.'})
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 8192:
                return self.reply(400, {'error': 'Nội dung yêu cầu không hợp lệ.'})
            payload = json.loads(self.rfile.read(length))
            if not isinstance(payload, dict):
                raise ValueError('Nội dung yêu cầu phải là đối tượng JSON.')
            url = urlsplit(self.path)
            if url.path == '/api/login':
                username, password = payload.get('username', ''), payload.get('password', '')
                if not isinstance(username, str) or not isinstance(password, str):
                    raise ValueError('Thông tin đăng nhập không hợp lệ.')
                result = self.server.app.login(username, password)
                if not result:
                    return self.reply(401, {'error': 'Tên đăng nhập hoặc mật khẩu chưa đúng.'})
                token, session = result
                return self.reply(200, {k: session[k] for k in ('username', 'role', 'csrf')}, cookie=f'nmdw_session={token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=28800')
            token, session = self.session()
            if not session:
                return self.reply(401, {'error': 'Vui lòng đăng nhập.'})
            if not hmac.compare_digest(self.headers.get('X-CSRF-Token', ''), session['csrf']):
                return self.reply(403, {'error': 'Phiên thao tác không hợp lệ. Hãy đăng nhập lại.'})
            if url.path == '/api/logout':
                with self.server.app.lock:
                    self.server.app.sessions.pop(token, None)
                return self.reply(200, {'ok': True}, cookie='nmdw_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0')
            if url.path == '/api/oltp/request-code':
                return self.reply(200, source_data('write', action='ma-yeu-cau', payload={}))
            if url.path == '/api/oltp/write':
                action = payload.get('action')
                if not isinstance(action, str):
                    raise ValueError('Chức năng không hợp lệ.')
                clean = validate(action, payload.get('values'), session['role'])
                data = source_data('write', action=action, payload=clean)
                return self.reply(200, dict(data, message='Đã ghi nhận trong nguồn NhaMangOLTP.'))
            if url.path == '/api/jobs':
                if session['role'] != 'admin':
                    return self.reply(403, {'error': 'Chỉ quản trị viên được vận hành ETL/cube.'})
                job = self.server.app.start_job(payload.get('action'))
                return self.reply(202, {'job': job}) if job else self.reply(409, {'error': 'Đang có tác vụ chạy. Hãy chờ hoàn tất.'})
            self.reply(404, {'error': 'Không tìm thấy chức năng.'})
        except PermissionError as exc:
            self.reply(403, {'error': str(exc)})
        except SourceError as exc:
            self.reply(exc.status, {'error': str(exc), 'code': exc.code})
        except (ValueError, TypeError) as exc:
            self.reply(400, {'error': str(exc)})
        except Exception:
            self.reply(500, {'error': 'Không thực hiện được yêu cầu.'})


def make_server(passwords, port=8765):
    server = ThreadingHTTPServer(('127.0.0.1', port), Handler)
    server.app = App(passwords)
    return server


def main():
    print('NHÀ MẠNG DW · Demo trên máy cục bộ')
    print('Tạo hai mật khẩu cho phiên demo; mật khẩu không ghi vào tệp.')
    passwords = {}
    for name, role in [('quantri', 'Quản trị viên'), ('nhanvien', 'Nhân viên')]:
        while True:
            password = getpass.getpass(f'Mật khẩu {name} ({role}, tối thiểu 8 ký tự): ')
            if len(password) >= 8:
                passwords[name] = password
                break
            print('Cần ít nhất 8 ký tự.')
    server = make_server(passwords)
    passwords.clear()
    print('Mở http://127.0.0.1:8765 · Ctrl+C để dừng')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
