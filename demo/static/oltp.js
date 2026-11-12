'use strict';
const Oltp = {
  sections:{customers:'Khách hàng',subscribers:'Thuê bao',registrations:'Đăng ký gói cước',topups:'Nạp tiền',usage:'Sử dụng dịch vụ',invoices:'Hóa đơn & thanh toán',ledger:'Sổ tài khoản',plans:'Biểu giá mô phỏng'},
  actions:{customers:['khach-hang'],subscribers:['thue-bao','trang-thai'],registrations:['dang-ky','huy-goi'],topups:['nap-tien'],usage:['su-dung'],invoices:['hoa-don','thanh-toan'],ledger:[],plans:['goi-cuoc']},
  labels:{TrangThaiKho:'Trạng thái vào kho',ThanhTienKho:'Tiền cước trong kho (VND)',MaKhachHang:'Mã khách hàng',TenKhachHang:'Tên khách hàng',LoaiKhachHang:'Loại khách hàng',EmailHienThi:'Email',MaThueBao:'Mã thuê bao',SoThueBao:'Số mô phỏng',TenNhaMang:'Nhà mạng',TenTinh:'Tỉnh / thành',Vung:'Miền',LoaiThueBao:'Hình thức',TrangThai:'Trạng thái',SoDu:'Số dư (VND)',MaDangKy:'Mã đăng ký',MaYeuCau:'Mã yêu cầu',MaGoiCuoc:'Mã gói',TenGoiCuoc:'Tên biểu giá',LoaiDichVu:'Dịch vụ',DonViTinh:'Đơn vị',DonGia:'Đơn giá (VND)',DonGiaApDung:'Đơn giá áp dụng',NgayBatDau:'Hiệu lực từ',KetThucHienThi:'Kết thúc',BatDau:'Bắt đầu',KetThuc:'Kết thúc',SoPhutGoi:'Phút tính cước',DungLuongDataMB:'Dung lượng (MB)',ThanhTien:'Tiền cước (VND)',SoTien:'Số tiền (VND)',ThoiDiem:'Thời điểm',Thang:'Tháng',TongTien:'Tổng tiền (VND)',SoTienDaThanhToan:'Đã thanh toán (VND)',SoTienConNo:'Còn nợ (VND)',PhuongThuc:'Phương thức',MaSoCai:'Mã sổ cái',LoaiGiaoDich:'Loại giao dịch',MaGiaoDich:'Mã giao dịch',SoDuSau:'Số dư sau (VND)',NgayTaoUTC:'Ghi nhận (UTC)',HoaDonID:'Mã hóa đơn'},
  columns:{customers:['MaKhachHang','TenKhachHang','LoaiKhachHang','EmailHienThi'],subscribers:['MaThueBao','SoThueBao','TenKhachHang','TenNhaMang','TenTinh','LoaiThueBao','TrangThai','SoDu'],registrations:['MaDangKy','MaYeuCau','MaThueBao','TenGoiCuoc','LoaiDichVu','DonGiaApDung','NgayBatDau','KetThucHienThi','TrangThai'],topups:['MaYeuCau','MaThueBao','SoTien','ThoiDiem'],usage:['MaYeuCau','MaThueBao','LoaiDichVu','BatDau','KetThuc','SoPhutGoi','DungLuongDataMB','ThanhTien','TrangThaiKho','ThanhTienKho'],invoices:['HoaDonID','MaYeuCau','MaThueBao','Thang','TongTien','SoTienDaThanhToan','SoTienConNo','TrangThai'],payments:['MaYeuCau','MaThueBao','HoaDonID','SoTien','ThoiDiem','PhuongThuc'],ledger:['MaSoCai','MaThueBao','LoaiGiaoDich','MaGiaoDich','SoTien','SoDuSau','NgayTaoUTC'],plans:['MaGoiCuoc','TenGoiCuoc','LoaiDichVu','DonViTinh','DonGia']},
  enums:{customerTypes:[['CA_NHAN','Cá nhân'],['DOANH_NGHIEP','Doanh nghiệp']],subscriberTypes:[['TRA_TRUOC','Trả trước'],['TRA_SAU','Trả sau']],statuses:[['HOAT_DONG','Hoạt động'],['KHOA','Khóa']],paymentMethods:[['TIEN_MAT','Tiền mặt'],['CHUYEN_KHOAN','Chuyển khoản']],serviceTypes:[['THOAI','Thoại'],['DATA','Data']],units:[['PHUT','Phút'],['MB','MB']]},
  catalog:null,data:null,subject:'0',page:1,q:'',action:null,section:null,owner:null,loading:false,busy:false,message:'',failed:false,serial:0,
  key(){return 'nhamangdw.oltp.'+state.user.username+'.'+this.action;},
  draft(){try{return JSON.parse(localStorage.getItem(this.key()))||{};}catch{return {};}},
  save(d){localStorage.setItem(this.key(),JSON.stringify(d));},
  capture(){const form=$('oltp-form');if(!form)return;const d=this.draft();if(d.pending||d.done)return;d.values=Object.fromEntries(new FormData(form));this.save(d);},
  async load(fresh=false){
    const serial=++this.serial,owner=state.user.username,section=state.view.slice(5);
    if(this.owner!==owner){this.owner=owner;this.catalog=null;this.section=null;const saved=sessionStorage.getItem('nhamangdw.oltp.subject.'+owner)||'0';this.subject=/^\d{1,9}$/.test(saved)?saved:'0';}
    if(this.section!==section){this.section=section;this.page=1;this.q='';this.action=null;this.data=null;this.message='';}
    this.loading=true;this.render();
    try{
      const catalog=(!this.catalog||fresh)?await api('/api/oltp/catalog'):this.catalog;
      const data=await api('/api/oltp/list?'+new URLSearchParams({section:this.listSection(),subject:this.subject,page:this.page,q:this.q}));
      if(serial!==this.serial||state.user?.username!==owner||state.view!=='oltp-'+section)return;
      this.catalog=catalog;this.data=data;
      const actions=this.available();if(!actions.includes(this.action))this.action=actions[0]||null;
      $('data-status').textContent='Nguồn NhaMangOLTP · Đang xem dữ liệu giao dịch';
    }catch(e){if(serial===this.serial){this.message=e.message;this.failed=true;}}
    finally{if(serial===this.serial){this.loading=false;if(state.view==='oltp-'+section&&state.user?.username===owner)this.render();}}
  },
  available(){return (this.actions[this.section]||[]).filter(a=>this.catalog?.forms[a]);},
  listSection(){return this.section==='invoices'&&this.action==='thanh-toan'?'payments':this.section;},
  rowsFor(source){return this.enums[source]?.map(([ID,Ten])=>({ID,Ten}))||this.data?.[source]||this.catalog?.[source]||[];},
  field(field,value,locked){
    const name=field.name,id='oltp-'+name;let control;
    const required=field.optional?'':'required',lock=locked?'disabled':'';
    if(field.kind==='select')control=`<select id="${id}" name="${name}" ${required} ${lock}><option value="">Chọn…</option>${options(this.rowsFor(field.source),String(value??''))}</select>`;
    else control=`<input id="${id}" name="${name}" type="${field.kind==='request'?'text':field.kind==='decimal'?'number':field.kind}" ${required} ${lock} ${field.kind==='decimal'?'min="0" step="0.01"':''} ${field.kind==='datetime-local'?'step="1"':''} ${field.kind==='request'?'readonly':''} value="${escapeHTML(value??'')}" maxlength="150">`;
    return `<div><label for="${id}">${escapeHTML(field.label)}</label>${control}</div>`;
  },
  render(){
    if(!state.user||!state.view.startsWith('oltp-'))return;
    const title=this.sections[this.section]||'Nguồn giao dịch';$('page-title').textContent=title;$('page-description').textContent='Quản lý nghiệp vụ trên nguồn OLTP mô phỏng.';$('breadcrumb').textContent=title;$('month').closest('.period').hidden=true;
    document.querySelectorAll('#navigation [data-view]').forEach(a=>a.classList.toggle('active',a.dataset.view===state.view));
    if(!this.catalog){$('content').innerHTML=panel('Kết nối nguồn OLTP','NhaMangOLTP',`<p role="status">${escapeHTML(this.message||'Đang tải danh mục…')}</p><button id="oltp-reload">Thử lại</button>`);$('oltp-reload').onclick=()=>this.load(true);return;}
    const actions=this.available(),form=this.catalog.forms[this.action],draft=this.action?this.draft():{},values=draft.values||{},locked=this.busy||draft.pending||draft.done;
    const hasRequest=form?.fields.some(f=>f.kind==='request');
    const formHTML=form?panel(form.title,'Chỉ thêm giao dịch mới; dữ liệu đã ghi được giữ lại.',`<form id="oltp-form"><fieldset ${this.busy?'disabled':''}><div class="oltp-fields">${form.fields.map(f=>this.field(f,values[f.name]??(f.name==='ThueBaoID'&&this.subject!=='0'?this.subject:f.name==='DungLuongMB'?'0':''),locked)).join('')}</div><div class="page-tools oltp-actions">${hasRequest?`<button type="button" id="oltp-code" class="secondary" ${locked||values.MaYeuCau?'disabled':''}>Cấp mã YC</button>`:''}<button id="oltp-submit" class="primary" type="submit" ${this.busy||draft.done||(hasRequest&&!values.MaYeuCau)?'disabled':''}>${this.busy?'Đang ghi…':draft.pending?'Gửi lại cùng yêu cầu':'Ghi nhận'}</button><button id="oltp-new" class="secondary" type="button" ${this.busy||draft.pending?'disabled':''}>Giao dịch mới</button></div></fieldset></form><p class="explain">Ngày giờ nghiệp vụ theo giờ Việt Nam. ${hasRequest?'Cấp YC một lần, giữ mã và nội dung khi gửi lại. ':''}${['huy-goi','su-dung','thanh-toan'].includes(this.action)?'Chọn thuê bao ở bộ lọc để lấy đúng đăng ký/hóa đơn. ':''}Biểu giá tính theo phút/MB mô phỏng; gói thương mại chỉ dùng tham khảo.</p>`):'';
    const cols=this.columns[this.listSection()].map(k=>[k,this.labels[k]||k,/^(SoDu|SoTien|DonGia|ThanhTien|TongTien|SoPhut|DungLuong)/.test(k),v=>this.display(k,v)]);
    $('content').innerHTML=`<p class="explain">Ghi nhận xong, quản trị viên chọn Nạp dữ liệu trong menu Nạp & xử lý cube để cập nhật báo cáo. Trạng thái vào kho được xem tại Sử dụng dịch vụ.</p><div class="page-tools"><form id="oltp-filter" class="filterbar"><div><label for="oltp-subject">Thuê bao đang lọc</label><select id="oltp-subject"><option value="0">Tất cả thuê bao</option>${options(this.catalog.subscribers,this.subject)}</select></div><div><label for="oltp-search">Tìm mã / tên</label><input id="oltp-search" value="${escapeHTML(this.q)}" maxlength="100"></div><button class="secondary">Tra cứu</button></form></div>${actions.length>1?`<div class="oltp-tabs">${actions.map(a=>`<button data-oltp-action="${a}" class="${this.action===a?'primary':'secondary'}">${escapeHTML(this.catalog.forms[a].title)}</button>`).join('')}</div>`:''}<div id="oltp-feedback" class="${this.failed?'error-panel':'notice'}" role="status" ${this.message?'':'hidden'}>${escapeHTML(this.message)}</div>${formHTML}${panel('Danh sách '+title.toLowerCase(),`${number(this.data?.count||0)} dòng · 50 dòng/trang`,this.loading?'<p>Đang tải…</p>':table(this.data?.rows||[],cols))+`<div class="page-tools"><span>Trang ${this.page} / ${Math.max(1,Math.ceil((this.data?.count||0)/50))}</span><div><button id="oltp-prev" ${this.page<=1?'disabled':''}>Trang trước</button> <button id="oltp-next" ${this.page*50>=(this.data?.count||0)?'disabled':''}>Trang sau</button></div></div>`}`;
    $('oltp-filter').onsubmit=e=>{e.preventDefault();this.capture();this.subject=$('oltp-subject').value;if(this.action){const d=this.draft();if(!d.pending&&!d.done&&d.values){if('ThueBaoID' in d.values&&this.subject!=='0')d.values.ThueBaoID=this.subject;delete d.values.DangKyID;delete d.values.HoaDonID;this.save(d);}}sessionStorage.setItem('nhamangdw.oltp.subject.'+state.user.username,this.subject);this.q=$('oltp-search').value;this.page=1;this.load();};
    document.querySelectorAll('[data-oltp-action]').forEach(b=>b.onclick=()=>{if(this.busy)return;this.capture();this.action=b.dataset.oltpAction;this.message='';this.page=1;this.load();});
    $('oltp-prev').onclick=()=>{this.capture();this.page--;this.load();};$('oltp-next').onclick=()=>{this.capture();this.page++;this.load();};
    if(form){$('oltp-form').addEventListener('input',()=>this.capture());$('oltp-form').addEventListener('change',()=>this.capture());$('oltp-form').onsubmit=e=>{e.preventDefault();this.submit();};$('oltp-new').onclick=()=>{this.save({});this.message='';this.render();};}
    if($('oltp-code'))$('oltp-code').onclick=async()=>{this.capture();const action=this.action,key=this.key();this.busy=true;this.render();try{const d=await api('/api/oltp/request-code',{});const saved=JSON.parse(localStorage.getItem(key))||{};saved.values={...saved.values,MaYeuCau:d.rows[0].MaYeuCau};localStorage.setItem(key,JSON.stringify(saved));this.message='Đã cấp mã YC. Điền thông tin rồi chọn Ghi nhận.';this.failed=false;}catch(e){this.message=e.message;this.failed=true;}finally{this.busy=false;if(this.action===action)this.render();}};
  },
  display(k,v){if(v===null||v===undefined)return 'Không áp dụng';if(k==='HoaDonID')return 'HD'+String(v).padStart(10,'0');const labels={HIEU_LUC:'Có hiệu lực',HET_HAN:'Hết hạn',HUY:'Đã hủy',DA_THANH_TOAN:'Đã thanh toán',CHUA_THANH_TOAN:'Còn công nợ'};if(labels[v])return labels[v];const e=Object.values(this.enums).flat().find(([code])=>code===v);if(e)return escapeHTML(e[1]);if(typeof v==='number')return number(v);return escapeHTML(v);},
  async submit(){
    if(this.busy)return;this.capture();const action=this.action,key=this.key(),section=this.section,owner=state.user.username;let d=this.draft();
    d.pending=true;this.save(d);this.busy=true;this.message='Đang ghi nhận giao dịch…';this.failed=false;this.render();
    try{const result=await api('/api/oltp/write',{action,values:d.values});d.pending=false;d.done=true;localStorage.setItem(key,JSON.stringify(d));this.message=result.message+(result.rows[0]?.ID?' ID: '+result.rows[0].ID+'.':'');this.failed=false;
      if(state.user?.username===owner&&this.section===section){await this.load(true);}
    }catch(e){if(e.status===400&&e.code!==56104&&e.code!==56505){d.pending=false;localStorage.setItem(key,JSON.stringify(d));}this.message=e.message+(d.pending?' Giữ nguyên mã và nội dung; bấm Gửi lại cùng yêu cầu để xác nhận kết quả.':' Sửa thông tin rồi gửi lại.');this.failed=true;}
    finally{this.busy=false;if(state.user?.username===owner&&this.action===action&&this.section===section)this.render();}
  }
};
